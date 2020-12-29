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

import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import 'utils.dart';
import 'workspace_scripts.dart';

String get _yamlConfigDefault {
  return '''
name: Melos
packages:
  - packages/**
environment:
  sdk: '>=$currentDartVersion <$nextDartMajorVersion'
''';
}

// TODO document & cleanup class members.
// TODO validation of config e.g. name should be alphanumeric dasherized/underscored
class MelosWorkspaceConfig {
  /// Does the melos.yaml file exist.
  /// Can be false if the default configuration is used without a file present.
  final bool exists;

  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

  Map get environment => map['environment'] as Map ?? {};

  MelosWorkspaceScripts get scripts =>
      MelosWorkspaceScripts(map['scripts'] as Map ?? {});

  Map get dependencies => map['dependencies'] as Map ?? {};

  Map get devDependencies => map['dev_dependencies'] as Map ?? {};

  String get version => map['version'] as String;

  bool get generateIntellijIdeFiles {
    var ide = map['ide'] as Map ?? {};
    if (ide['intellij'] == false) return false;
    if (ide['intellij'] == true) return true;
    return true;
  }

  bool get environmentExists {
    return map['environment'] != null && map['environment'] is Map;
  }

  String get environmentSdkVersion {
    if (!environmentExists) return null;
    return map['environment']['sdk'] as String;
  }

  String get environmentFlutterVersion {
    if (!environmentExists) return null;
    return map['environment']['flutter'] as String;
  }

  final Map map;

  MelosWorkspaceConfig._(this._name, this._path, this.map, this.exists);

  List<String> get packages {
    final patterns = map['packages'] as YamlList;
    if (patterns == null) return <String>[];
    return List<String>.from(patterns);
  }

  /// Glob patterns defined in "melos.yaml" ignore of packages to always exclude
  /// regardless of any custom CLI filter options.
  List<String> get ignore {
    final patterns = map['ignore'] as YamlList;
    if (patterns == null) return <String>[];
    return List<String>.from(patterns);
  }

  static Future<MelosWorkspaceConfig> fromDirectory(Directory directory) async {
    if (!isWorkspaceDirectory(directory)) {
      // Allow melos to use a project without a `melos.yaml` file if a `packages`
      // directory exists.
      Directory packagesDirectory =
          Directory(joinAll([directory.path, 'packages']));
      if (packagesDirectory.existsSync()) {
        return MelosWorkspaceConfig._('Melos', directory.path,
            loadYaml(_yamlConfigDefault) as Map, false);
      }

      return null;
    }

    final melosYamlPath = melosYamlPathForDirectory(directory);
    final map = await loadYamlFile(melosYamlPath);
    if (map == null) {
      return null;
    }

    return MelosWorkspaceConfig._(
        map['name'] as String, directory.path, map, true);
  }
}
