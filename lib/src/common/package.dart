import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;

import '../pub/pub_file.dart';
import '../pub/pub_file_flutter_dependencies.dart';
import '../pub/pub_file_flutter_plugins.dart';
import '../pub/pub_file_package_config.dart';
import '../pub/pub_file_packages.dart';
import '../pub/pub_file_pubspec_lock.dart';
import 'logger.dart';
import 'utils.dart';
import 'workspace.dart';

/// Key for windows platform.
const String kWindows = 'windows';

/// Key for macos platform.
const String kMacos = 'macos';

/// Key for linux platform.
const String kLinux = 'linux';

/// Key for IPA (iOS) platform.
const String kIos = 'ios';

/// Key for APK (Android) platform.
const String kAndroid = 'android';

/// Key for Web platform.
const String kWeb = 'web';

class MelosPackage {
  final Map _yamlContents;
  List<String> _registryVersions;

  final String _name;

  String get name => _name;

  String get version => _yamlContents['version'] as String;

  final String _path;

  String get path => _path;

  String get pathInWorkspace =>
      _path.replaceFirst('${currentWorkspace.path}/', '');

  MelosPackage._(this._name, this._path, this._yamlContents);

  Set<String> get dependenciesSet {
    if (_yamlContents['dependencies'] != null) {
      // ignore: omit_local_variable_types
      Set<String> keysSet = <String>{};
      _yamlContents['dependencies'].keys.forEach((key) {
        keysSet.add(key as String);
      });
      return keysSet;
    }
    return {};
  }

  Map<String, dynamic> get devDependencies {
    if (_yamlContents['dev_dependencies'] != null) {
      // ignore: omit_local_variable_types
      Map<String, dynamic> devDeps = {};
      _yamlContents['dev_dependencies'].keys.forEach((key) {
        devDeps[key as String] = _yamlContents['dev_dependencies'][key];
      });
      return devDeps;
    }
    return {};
  }

  Set<String> get devDependenciesSet {
    if (_yamlContents['dev_dependencies'] != null) {
      // ignore: omit_local_variable_types
      Set<String> keysSet = <String>{};
      _yamlContents['dev_dependencies'].keys.forEach((key) {
        keysSet.add(key as String);
      });
      return keysSet;
    }
    return {};
  }

  static Future<MelosPackage> fromPubspecPath(
      FileSystemEntity pubspecPath) async {
    final yamlFileContents = await loadYamlFile(pubspecPath.path);
    if (yamlFileContents == null) return null;
    final pluginName = yamlFileContents['name'] as String;
    return MelosPackage._(
        pluginName, pubspecPath.parent.path, yamlFileContents);
  }

  Future<Set<String>> getDependencyGraph({bool includeDev = true}) async {
    var dependencyGraph = <String>{};
    var workspaceGraph = await currentWorkspace.getDependencyGraph();

    dependenciesSet.forEach((name) {
      dependencyGraph.add(name);
      var children = workspaceGraph[name];
      if (children != null && children.isNotEmpty) {
        dependencyGraph.addAll(children);
      }
    });

    if (includeDev) {
      devDependenciesSet.forEach((name) {
        dependencyGraph.add(name);
        var children = workspaceGraph[name];
        if (children != null && children.isNotEmpty) {
          dependencyGraph.addAll(children);
        }
      });
    }

    return dependencyGraph;
  }

  /// Execute a command from this packages root directory.
  Future<int> exec(List<String> execArgs) async {
    final packagePrefix =
        '[${logger.ansi.blue + logger.ansi.emphasized(_name) + logger.ansi.noColor}]: ';

    var environment = {
      'MELOS_PACKAGE_NAME': name,
      'MELOS_PACKAGE_VERSION': version ?? '0.0.0',
      'MELOS_PACKAGE_PATH': path,
      'MELOS_ROOT_PATH': currentWorkspace.path,
    };

    if (path.endsWith('example')) {
      var exampleParentPackagePath = Directory(path).parent.path;
      var exampleParentPackage = await fromPubspecPath(File(
          '$exampleParentPackagePath${Platform.pathSeparator}pubspec.yaml'));
      if (exampleParentPackage != null) {
        environment['MELOS_PARENT_PACKAGE_NAME'] = exampleParentPackage.name;
        environment['MELOS_PARENT_PACKAGE_VERSION'] =
            exampleParentPackage.version;
        environment['MELOS_PARENT_PACKAGE_PATH'] = exampleParentPackage.path;
      }
    }

    return startProcess(execArgs,
        environment: environment,
        workingDirectory: path,
        prefix: packagePrefix);
  }

  /// Generates Pub/Flutter related temporary files such as .packages or pubspec.lock.
  Future<void> linkPackages(MelosWorkspace workspace) async {
    // Dart specific files.
    await Future.forEach([
      PackagesPubFile.fromWorkspacePackage(workspace, this),
      PubspecLockPubFile.fromWorkspacePackage(workspace, this),
      PackageConfigPubFile.fromWorkspacePackage(workspace, this),
    ], (Future<PubFile> future) async {
      PubFile pubFile = await future;
      return pubFile.write();
    });

    // Additional Flutter application specific files, only if package is an App.
    if (isFlutterApp) {
      await Future.forEach([
        FlutterPluginsPubFile.fromWorkspacePackage(workspace, this),
        FlutterDependenciesPubFile.fromWorkspacePackage(workspace, this),
      ], (Future<PubFile> future) async {
        PubFile pubFile = await future;
        return pubFile.write();
      });
    }
  }

  /// Queries the registry for published versions of this package.
  /// Primarily used for publish filters and versioning.
  Future<List<String>> getPublishedVersions() async {
    if (_registryVersions != null) {
      return _registryVersions;
    }
    var url = 'https://pub.dev/packages/$name.json';
    var response = await http.get(url);
    if (response.statusCode == 404) {
      return [];
    } else if (response.statusCode != 200) {
      throw Exception(
          'Error reading pub.dev registry for package "$name" (HTTP Status ${response.statusCode}), response: ${response.body}');
    }
    var versions = <String>[];
    var versionsRaw = json.decode(response.body)['versions'] as List<dynamic>;
    versionsRaw.forEach((element) {
      versions.add(element as String);
    });
    versions.sort();
    _registryVersions = versions.reversed.toList();
    return _registryVersions;
  }

  /// Cleans up all Melos generated files in this package.
  void clean() {
    PackagesPubFile.fromDirectory(path).delete();
    PubspecLockPubFile.fromDirectory(path).delete();
    PackageConfigPubFile.fromDirectory(path).delete();
    if (isFlutterPackage) {
      FlutterPluginsPubFile.fromDirectory(path).delete();
      FlutterDependenciesPubFile.fromDirectory(path).delete();
    }
  }

  bool supportsFlutterPlatform(String platform) {
    assert(platform == kIos ||
        platform == kAndroid ||
        platform == kWeb ||
        platform == kMacos ||
        platform == kWindows ||
        platform == kLinux);

    final YamlMap flutterSection = _yamlContents['flutter'] as YamlMap;
    if (flutterSection == null) {
      return false;
    }

    final YamlMap pluginSection = flutterSection['plugin'] as YamlMap;
    if (pluginSection == null) {
      return false;
    }

    final YamlMap platforms = pluginSection['platforms'] as YamlMap;
    if (platforms == null) {
      return false;
    }

    return platforms.containsKey(platform);
  }

  /// Returns whether this package is for Flutter.
  /// This is determined by whether the package depends on the Flutter SDK.
  bool get isFlutterPackage {
    final YamlMap dependencies = _yamlContents['dependencies'] as YamlMap;
    if (dependencies == null) {
      return false;
    }
    return dependencies.containsKey('flutter');
  }

  /// Returns whether this package is a Flutter app.
  /// This is determined by ensuring all the following conditions are met:
  ///  a) the package depends on the Flutter SDK.
  ///  b) the package does not define itself as a Flutter plugin inside pubspec.yaml.
  bool get isFlutterApp {
    // Must directly depend on the Flutter SDK.
    if (!isFlutterPackage) return false;

    // Must not have a Flutter plugin definition in it's pubspec.yaml.
    final YamlMap flutterSection = _yamlContents['flutter'] as YamlMap;
    if (flutterSection == null) {
      return true;
    }
    final YamlMap pluginSection = flutterSection['plugin'] as YamlMap;
    if (pluginSection == null) {
      return true;
    }

    // Package is a plugin not an app.
    return false;
  }

  /// Returns whether this package supports Flutter for Android.
  bool get supportsFlutterAndroid {
    return supportsFlutterPlatform(kAndroid);
  }
  /// Returns whether this package supports Flutter for Web.
  bool get supportsFlutterWeb {
    return supportsFlutterPlatform(kWeb);
  }

  /// Returns whether this package supports Flutter for Windows.
  bool get supportsFlutterWindows {
    return supportsFlutterPlatform(kWindows);
  }

  /// Returns whether this package supports Flutter for MacOS.
  bool get supportsFlutterMacos {
    return supportsFlutterPlatform(kMacos);
  }

  /// Returns whether this package supports Flutter for Linux.
  bool get supportsFlutterLinux {
    return supportsFlutterPlatform(kLinux);
  }

  /// Returns whether this package is private (publish_to set to 'none').
  bool get isPrivate {
    if (!_yamlContents.containsKey('publish_to')) return false;
    if (_yamlContents['publish_to'].runtimeType != String) return false;
    return _yamlContents['publish_to'] == 'none';
  }

  @override
  String toString() {
    return 'MelosPackage[$name@$version]';
  }
}
