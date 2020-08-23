/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:path/path.dart' show relative, normalize;
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

// Various pubspec yaml keys.
const String _kName = 'name';
const String _kVersion = 'version';
const String _kPublishTo = 'publish_to';
const String _kDependencies = 'dependencies';
const String _kDevDependencies = 'dev_dependencies';
const String _kFlutter = 'flutter';
const String _kPlugin = 'plugin';

/// Enum representing what type of package this is.
enum PackageType {
  dartPackage,
  flutterPackage,
  flutterPlugin,
  flutterApp,
}

/// A workspace representation of a Dart package.
class MelosPackage {
  final MelosWorkspace _workspace;
  final Map _yamlContents;
  List<String> _registryVersions;
  final String _name;
  final String _path;

  /// Package name.
  /// As defined in pubspec.yaml.
  String get name => _name;

  /// Package version.
  /// As defined in pubspec.yaml.
  String get version => _yamlContents[_kVersion] as String;

  /// Package path.
  /// Fully qualified path to this package location.
  String get path => _path;

  /// Package path as a normalized sting relative to the root of the workspace.
  /// e.g. "packages/firebase_database".
  String get pathRelativeToWorkspace =>
      normalize(relative(_path, from: _workspace.path));

  /// Type of this package, e.g. [PackageType.flutterApp].
  PackageType get type {
    if (isFlutterApp) return PackageType.flutterApp;
    if (isFlutterPlugin) return PackageType.flutterPlugin;
    if (isFlutterPackage) return PackageType.flutterPackage;
    return PackageType.dartPackage;
  }

  MelosPackage._(this._name, this._path, this._yamlContents, this._workspace);

  /// Dependencies of this package.
  /// Sourced from pubspec.yaml.
  Map<String, dynamic> get dependencies {
    if (_yamlContents[_kDependencies] != null) {
      // ignore: omit_local_variable_types
      Map<String, dynamic> deps = {};
      _yamlContents[_kDependencies].keys.forEach((key) {
        deps[key as String] = _yamlContents[_kDependencies][key];
      });
      return deps;
    }
    return {};
  }

  /// Dev dependencies of this package.
  /// Sourced from pubspec.yaml.
  Map<String, dynamic> get devDependencies {
    if (_yamlContents[_kDevDependencies] != null) {
      // ignore: omit_local_variable_types
      Map<String, dynamic> devDeps = {};
      _yamlContents[_kDevDependencies].keys.forEach((key) {
        devDeps[key as String] = _yamlContents[_kDevDependencies][key];
      });
      return devDeps;
    }
    return {};
  }

  /// Build a Melos representation of a package from a pubspec file.
  static Future<MelosPackage> fromPubspecPathAndWorkspace(
      FileSystemEntity pubspecPath, MelosWorkspace workspace) async {
    final yamlFileContents = await loadYamlFile(pubspecPath.path);
    if (yamlFileContents == null) return null;
    final pluginName = yamlFileContents[_kName] as String;
    return MelosPackage._(
        pluginName, pubspecPath.parent.path, yamlFileContents, workspace);
  }

  /// Builds a dependency graph of this packages dependencies and their dependents.
  Future<Set<String>> getDependencyGraph({bool includeDev = true}) async {
    var dependencyGraph = <String>{};
    var workspaceGraph = await _workspace.getDependencyGraph();

    dependencies.keys.toSet().forEach((name) {
      dependencyGraph.add(name);
      var children = workspaceGraph[name];
      if (children != null && children.isNotEmpty) {
        dependencyGraph.addAll(children);
      }
    });

    if (includeDev) {
      devDependencies.keys.toSet().forEach((name) {
        dependencyGraph.add(name);
        var children = workspaceGraph[name];
        if (children != null && children.isNotEmpty) {
          dependencyGraph.addAll(children);
        }
      });
    }

    return dependencyGraph;
  }

  /// Execute a shell command inside this package.
  Future<int> exec(List<String> execArgs) async {
    final packagePrefix =
        '[${logger.ansi.blue + logger.ansi.emphasized(_name) + logger.ansi.noColor}]: ';

    var environment = {
      'MELOS_PACKAGE_NAME': name,
      'MELOS_PACKAGE_VERSION': version ?? 'none',
      'MELOS_PACKAGE_PATH': path,
      'MELOS_ROOT_PATH': _workspace.path,
    };

    // TODO what if it's not called 'example'?
    if (path.endsWith('example')) {
      var exampleParentPackagePath = Directory(path).parent.path;
      var exampleParentPackage = await fromPubspecPathAndWorkspace(
          File(
              '$exampleParentPackagePath${Platform.pathSeparator}pubspec.yaml'),
          _workspace);
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

  /// Queries the pub.dev registry for published versions of this package.
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

  /// Cleans up all Melos generated files for this package.
  void clean() {
    PackagesPubFile.fromDirectory(path).delete();
    PubspecLockPubFile.fromDirectory(path).delete();
    PackageConfigPubFile.fromDirectory(path).delete();
    if (isFlutterPackage) {
      FlutterPluginsPubFile.fromDirectory(path).delete();
      FlutterDependenciesPubFile.fromDirectory(path).delete();
    }
  }

  /// Returns whether this package is for Flutter.
  /// This is determined by whether the package depends on the Flutter SDK.
  bool get isFlutterPackage {
    final YamlMap dependencies = _yamlContents[_kDependencies] as YamlMap;
    if (dependencies == null) {
      return false;
    }
    return dependencies.containsKey(_kFlutter);
  }

  /// Returns whether this package is a Flutter app.
  /// This is determined by ensuring all the following conditions are met:
  ///  a) the package depends on the Flutter SDK.
  ///  b) the package does not define itself as a Flutter plugin inside pubspec.yaml.
  bool get isFlutterApp {
    // Must directly depend on the Flutter SDK.
    if (!isFlutterPackage) return false;
    // Must not have a Flutter plugin definition in it's pubspec.yaml.
    final YamlMap flutterSection = _yamlContents[_kFlutter] as YamlMap;
    if (flutterSection == null) {
      return true;
    }
    final YamlMap pluginSection = flutterSection[_kPlugin] as YamlMap;
    if (pluginSection == null) {
      return true;
    }
    // Package is a plugin not an app.
    return false;
  }

  /// Returns whether this package supports Flutter for Android.
  bool get flutterAppSupportsAndroid {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kAndroid);
  }

  /// Returns whether this package supports Flutter for Web.
  bool get flutterAppSupportsWeb {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kWeb);
  }

  /// Returns whether this package supports Flutter for Windows.
  bool get flutterAppSupportsWindows {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kWindows);
  }

  /// Returns whether this package supports Flutter for MacOS.
  bool get flutterAppSupportsMacos {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kMacos);
  }

  /// Returns whether this package supports Flutter for Linux.
  bool get flutterAppSupportsLinux {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kLinux);
  }

  /// Returns whether this package is a Flutter plugin.
  /// This is determined by whether the pubspec contains a flutter.plugin definition.
  bool get isFlutterPlugin {
    final YamlMap flutterSection = _yamlContents[_kFlutter] as YamlMap;
    if (flutterSection == null) {
      return false;
    }
    final YamlMap pluginSection = flutterSection[_kPlugin] as YamlMap;
    if (pluginSection == null) {
      return false;
    }
    return true;
  }

  /// Returns whether this package supports Flutter for Android.
  bool get flutterPluginSupportsAndroid {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kAndroid);
  }

  /// Returns whether this package supports Flutter for Web.
  bool get flutterPluginSupportsWeb {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kWeb);
  }

  /// Returns whether this package supports Flutter for Windows.
  bool get flutterPluginSupportsWindows {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kWindows);
  }

  /// Returns whether this package supports Flutter for MacOS.
  bool get flutterPluginSupportsMacos {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kMacos);
  }

  /// Returns whether this package supports Flutter for Linux.
  bool get flutterPluginSupportsLinux {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kLinux);
  }

  /// Returns whether this package is private (publish_to set to 'none').
  bool get isPrivate {
    if (!_yamlContents.containsKey(_kPublishTo)) return false;
    if (_yamlContents[_kPublishTo].runtimeType != String) return false;
    return _yamlContents[_kPublishTo] == 'none';
  }

  bool _flutterAppSupportsPlatform(String platform) {
    assert(platform == kIos ||
        platform == kAndroid ||
        platform == kWeb ||
        platform == kMacos ||
        platform == kWindows ||
        platform == kLinux);
    return File('$path${Platform.pathSeparator}$platform').existsSync();
  }

  bool _flutterPluginSupportsPlatform(String platform) {
    assert(platform == kIos ||
        platform == kAndroid ||
        platform == kWeb ||
        platform == kMacos ||
        platform == kWindows ||
        platform == kLinux);

    final YamlMap flutterSection = _yamlContents[_kFlutter] as YamlMap;
    if (flutterSection == null) {
      return false;
    }

    final YamlMap pluginSection = flutterSection[_kPlugin] as YamlMap;
    if (pluginSection == null) {
      return false;
    }

    final YamlMap platforms = pluginSection['platforms'] as YamlMap;
    if (platforms == null) {
      return false;
    }

    return platforms.containsKey(platform);
  }

  @override
  String toString() {
    return 'MelosPackage[$name@$version]';
  }
}
