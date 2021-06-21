import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/scaffolding.dart';

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

Directory createTemporaryWorkspaceDirectory() {
  final dir = Directory.current.createTempSync();
  addTearDown(() => dir.delete(recursive: true));

  File(join(dir.path, 'melos.yaml')).writeAsStringSync(
    '''
name: test_workspace
packages:
  - packages/**
''',
  );

  return dir;
}

Future<Directory> createProject(
  Directory workspace,
  PubSpec partialPubSpec,
) async {
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
    join(
      workspace.path,
      'packages',
      pubSpec.name,
    ),
  );

  projectDirectory.createSync(recursive: true);

  await pubSpec.save(projectDirectory);

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
