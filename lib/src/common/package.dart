import 'dart:async';
import 'dart:io';

import '../pub/pub_file.dart';
import '../pub/pub_file_flutter_plugins.dart';
import '../pub/pub_file_package_config.dart';
import '../pub/pub_file_packages.dart';
import '../pub/pub_file_pubspec_lock.dart';
import 'logger.dart';
import 'utils.dart';
import 'workspace.dart';

class MelosPackage {
  final Map _yamlContents;

  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

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
  Future<int> exec(List<String> execArgs) {
    final packagePrefix =
        '[${logger.ansi.blue + logger.ansi.emphasized(_name) + logger.ansi.noColor}]: ';

    final environment = {
      'MELOS_PACKAGE_NAME': name,
      'MELOS_PACKAGE_PATH': path,
      'MELOS_ROOT_PATH': currentWorkspace.path,
    };

    return startProcess(execArgs,
        environment: environment,
        workingDirectory: path,
        prefix: packagePrefix);
  }

  // TODO(salakar): conditionally write these files only if they exist in root
  Future<void> linkPackages(MelosWorkspace workspace) async {
    await Future.forEach([
      PackagesPubFile.fromWorkspacePackage(workspace, this),
      FlutterPluginsPubFile.fromWorkspacePackage(workspace, this),
      PubspecLockPubFile.fromWorkspacePackage(workspace, this),
      PackageConfigPubFile.fromWorkspacePackage(workspace, this),
    ], (Future<PubFile> future) async {
      PubFile pubFile = await future;
      return pubFile.write();
    });

    // TODO(salakar): .flutter-plugins-dependencies
  }

  void clean() {
    PackagesPubFile.fromDirectory(path).delete();
    FlutterPluginsPubFile.fromDirectory(path).delete();
    PubspecLockPubFile.fromDirectory(path).delete();
    PackageConfigPubFile.fromDirectory(path).delete();
    // TODO(salakar): .flutter-plugins-dependencies
  }
}
