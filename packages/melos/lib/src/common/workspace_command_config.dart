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

import 'package:yaml/yaml.dart';

import 'workspace_config.dart';

/// Command-specific configuration information, as represented in the
/// `melos.yaml`'s `command` section.
class MelosWorkspaceCommandConfigs {
  /// Constructs a new command config map from a mapping of command names to
  /// their associated config maps.
  MelosWorkspaceCommandConfigs({
    required Map<String, Map<String, Object?>> configsByCommandName,
  }) : _configsByCommandName = {
          for (final entry in configsByCommandName.entries)
            entry.key: MelosCommandConfig(entry.key, entry.value),
        };

  /// Constructs a new command config map from a [YamlMap] representation of the
  /// `melos.yaml` `command` section.
  ///
  /// [yamlConfigsByCommandName] is expected to be a YamlMap of YamlMaps, or
  /// `null`.
  factory MelosWorkspaceCommandConfigs.fromYaml(
    YamlMap? yamlConfigsByCommandName,
  ) {
    if (yamlConfigsByCommandName == null) {
      return MelosWorkspaceCommandConfigs(configsByCommandName: {});
    }

    // Validate the YAML's shape, and massage it into the typing we want.
    final configsByCommandName = yamlConfigsByCommandName.map(
      (Object? commandName, Object? commandConfig) {
        if (commandConfig is! YamlMap) {
          throw MelosConfigException(
            'command.$commandName section must contain a map',
          );
        }

        return MapEntry(
          commandName.toString(),
          commandConfig.cast<String, Object?>(),
        );
      },
    );

    return MelosWorkspaceCommandConfigs(
      configsByCommandName: configsByCommandName,
    );
  }

  final Map<String, MelosCommandConfig> _configsByCommandName;

  /// Returns the `melos.yaml` configuration for the command named [name].
  ///
  /// If no config exists, an empty config will be returned.
  MelosCommandConfig configForCommandNamed(String name) {
    return _configsByCommandName[name] ??= MelosCommandConfig(
      name,
      const <String, Object?>{},
    );
  }
}

/// The `melos.yaml` configuration information for a single command.
class MelosCommandConfig {
  MelosCommandConfig(
    this.commandName,
    Map<String, Object?> configEntries,
  ) : _configEntries = configEntries;

  /// Name of this configuration's associated command.
  final String commandName;
  final Map<String, Object?> _configEntries;

  /// The keys of this configuration's entries.
  Iterable<String> get keys => _configEntries.keys;

  /// Returns the config entry named [name], or `null` if none exists.
  String? getString(String name) => _configEntries[name] as String?;
}
