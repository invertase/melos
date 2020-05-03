import 'dart:io';

import 'package:glob/glob.dart';
import 'package:melos_cli/src/common/utils.dart';
import 'package:yaml/yaml.dart';

class MelosWorkspaceConfig {
  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

  final Map _yamlContents;

  MelosWorkspaceConfig._(this._name, this._path, this._yamlContents);

  List<Glob> get packages {
    final globs = _yamlContents['packages'] as YamlList;
    if (globs == null) return <Glob>[];
    return globs.map((globString) => Glob(globString as String)).toList();
  }

  static Future<MelosWorkspaceConfig> fromDirectory(Directory directory) async {
    if (!isWorkspaceDirectory(directory)) {
      return null;
    }

    final melosYamlPath = melosYamlPathForDirectory(directory);
    final yamlContents = await loadYamlFile(melosYamlPath);
    if (yamlContents == null) {
      return null;
    }

    return MelosWorkspaceConfig._(
        yamlContents['name'] as String, directory.path, yamlContents);
  }
}
