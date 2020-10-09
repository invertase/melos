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

import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import 'utils.dart';

String _yamlConfigDefault = '''
name: Melos
packages:
  - packages/**
''';

// TODO validation of config
//   name should be required, alphanumeric dasherized/underscored
class MelosWorkspaceConfig {
  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

  Map get environment => _yamlContents['environment'] as Map ?? {};

  Map get scripts => _yamlContents['scripts'] as Map ?? {};

  Map get dependencies => _yamlContents['dependencies'] as Map ?? {};

  Map get devDependencies => _yamlContents['dev_dependencies'] as Map ?? {};

  String get version => _yamlContents['version'] as String;

  bool get generateIntellijIdeFiles {
    var ide = _yamlContents['ide'] as Map ?? {};
    if (ide['intellij'] == false) return false;
    if (ide['intellij'] == true) return true;
    return true;
  }

  final Map _yamlContents;

  MelosWorkspaceConfig._(this._name, this._path, this._yamlContents);

  List<Glob> get packages {
    final globs = _yamlContents['packages'] as YamlList;
    if (globs == null) return <Glob>[];
    return globs.map((globString) => Glob(globString as String)).toList();
  }

  static Future<MelosWorkspaceConfig> fromDirectory(Directory directory) async {
    if (!isWorkspaceDirectory(directory)) {
      // Allow melos to use a project without a `melos.yaml` file if a `packages`
      // directory exists.
      Directory packagesDirectory =
          Directory(joinAll([directory.path, 'packages']));
      if (packagesDirectory.existsSync()) {
        return MelosWorkspaceConfig._(
            'Melos', directory.path, loadYaml(_yamlConfigDefault) as Map);
      }

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
