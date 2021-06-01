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
 */

import 'package:melos/src/common/workspace_command_config.dart';
import 'package:melos/src/common/workspace_config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('MelosWorkspaceConfig', () {
    group('command section', () {
      test('does not fail when missing from file', () {
        final config = createTestWorkspaceConfig(<String, dynamic>{
          'name': 'mono-root',
          'packages': ['packages/*'],
        });

        // reading the commands, which implicitly deserialize the YAML
        // ignore: unnecessary_statements
        config.commands;
      });

      test('produces a commands map when provided', () {
        final config = createTestWorkspaceConfig(<String, dynamic>{
          'command': {
            'version': <String, dynamic>{},
          },
        });
        expect(config.commands, isA<MelosWorkspaceCommandConfigs>());
      });

      test('produces a commands map even when missing from file', () {
        final config = createTestWorkspaceConfig();
        expect(config.commands, isA<MelosWorkspaceCommandConfigs>());
      });
    });
  });

  group('MelosWorkspaceCommandConfigs', () {
    test('vends command-specific config objects', () {
      const expectedMessage = 'Version message';
      const expectedTagPrefix = 'v';
      final commandConfig = MelosWorkspaceCommandConfigs(configsByCommandName: {
        'version': {
          'message': expectedMessage,
        },
        'publish': {
          'tagPrefix': expectedTagPrefix,
        },
      });

      final versionConfig = commandConfig.configForCommandNamed('version');
      expect(versionConfig, isNotNull);
      expect(versionConfig.getString('message'), expectedMessage);

      final publishConfig = commandConfig.configForCommandNamed('publish');
      expect(publishConfig, isNotNull);
      expect(publishConfig.getString('tagPrefix'), expectedTagPrefix);
    });

    test(
        'vends (empty) command configs even when not provided in the '
        'backing map', () {
      final commandConfig =
          MelosWorkspaceCommandConfigs(configsByCommandName: {});
      final versionConfig = commandConfig.configForCommandNamed('version');
      expect(versionConfig, isNotNull);
      expect(versionConfig.keys, isEmpty);
    });

    group('fromYaml', () {
      test('can be constructed with a null yaml map', () {
        expect(
          () => MelosWorkspaceCommandConfigs.fromYaml(null),
          returnsNormally,
        );
      });

      test('fails if command configs are not maps', () {
        final commandSection = createYamlMap(<String, dynamic>{
          'version': ['should', 'be', 'a', 'map'],
        });

        expect(
          () => MelosWorkspaceCommandConfigs.fromYaml(commandSection),
          throwsA(isA<MelosConfigException>()),
        );
      });

      test('succeeds with a well-formed config', () {
        const expectedMessage = 'This is my message';
        const expectedPrefix = 'v';

        final commandSection = createYamlMap(<String, dynamic>{
          'version': {
            'message': expectedMessage,
          },
          'publish': {
            'tagPrefix': expectedPrefix,
          },
        });
        final commandConfig =
            MelosWorkspaceCommandConfigs.fromYaml(commandSection);

        expect(
          commandConfig.configForCommandNamed('version').getString('message'),
          expectedMessage,
        );
        expect(
          commandConfig.configForCommandNamed('publish').getString('tagPrefix'),
          expectedPrefix,
        );
      });
    });
  });
}

/// Default values used by [createTestWorkspaceConfig].
const configMapDefaults = {
  'name': 'mono-root',
  'packages': ['packages/*'],
};

/// [configMap] is a map representation of `melos.yaml` contents
MelosWorkspaceConfig createTestWorkspaceConfig([
  Map<String, dynamic> configMap = const <String, dynamic>{},
]) {
  return MelosWorkspaceConfig.fromYaml(
    createYamlMap(configMap, defaults: configMapDefaults),
  );
}

YamlMap createYamlMap(Map<String, dynamic> configMap,
    {Map<String, dynamic> defaults = const <String, dynamic>{}}) {
  return YamlMap.wrap(<String, dynamic>{
    ...defaults,
    ...configMap,
  }, sourceUrl: '/mono-root/melos.yaml');
}
