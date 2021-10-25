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

import 'package:melos/src/common/git_repository.dart';
import 'package:melos/src/workspace_configs.dart';
import 'package:test/test.dart';

import 'matchers.dart';

void main() {
  group('VersionCommandConfigs', () {
    test('message/repository/linkToCommits are optional', () {
      // ignore: use_named_constants
      const value = VersionCommandConfigs();

      expect(value.branch, null);
      expect(value.message, null);
      expect(value.linkToCommits, null);
    });

    group('fromYaml', () {
      test('accepts empty object', () {
        expect(
          VersionCommandConfigs.fromYaml(const {}),
          VersionCommandConfigs.empty,
        );
      });

      test('throws if message is not a string', () {
        expect(
          () => VersionCommandConfigs.fromYaml(const {'message': 42}),
          throwsMelosConfigException(),
        );
      });

      test('throws if branch is not a string', () {
        expect(
          () => VersionCommandConfigs.fromYaml(const {'branch': 42}),
          throwsMelosConfigException(),
        );
      });

      test('throws if linkToCommits is not a bool', () {
        expect(
          () => VersionCommandConfigs.fromYaml(const {'linkToCommits': 42}),
          throwsMelosConfigException(),
        );
      });

      test('can decode values', () {
        expect(
          VersionCommandConfigs.fromYaml(
            const {
              'branch': 'branch',
              'message': 'message',
              'linkToCommits': true,
            },
          ),
          const VersionCommandConfigs(
            branch: 'branch',
            message: 'message',
            linkToCommits: true,
          ),
        );
      });
    });
  });

  group('CommandConfigs', () {
    test('defaults to empty version configs', () {
      expect(
        CommandConfigs.empty.version,
        VersionCommandConfigs.empty,
      );

      expect(
        // ignore: use_named_constants
        const CommandConfigs(),
        CommandConfigs.empty,
      );
    });

    group('fromYaml', () {
      test('supports `version` missing', () {
        expect(
          CommandConfigs.fromYaml(const {}),
          CommandConfigs.empty,
        );
      });

      test('can decode `version`', () {
        expect(
          CommandConfigs.fromYaml(const {
            'version': {
              'message': 'Hello world',
              'branch': 'master',
              'linkToCommits': true,
            }
          }),
          const CommandConfigs(
            version: VersionCommandConfigs(
              branch: 'master',
              message: 'Hello world',
              linkToCommits: true,
            ),
          ),
        );
      });

      test('throws if `version` is not a map', () {
        expect(
          () => CommandConfigs.fromYaml(const {'version': 42}),
          throwsMelosConfigException(),
        );
      });
    });
  });

  group('IDEConfigs', () {
    test('enables intelliJ by default', () {
      expect(
        IDEConfigs.empty.intelliJ.enabled,
        true,
      );
    });

    group('fromYaml', () {
      test('supports empty map', () {
        expect(
          IDEConfigs.fromYaml(const {}),
          isA<IDEConfigs>()
              .having((e) => e.intelliJ.enabled, 'intelliJ.enabled', true),
        );
      });

      test('throws if intelliJ is not an object', () {
        expect(
          () => IDEConfigs.fromYaml(const {'intellij': 42}),
          throwsMelosConfigException(),
        );
      });

      test('accepts booleans as intelliJ keys', () {
        expect(
          IDEConfigs.fromYaml(const {'intellij': true}),
          isA<IDEConfigs>()
              .having((e) => e.intelliJ.enabled, 'intelliJ.eneabled', true),
        );
      });
    });
  });

  group('IntelliJConfig', () {
    test('is enabled by default', () {
      expect(
        IntelliJConfig.empty.enabled,
        true,
      );
    });

    group('fromYaml', () {
      test('throws if yaml is not a boolean', () {
        expect(
          () => IntelliJConfig.fromYaml(const <dynamic, dynamic>{}),
          throwsMelosConfigException(),
        );
      });

      test('accepts booleans as yaml', () {
        expect(
          IntelliJConfig.fromYaml(false),
          const IntelliJConfig(enabled: false),
        );
      });
    });
  });

  group('MelosWorkspaceConfig', () {
    test(
        'throws if commands.version.linkToCommits == true but repository is missing',
        () {
      expect(
        () => MelosWorkspaceConfig(
          name: '',
          packages: const [],
          commands: const CommandConfigs(
            version: VersionCommandConfigs(linkToCommits: true),
          ),
          path: '/workspace',
        ),
        throwsMelosConfigException(),
      );
    });

    test('accepts commands.version.linkToCommits == true if repository exists',
        () {
      expect(
        () => MelosWorkspaceConfig(
          name: '',
          repository: GitHubRepository(owner: 'invertase', name: 'melos'),
          packages: const [],
          commands: const CommandConfigs(
            version: VersionCommandConfigs(linkToCommits: true),
          ),
          path: '/workspace',
        ),
        returnsNormally,
      );
    });

    group('fromYaml', () {
      test('throws if name is missing', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap({
              'packages': <Object?>['*']
            }),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if name is not a String', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap({'name': <Object?>[]}, defaults: configMapDefaults),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if name is not a valid dart package name', () {
        void testName(String name) {
          expect(
            () => MelosWorkspaceConfig.fromYaml(
              createYamlMap({'name': name}, defaults: configMapDefaults),
              path: '/workspace',
            ),
            throwsMelosConfigException(),
          );
        }

        testName('42');
        testName('hello/world');
        testName(r'hello$world');
        testName('hello"world');
        testName("hello'world");
        testName('hello#world');
        testName('hello`world');
        testName('hello!world');
        testName('hello?world');
        testName('hello~world');
        testName('hello,world');
        testName('hello.world');
        testName(r'hello\world');
        testName('hello|world');
        testName('hello world');
        testName('hello*world');
        testName('hello(world');
        testName('hello)world');
        testName('hello=world');
      });

      test('accepts valid dart package name', () {
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'hello_world'}, defaults: configMapDefaults),
          path: '/workspace',
        );
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'hello2'}, defaults: configMapDefaults),
          path: '/workspace',
        );
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'HELLO'}, defaults: configMapDefaults),
          path: '/workspace',
        );
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'hello-world'}, defaults: configMapDefaults),
          path: '/workspace',
        );
      });

      test('throws if packages is missing', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap({'name': 'package_name'}),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if packages is not a collection', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {'packages': <Object?, Object?>{}},
              defaults: configMapDefaults,
            ),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if packages value is not a String', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {
                'packages': [42]
              },
              defaults: configMapDefaults,
            ),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if packages is empty', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {'packages': <Object?>[]},
              defaults: configMapDefaults,
            ),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if ignore is not a List', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {'ignore': <Object?, Object?>{}},
              defaults: configMapDefaults,
            ),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if ignore value is not a String', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {
                'ignore': [42]
              },
              defaults: configMapDefaults,
            ),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if repository is not a string', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {'repository': 42},
              defaults: configMapDefaults,
            ),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if repository is not from a supported git repository host',
          () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {'repository': 'https://example.com'},
              defaults: configMapDefaults,
            ),
            path: '/workspace',
          ),
          throwsMelosConfigException(),
        );
      });

      test('accepts a GitHub repository', () {
        final config = MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {'repository': 'https://github.com/invertase/melos'},
            defaults: configMapDefaults,
          ),
          path: '/workspace',
        );
        final repository = config.repository! as GitHubRepository;

        expect(repository.owner, 'invertase');
        expect(repository.name, 'melos');
      });
    });
  });
}

Map<String, Object?> createYamlMap(
  Map<String, Object?> source, {
  Map<String, Object?>? defaults,
}) {
  return {
    if (defaults != null) ...defaults,
    ...source,
  };
}

/// Default values used by [MelosWorkspaceConfig.fromYaml].
const configMapDefaults = {
  'name': 'mono-root',
  'packages': ['packages/*'],
};
