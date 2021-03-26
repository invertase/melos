import 'package:melos/src/common/workspace_command_config.dart';
import 'package:melos/src/common/workspace_config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('MelosWorkspaceConfig', () {
    group('command section', () {
      test('does not fail when missing from file', () {
        expect(() {
          final config = createTestWorkspaceConfig({
            'name': 'mono-root',
            'packages': ['packages/*'],
          });
          return config.commands;
        }, returnsNormally);
      });

      test('produces a commands map when provided', () {
        final config = createTestWorkspaceConfig({
          'command': {
            'version': {},
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
      final commandConfig = MelosWorkspaceCommandConfigs({
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
      final commandConfig = MelosWorkspaceCommandConfigs({});
      final versionConfig = commandConfig.configForCommandNamed('version');
      expect(versionConfig, isNotNull);
      expect(versionConfig.keys, isEmpty);
    });

    test('can be constructed without a backing map', () {
      final commandConfig = MelosWorkspaceCommandConfigs();
      final versionConfig = commandConfig.configForCommandNamed('version');
      expect(versionConfig, isNotNull);
    });

    group('fromYaml', () {
      test('can be constructed with a null yaml map', () {
        expect(
          () => MelosWorkspaceCommandConfigs.fromYaml(null),
          returnsNormally,
        );
      });

      test('fails if command configs are not maps', () {
        final commandSection = createYamlMap({
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

        final commandSection = createYamlMap({
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
  Map<String, dynamic> configMap = const {},
]) {
  return MelosWorkspaceConfig.fromYaml(
      createYamlMap(configMap, defaults: configMapDefaults));
}

YamlMap createYamlMap(Map<String, dynamic> configMap,
    {Map<String, dynamic> defaults = const {}}) {
  return YamlMap.wrap({
    ...defaults,
    ...configMap,
  }, sourceUrl: '/mono-root/melos.yaml');
}
