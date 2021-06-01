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
import 'workspace_command_config.dart';
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

  /// Constructs a workspace config from a [YamlMap] representation of
  /// `melos.yaml`.
  factory MelosWorkspaceConfig.fromYaml(YamlMap yamlMap) {
    final melosYamlPath = yamlMap.span.sourceUrl?.toFilePath();
    assert(
      melosYamlPath != null,
      'Config yaml does not have an associated path. Was it loaded from disk?',
    );

    return MelosWorkspaceConfig._(
      yamlMap['name'] as String,
      dirname(melosYamlPath!),
      yamlMap,
    );
  }

  static Directory? _searchForAncestorDirectoryWithMelosYaml(Directory from) {
    for (var testedDirectory = from;
        testedDirectory.path != testedDirectory.parent.path;
        testedDirectory = testedDirectory.parent) {
      if (isWorkspaceDirectory(testedDirectory)) {
        return testedDirectory;
      }
    }
    return null;
  }

  /// Creates a new configuration from a [directory].
  ///
  /// If no `melos.yaml` is found, but [directory] contains a `packages/`
  /// sub-directory, a configuration for those packages will be created.
  static Future<MelosWorkspaceConfig?> fromDirectory(
    Directory directory,
  ) async {
    final melosWorkspaceDirectory =
        _searchForAncestorDirectoryWithMelosYaml(directory);

    if (melosWorkspaceDirectory == null) {
      // Allow melos to use a project without a `melos.yaml` file if a `packages`
      // directory exists.
      final packagesDirectory =
          Directory(joinAll([directory.path, 'packages']));
      if (packagesDirectory.existsSync()) {
        return MelosWorkspaceConfig._(
          'Melos',
          directory.path,
          loadYaml(_yamlConfigDefault) as Map,
        );
      }

      return null;
    }

    final melosYamlPath = melosYamlPathForDirectory(melosWorkspaceDirectory);
    final yamlContents = await loadYamlFile(melosYamlPath);
    if (yamlContents == null) {
      return null;
    }

    return MelosWorkspaceConfig.fromYaml(yamlContents);
  }

  final Map _yamlContents;

  /// The name of the workspace.
  String get name => _name;
  final String _name;

  /// The path to the root of this workspace.
  String get path => _path;
  final String _path;

  /// `true` if this workspace is configured to generate an IntelliJ IDE
  /// project via `melos bootstrap`.
  bool get generateIntellijIdeFiles {
    final ide = _yamlContents['ide'] as Map<String, Object?>? ?? {};

    return ide['intellij'] as bool? ?? true;
  }

  /// A list of glob patterns indicating the locations of this workspace's
  /// packages.
  List<String> get packages {
    final patterns = _yamlContents['packages'] as YamlList?;

    if (patterns == null) return <String>[];
    return List<String>.from(patterns);
  }

  /// A list of glob patterns that should be ignored when determining the
  /// workspace's packages.
  List<String> get ignore {
    final patterns = _yamlContents['ignore'] as YamlList?;

    if (patterns == null) return <String>[];
    return List<String>.from(patterns);
  }

  /// Scripts defined by the workspace.
  MelosWorkspaceScripts get scripts => MelosWorkspaceScripts(
        Map.from(_yamlContents['scripts'] as YamlMap? ?? {}),
      );

  /// Command-specific configurations defined by the workspace.
  late final MelosWorkspaceCommandConfigs commands =
      MelosWorkspaceCommandConfigs.fromYaml(
    _yamlContents['command'] as YamlMap?,
  );
}

/// Thrown when `melos.yaml` configuration is malformed.
class MelosConfigException implements Exception {
  MelosConfigException(this.message);

  final String message;

  @override
  String toString() => 'melos.yaml: $message';
}
