import 'dart:io';

import '../common/package.dart';
import '../common/utils.dart' as utils;
import '../common/workspace.dart';
import '../pub/pub_file.dart';

class FlutterPluginsPubFile extends PubFile {
  Map<String, String> _entries;

  Map<String, String> get entries {
    if (_entries != null) return _entries;

    var input = File(filePath).readAsStringSync();

    // ignore: omit_local_variable_types
    Map<String, String> packages = {};

    final regex = RegExp('^([a-z_A-Z0-9-]*)=(.*)\$', multiLine: true);

    regex.allMatches(input).forEach((match) {
      return packages[match[1]] = match[2];
    });

    _entries = packages;
    return _entries;
  }

  FlutterPluginsPubFile._(String rootDirectory) : super(rootDirectory, '.flutter-plugins');

  factory FlutterPluginsPubFile.fromDirectory(String fileRootDirectory) {
    return FlutterPluginsPubFile._(fileRootDirectory);
  }

  factory FlutterPluginsPubFile.fromWorkspacePackage(
      MelosWorkspace workspace, MelosPackage package) {
    var workspaceFlutterPluginsPubFile =
        FlutterPluginsPubFile.fromDirectory(workspace.path);

    // ignore: omit_local_variable_types
    Map<String, String> newEntries = {};
    var dependencyGraph = package.getDependencyGraph();

    workspaceFlutterPluginsPubFile.entries.forEach((name, path) {
      if (!dependencyGraph.contains(name) && name != package.name) {
        return;
      }

      var _path = path;
      if (path.contains(currentWorkspace.path)) {
        // path is fully qualified already, so we'll just make it relative
        _path = utils.relativePath(_path, package.path) + '/';
      }

      newEntries[name] = _path;
    });

    var flutterPluginsFile = FlutterPluginsPubFile._(package.path);
    flutterPluginsFile._entries = newEntries;
    return flutterPluginsFile;
  }

  @override
  String toString() {
    var string = '# This is a generated file; do not edit or check into version control.';
    _entries.forEach((key, value) {
      string += '\n$key=$value';
    });
    return string;
  }
}
