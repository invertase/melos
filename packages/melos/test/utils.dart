import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:http/http.dart' as http;
import 'package:melos/melos.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/yamlicious/yaml_writer.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/scaffolding.dart';
import 'package:yaml/yaml.dart';

class TestLogger extends StandardLogger {
  final _buffer = StringBuffer();

  /// All the logs in order that were emitted so far.
  ///
  /// This includes both [stdout], [stderr] and [trace].
  /// Logs from [trace] and [stderr] are respectively prefixed by `t-` and `e-`
  /// such that:
  ///
  /// ```dart
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
  /// This both ensures that tests to not forget to check errors and
  /// allows testing what the logs would actually look like.
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

Directory createTemporaryWorkspaceDirectory({
  MelosWorkspaceConfig Function(String path)? configBuilder,
}) {
  configBuilder ??= (path) => MelosWorkspaceConfig.fallback(path: path);

  final dir =
      Directory(join(Directory.current.path, '.dart_tool')).createTempSync();
  addTearDown(() => dir.delete(recursive: true));
  final path = currentPlatform.isWindows
      ? windows.normalize(dir.path).replaceAll(r'\', r'\\')
      : dir.path;
  final config = (configBuilder(path)..validatePhysicalWorkspace()).toJson();

  File(join(path, 'melos.yaml')).writeAsStringSync(toYamlString(config));

  return dir;
}

Future<Directory> createProject(
  Directory workspace,
  PubSpec partialPubSpec, {
  String? path,
}) async {
  final pubSpec = partialPubSpec.environment != null
      ? partialPubSpec
      : partialPubSpec.copy(
          environment: Environment.fromJson(<Object?, Object?>{
            'sdk': '>=2.10.0 <3.0.0',
          }),
        );

  assert(
    pubSpec.name != null,
    'Pubspecs of generated projects must have a name',
  );

  final projectDirectory = Directory(
    joinAll([
      workspace.path,
      if (path != null)
        path
      else ...[
        'packages',
        pubSpec.name!,
      ]
    ]),
  );

  projectDirectory.createSync(recursive: true);

  await pubSpec.save(projectDirectory);

  // Reach into unParsedYaml and determine whether this is a plugin that
  // supports Android.
  // If it is, create an empty main class file to appease flutter pub
  // get in case an add-to-app module is present in the workspace
  final androidPluginNode =
      // ignore: avoid_dynamic_calls
      pubSpec.unParsedYaml?['flutter']?['plugin']?['platforms']?['android']
          as Map?;

  if (androidPluginNode != null) {
    final package = androidPluginNode['package'] as String?;
    final pluginClass = androidPluginNode['pluginClass'] as String?;

    if (package != null && pluginClass != null) {
      final javaMainClassFile = File(
        joinAll([
          projectDirectory.path,
          'android/src/main/java',
          ...package.split('.'),
          '$pluginClass.java',
        ]),
      );
      javaMainClassFile.createSync(recursive: true);
    }
  }

  return projectDirectory;
}

PackageConfig packageConfigForPackageAt(Directory dir) {
  final source = File(
    join(
      dir.path,
      '.dart_tool',
      'package_config.json',
    ),
  ).readAsStringSync();

  return PackageConfig.fromJson(json.decode(source) as Map);
}

class PackageConfig {
  PackageConfig._(
    this._map, {
    required this.packages,
    required this.generator,
  });

  PackageConfig.fromJson(Map<Object?, Object?> json)
      : this._(
          json,
          generator: json['generator']! as String,
          packages: (json['packages']! as List)
              .cast<Map>()
              .map((e) => PackageDependencyConfig.fromJson(e))
              .toList(),
        );

  final Map _map;
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

  PackageDependencyConfig.fromJson(Map<Object?, Object?> json)
      : this._(
          json,
          name: json['name']! as String,
          rootUri: json['rootUri']! as String,
          packageUri: json['packageUri']! as String,
        );

  final String name;
  final String rootUri;
  final String packageUri;
  final Map _map;

  @override
  String toString() {
    return _map.toString();
  }
}

PubSpec pubSpecFromJsonFile({
  String path = 'test/test_assets/',
  required String fileName,
}) {
  final filePath = '$path$fileName';
  final jsonAsString = File(filePath).readAsStringSync();
  return PubSpec.fromJson(json.decode(jsonAsString) as Map);
}

/// Builder to build a [MelosWorkspace] that is entirely virtual and only exists
/// in memory.
class VirtualWorkspaceBuilder {
  VirtualWorkspaceBuilder(
    this.melosYaml, {
    this.path = '/workspace',
    this.defaultPackagesPath = 'packages',
    this.sdkPath,
    Logger? logger,
  }) : logger = logger ?? TestLogger() {
    if (currentPlatform.isWindows) {
      path = r'\\workspace';
    }
  }

  /// The contents of the melos.yaml file, to configure the workspace.
  final String melosYaml;

  /// The absolute path to the workspace.
  late String path;

  /// The path relative to the workspace root, where packages are located,
  /// unless a path is provided in [addPackage].
  final String defaultPackagesPath;

  /// The logger to build the workspace with.
  final Logger logger;

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
    String pubSpecYaml, {
    String? path,
  }) {
    _packages.add(_VirtualPackage(pubSpecYaml, path: path));
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
      logger: logger,
      sdkPath: sdkPath,
    );
  }

  PackageMap _buildVirtualPackageMap(
    List<_VirtualPackage> packages,
    Logger logger,
  ) {
    final packageMap = <String, Package>{};

    for (final package in packages) {
      final pubSpec = PubSpec.fromYamlString(package.pubSpecYaml);
      final name = pubSpec.name!;
      final pathRelativeToWorkspace =
          package.path ?? '$defaultPackagesPath/$name';
      packageMap[name] = Package(
        pubSpec: pubSpec,
        name: name,
        path: '$path/$pathRelativeToWorkspace',
        version: pubSpec.version ?? Version.none,
        publishTo: pubSpec.publishTo,
        dependencies: pubSpec.dependencies.keys.toList(),
        devDependencies: pubSpec.devDependencies.keys.toList(),
        dependencyOverrides: pubSpec.dependencyOverrides.keys.toList(),
        packageMap: packageMap,
        pathRelativeToWorkspace: pathRelativeToWorkspace,
      );
    }

    return PackageMap(packageMap, logger);
  }
}

class _VirtualPackage {
  _VirtualPackage(
    this.pubSpecYaml, {
    this.path,
  });

  final String pubSpecYaml;

  final String? path;
}

class HttpClientMock extends Mock implements http.Client {
  @override
  Future<http.Response> get(Uri? url, {Map<String, String>? headers}) {
    return super.noSuchMethod(
      Invocation.method(#get, [url], {#headers: headers}),
      returnValue: Future.value(http.Response('', 200)),
    ) as Future<http.Response>;
  }
}
