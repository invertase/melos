import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:melos/melos.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'pubspec_extension.dart';

class TestLogger extends StandardLogger {
  final _buffer = StringBuffer();

  /// All the logs in order that were emitted so far.
  ///
  /// This includes both [stdout], [stderr] and [trace]. Logs from [trace] and
  /// [stderr] are respectively prefixed by `t-` and `e-` such that:
  ///
  /// ```dart main
  /// logger.stdout('Hello');
  /// logger.stderr('Error');
  /// logger.stdout('world');
  /// ```
  ///
  /// has the following output:
  ///
  /// ```
  /// Hello
  /// e-Error
  /// world
  /// ```
  ///
  /// This both ensures that tests to not forget to check errors and allows
  /// testing what the logs would actually look like.
  String get output => _buffer.toString();

  @override
  void stderr(String message) {
    _buffer.writeln(
      message.replaceAll(RegExp('^', multiLine: true), 'e-'),
    );
  }

  @override
  void stdout(String message) {
    _buffer.writeln(message);
  }

  @override
  void trace(String message) {
    _buffer.writeln(
      message.replaceAll(RegExp('^', multiLine: true), 't-'),
    );
  }

  @override
  void write(String message) {
    _buffer.write(message);
  }

  @override
  void writeCharCode(int charCode) {
    throw UnimplementedError();
  }
}

Directory createTestTempDir() {
  final dir = createTempDir(Directory.systemTemp.path);
  addTearDown(() => deleteEntry(dir));
  return Directory(dir);
}

Future<void> runPubGet(String workspacePath) async {
  final result = await Process.run(
    'dart',
    ['pub', 'get'],
    runInShell: Platform.isWindows,
    workingDirectory: workspacePath,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw Exception(
      'Failed to run pub get:\n${result.stdout}\n${result.stderr}',
    );
  }
}

const _runPubGet = runPubGet;

typedef TestWorkspaceConfigBuilder = MelosWorkspaceConfig Function(String path);

MelosWorkspaceConfig _defaultWorkspaceConfigBuilder(String path) =>
    MelosWorkspaceConfig(
      name: 'Melos',
      packages: [
        createGlob('packages/**', currentDirectoryPath: path),
      ],
      path: path,
    );

Future<Directory> createTemporaryWorkspace({
  TestWorkspaceConfigBuilder configBuilder = _defaultWorkspaceConfigBuilder,
  bool runPubGet = false,
  bool createLockfile = false,
}) async {
  final tempDir = createTempDir(p.join(Directory.current.path, '.dart_tool'));
  addTearDown(() => deleteEntry(tempDir));

  final workspacePath = tempDir;

  await createProject(
    Directory(workspacePath),
    Pubspec(
      'workspace',
      environment: defaultTestEnvironment,
      devDependencies: {
        'melos': PathDependency(Directory.current.path),
      },
    ),
    path: '.',
    createLockfile: createLockfile,
  );

  if (runPubGet) {
    await _runPubGet(workspacePath);
  }

  final config =
      (configBuilder(workspacePath)..validatePhysicalWorkspace()).toJson();

  writeTextFile(
    p.join(workspacePath, 'melos.yaml'),
    prettyEncodeJson(config),
  );

  return Directory(tempDir);
}

Future<Directory> createProject(
  Directory workspace,
  Pubspec partialPubspec, {
  String? path,
  bool createLockfile = false,
}) async {
  final pubspec = partialPubspec.environment != null &&
          partialPubspec.environment!.isNotEmpty
      ? partialPubspec
      : partialPubspec.copyWith(
          environment: {
            'sdk': defaultTestEnvironment['sdk'],
          },
        );

  final projectDirectory = Directory(
    p.joinAll([
      workspace.path,
      if (path != null)
        path
      else ...[
        'packages',
        pubspec.name,
      ],
    ]),
  );

  ensureDir(projectDirectory.path);

  await pubspec.save(projectDirectory);

  if (createLockfile) {
    final lockfile = p.join(projectDirectory.path, 'pubspec.lock');
    writeTextFile(lockfile, '');
  }

  // Reach into unParsedYaml and determine whether this is a plugin that
  // supports Android.
  // If it is, create an empty main class file to appease flutter pub
  // get in case an add-to-app module is present in the workspace
  final flutterNode = pubspec.flutter;
  final pluginNode = flutterNode?['plugin'] as Map<String, Object?>?;
  final platformsNode = pluginNode?['platforms'] as Map<String, Object?>?;
  final androidPluginNode = platformsNode?['android'] as Map<String, Object?>?;

  if (androidPluginNode != null) {
    final package = androidPluginNode['package'] as String?;
    final pluginClass = androidPluginNode['pluginClass'] as String?;

    if (package != null && pluginClass != null) {
      final javaMainClassFile = p.joinAll([
        projectDirectory.path,
        'android/src/main/java',
        ...package.split('.'),
        '$pluginClass.java',
      ]);
      if (!fileExists(javaMainClassFile)) {
        writeTextFile(javaMainClassFile, '', recursive: true);
      }
    }
  }

  return projectDirectory;
}

String packageConfigPath(String packageRoot) {
  return p.join(
    packageRoot,
    '.dart_tool',
    'package_config.json',
  );
}

String pubspecPath(String directory) {
  return p.join(directory, 'pubspec.yaml');
}

PackageConfig packageConfigForPackageAt(Directory dir) {
  final source = readTextFile(packageConfigPath(dir.path));
  return PackageConfig.fromJson(json.decode(source) as Map<String, Object?>);
}

class PackageConfig {
  PackageConfig._(
    this._map, {
    required this.packages,
    required this.generator,
  });

  PackageConfig.fromJson(Map<String, Object?> json)
      : this._(
          json,
          generator: json['generator']! as String,
          packages: (json['packages']! as List)
              .cast<Map<String, Object?>>()
              .map(PackageDependencyConfig.fromJson)
              .toList(),
        );

  final Map<String, Object?> _map;
  final List<PackageDependencyConfig> packages;
  final String generator;

  @override
  String toString() {
    return _map.toString();
  }
}

class PackageDependencyConfig {
  PackageDependencyConfig._(
    this._map, {
    required this.name,
    required this.rootUri,
    required this.packageUri,
  });

  PackageDependencyConfig.fromJson(Map<String, Object?> json)
      : this._(
          json,
          name: json['name']! as String,
          rootUri: json['rootUri']! as String,
          packageUri: json['packageUri']! as String,
        );

  final String name;
  final String rootUri;
  final String packageUri;
  final Map<String, Object?> _map;

  @override
  String toString() {
    return _map.toString();
  }
}

Pubspec pubspecFromJsonFile({
  String path = 'test/test_assets/',
  required String fileName,
}) {
  final filePath = '$path$fileName';
  final jsonAsString = readTextFile(filePath);
  return Pubspec.fromJson(json.decode(jsonAsString) as Map);
}

Pubspec pubspecFromYamlFile({
  required String directory,
}) {
  final filePath = pubspecPathForDirectory(directory);
  return Pubspec.parse(readTextFile(filePath));
}

/// Builder to build a [MelosWorkspace] that is entirely virtual and only exists
/// in memory.
class VirtualWorkspaceBuilder {
  VirtualWorkspaceBuilder(
    this.melosYaml, {
    String? path,
    this.defaultPackagesPath = 'packages',
    this.sdkPath,
    Logger? logger,
  })  : logger = (logger ?? TestLogger()).toMelosLogger(),
        path =
            path ?? (currentPlatform.isWindows ? r'\\workspace' : '/workspace');

  /// The contents of the melos.yaml file, to configure the workspace.
  final String melosYaml;

  /// The absolute path to the workspace.
  late final String path;

  /// The path relative to the workspace root, where packages are located,
  /// unless a path is provided in [addPackage].
  final String defaultPackagesPath;

  /// The logger to build the workspace with.
  final MelosLogger logger;

  /// Optional Dart/Flutter SDK path.
  final String? sdkPath;

  Map<String, Object?> get _defaultWorkspaceConfig => {
        'name': 'virtual-workspace',
        'packages': ['$defaultPackagesPath/**'],
      };

  final List<_VirtualPackage> _packages = [];

  /// Adds a virtual package to the workspace.
  ///
  /// Use [path] to specify where this packages is located, relative to the
  /// workspace root. Per default packages are located at
  /// [defaultPackagesPath]/$PACKAGE_NAME$.
  void addPackage(
    String pubspecYaml, {
    String? path,
  }) {
    _packages.add(_VirtualPackage(pubspecYaml, path: path));
  }

  /// Build the workspace based on the current configuration of this builder.
  MelosWorkspace build() {
    final config = MelosWorkspaceConfig.fromYaml(
      {
        ..._defaultWorkspaceConfig,
        ...loadYaml(melosYaml) as Map<Object?, Object?>? ?? {},
      },
      path: path,
    );

    final packageMap = _buildVirtualPackageMap(_packages, logger);

    return MelosWorkspace(
      name: config.name,
      path: config.path,
      config: config,
      allPackages: packageMap,
      filteredPackages: packageMap,
      dependencyOverridePackages: _buildVirtualPackageMap(const [], logger),
      logger: logger,
      sdkPath: sdkPath,
    );
  }

  PackageMap _buildVirtualPackageMap(
    List<_VirtualPackage> packages,
    MelosLogger logger,
  ) {
    final packageMap = <String, Package>{};

    for (final package in packages) {
      final pubspec = Pubspec.parse(package.pubspecYaml);
      final name = pubspec.name;
      final pathRelativeToWorkspace =
          package.path ?? '$defaultPackagesPath/$name';
      packageMap[name] = Package(
        pubspec: pubspec,
        name: name,
        path: '$path/$pathRelativeToWorkspace',
        version: pubspec.version ?? Version.none,
        publishTo: pubspec.publishTo.let(Uri.parse),
        dependencies: pubspec.dependencies.keys.toList(),
        devDependencies: pubspec.devDependencies.keys.toList(),
        dependencyOverrides: pubspec.dependencyOverrides.keys.toList(),
        packageMap: packageMap,
        pathRelativeToWorkspace: pathRelativeToWorkspace,
        categories: [],
      );
    }

    return PackageMap(packageMap, logger);
  }
}

final defaultTestEnvironment = {
  'sdk': VersionConstraint.parse('>=2.12.0 <3.0.0'),
};

class _VirtualPackage {
  _VirtualPackage(
    this.pubspecYaml, {
    this.path,
  });

  final String pubspecYaml;

  final String? path;
}

class HttpClientMock extends http_testing.MockClient {
  HttpClientMock(super.fn);

  static Future<http.Response> parseResponse(String result) async {
    return http.Response(result, 200);
  }
}

extension StringTestExtension on String {
  String normalizeNewLines() => replaceAll('\r\n', '\n');
}
