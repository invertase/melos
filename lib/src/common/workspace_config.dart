import 'dart:io';

import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

import 'utils.dart';

class MelosWorkspaceConfig {
  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

  Map get environment => _yamlContents['environment'] as Map ?? {};

  Map get dependencies => _yamlContents['dependencies'] as Map ?? {};

  Map get devDependencies => _yamlContents['dev_dependencies'] as Map ?? {};

  String get version => _yamlContents['version'] as String;

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
