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
''';
}

// TODO validation of config e.g. name should be alphanumeric dasherized/underscored
/// Represents the contents of `melos.yaml`.
class MelosWorkspaceConfig {
  MelosWorkspaceConfig._(this._name, this._path, this._yamlContents);

  final Map _yamlContents;

  /// The name of the workspace.
  String get name => _name;
  final String _name;

  /// The path to the root of this workspace.
  String get path => _path;
  final String _path;

  String get version => _yamlContents['version'] as String;

  /// `true` if this workspace is configured to generate an IntelliJ IDE
  /// project via `melos bootstrap`.
  bool get generateIntellijIdeFiles {
    final ide = _yamlContents['ide'] as Map ?? {};
    return ide['intellij'] is bool ? ide['intellij'] : true;
  }

  /// A list of glob patterns indicating the locations of this workspace's
  /// packages.
  List<String> get packages {
    final patterns = _yamlContents['packages'] as YamlList;
    if (patterns == null) return <String>[];
    return List<String>.from(patterns);
  }

  /// A list of glob patterns that should be ignored when determining the
  /// workspace's packages.
  List<String> get ignore {
    final patterns = _yamlContents['ignore'] as YamlList;
    if (patterns == null) return <String>[];
    return List<String>.from(patterns);
  }

  /// Scripts defined by the workspace.
  MelosWorkspaceScripts get scripts =>
      MelosWorkspaceScripts(_yamlContents['scripts'] as Map ?? {});

  /// Creates a new configuration from a [directory].
  ///
  /// If no `melos.yaml` is found, but [directory] contains a `packages/`
  /// sub-directory, a configuration for those packages will be returned.
  static Future<MelosWorkspaceConfig> fromDirectory(Directory directory) async {
    if (!isWorkspaceDirectory(directory)) {
      // Allow melos to use a project without a `melos.yaml` file if a `packages`
      // directory exists.
      final packagesDirectory =
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
