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

import 'package:melos/melos.dart';
import 'package:melos/src/common/git_repository.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/scripts.dart';
import 'package:test/test.dart';

import 'matchers.dart';

void main() {
  group('BootstrapCommandConfigs', () {
    test('usePubspecOverrides is optional', () {
      // ignore: use_named_constants
      const value = BootstrapCommandConfigs();

      expect(value.usePubspecOverrides, false);
    });

    test('runPubGetInParallel is optional', () {
      // ignore: use_named_constants
      const value = BootstrapCommandConfigs();

      expect(value.runPubGetInParallel, true);
    });

    group('fromYaml', () {
      test('accepts empty object', () {
        expect(
          BootstrapCommandConfigs.fromYaml(const {}),
          BootstrapCommandConfigs.empty,
        );
      });

      test('throws if usePubspecOverrides is not a bool', () {
        expect(
          () => BootstrapCommandConfigs.fromYaml(const {
            'usePubspecOverrides': 42,
          }),
          throwsMelosConfigException(),
        );
      });

      test('throws if runPubGetInParallel is not a bool', () {
        expect(
          () => BootstrapCommandConfigs.fromYaml(const {
            'runPubGetInParallel': 42,
          }),
          throwsMelosConfigException(),
        );
      });

      test('can decode values', () {
        expect(
          BootstrapCommandConfigs.fromYaml(
            const {
              'usePubspecOverrides': true,
              'runPubGetInParallel': false,
            },
          ),
          const BootstrapCommandConfigs(
            usePubspecOverrides: true,
            runPubGetInParallel: false,
          ),
        );
      });
    });
  });

  group('VersionCommandConfigs', () {
    test('defaults', () {
      const value = VersionCommandConfigs.empty;

      expect(value.branch, null);
      expect(value.message, null);
      expect(value.includeScopes, false);
      expect(value.includeCommitId, null);
      expect(value.linkToCommits, null);
      expect(value.updateGitTagRefs, false);
      expect(value.workspaceChangelog, false);
    });

    group('fromYaml', () {
      test('accepts empty object', () {
        expect(
          VersionCommandConfigs.fromYaml(const {}),
          VersionCommandConfigs.empty,
        );
      });

      test('throws if branch is not a string', () {
        expect(
          () => VersionCommandConfigs.fromYaml(const {'branch': 42}),
          throwsMelosConfigException(),
        );
      });

      test('throws if message is not a string', () {
        expect(
          () => VersionCommandConfigs.fromYaml(const {'message': 42}),
          throwsMelosConfigException(),
        );
      });

      test('throws if includeScopes is not a bool', () {
        expect(
          () => VersionCommandConfigs.fromYaml(const {'includeScopes': 42}),
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
              'includeScopes': true,
              'includeCommitId': true,
              'linkToCommits': true,
              'updateGitTagRefs': true,
              'workspaceChangelog': true,
            },
          ),
          const VersionCommandConfigs(
            branch: 'branch',
            message: 'message',
            includeScopes: true,
            includeCommitId: true,
            linkToCommits: true,
            updateGitTagRefs: true,
            workspaceChangelog: true,
          ),
        );
      });
    });
  });

  group('CommandConfigs', () {
    test('defaults to empty configs', () {
      expect(
        CommandConfigs.empty.bootstrap,
        BootstrapCommandConfigs.empty,
      );

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
      test('supports `bootstrap` and `version` missing', () {
        expect(
          CommandConfigs.fromYaml(const {}),
          CommandConfigs.empty,
        );
      });

      test('can decode `bootstrap`', () {
        expect(
          CommandConfigs.fromYaml(const {
            'bootstrap': {
              'usePubspecOverrides': true,
            }
          }),
          const CommandConfigs(
            bootstrap: BootstrapCommandConfigs(
              usePubspecOverrides: true,
            ),
          ),
        );
      });

      test('can decode `bootstrap` with pub get offline', () {
        expect(
          CommandConfigs.fromYaml(const {
            'bootstrap': {
              'runPubGetOffline': true,
            }
          }),
          const CommandConfigs(
            bootstrap: BootstrapCommandConfigs(
              runPubGetOffline: true,
            ),
          ),
        );
      });

      test('can decode `version`', () {
        expect(
          CommandConfigs.fromYaml(const {
            'version': {
              'message': 'Hello world',
              'branch': 'main',
              'linkToCommits': true,
            }
          }),
          const CommandConfigs(
            version: VersionCommandConfigs(
              branch: 'main',
              message: 'Hello world',
              linkToCommits: true,
            ),
          ),
        );
      });

      test('throws if `bootstrap` is not a map', () {
        expect(
          () => CommandConfigs.fromYaml(const {'bootstrap': 42}),
          throwsMelosConfigException(),
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
              .having((e) => e.intelliJ.enabled, 'intelliJ.enabled', true),
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

    test('has "melos_" moduleNamePrefix by default', () {
      expect(
        IntelliJConfig.empty.moduleNamePrefix,
        'melos_',
      );
    });

    group('fromYaml', () {
      test('yields default config from empty map', () {
        expect(
          IntelliJConfig.fromYaml(const <dynamic, dynamic>{}),
          IntelliJConfig.empty,
        );
      });

      test('supports "enabled"', () {
        expect(
          IntelliJConfig.fromYaml(const <dynamic, dynamic>{'enabled': false}),
          const IntelliJConfig(enabled: false),
        );
        expect(
          IntelliJConfig.fromYaml(const <dynamic, dynamic>{'enabled': true}),
          IntelliJConfig.empty,
        );
      });

      test('supports "moduleNamePrefix" override', () {
        expect(
          IntelliJConfig.fromYaml(
            const <dynamic, dynamic>{'moduleNamePrefix': 'prefix1'},
          ),
          const IntelliJConfig(moduleNamePrefix: 'prefix1'),
        );
      });

      test('yields "moduleNamePrefix" of "melos_" by default', () {
        expect(
          IntelliJConfig.fromYaml(const <dynamic, dynamic>{}).moduleNamePrefix,
          'melos_',
        );
      });

      group('legacy config support', () {
        test('accepts boolean as yaml', () {
          expect(
            IntelliJConfig.fromYaml(false),
            const IntelliJConfig(enabled: false),
          );
        });
        
        test('yields "moduleNamePrefix" of "melos_" by default', () {
          expect(
            IntelliJConfig.fromYaml(true).moduleNamePrefix,
            'melos_',
          );
        });
      });
    });
  });

  group('Scripts', () {
    group('exec', () {
      test('supports specifying command through "exec"', () {
        final scripts = Scripts.fromYaml(
          createYamlMap({
            'a': {
              'exec': 'b',
            },
          }),
          workspacePath: testWorkspacePath,
        );
        expect(scripts['a']!.run, 'b');
        expect(scripts['a']!.exec, ExecOptions());
      });

      test('supports specifying command through "run"', () {
        final scripts = Scripts.fromYaml(
          createYamlMap({
            'a': {
              'run': 'b',
              'exec': <String, Object?>{},
            },
          }),
          workspacePath: testWorkspacePath,
        );
        expect(scripts['a']!.run, 'b');
        expect(scripts['a']!.exec, ExecOptions());
      });

      test('supports specifying exec options', () {
        final scripts = Scripts.fromYaml(
          createYamlMap({
            'a': {
              'run': 'b',
              'exec': {
                'concurrency': 1,
                'failFast': true,
              },
            },
          }),
          workspacePath: testWorkspacePath,
        );
        expect(scripts['a']!.run, 'b');
        expect(scripts['a']!.exec, ExecOptions(concurrency: 1, failFast: true));
      });

      test('throws when specifying command in "run" and "exec"', () {
        expect(
          () => Scripts.fromYaml(
            createYamlMap({
              'a': {
                'exec': 'b',
                'run': 'c',
              },
            }),
            workspacePath: testWorkspacePath,
          ),
          throwsA(isA<MelosConfigException>()),
        );
      });
    });
  });

  group('MelosWorkspaceConfig', () {
    test(
      'throws if commands.version.linkToCommits == true but repository is '
      'missing',
      () {
        expect(
          () => MelosWorkspaceConfig(
            name: '',
            packages: const [],
            commands: const CommandConfigs(
              version: VersionCommandConfigs(linkToCommits: true),
            ),
            path: testWorkspacePath,
          ),
          throwsMelosConfigException(),
        );
      },
    );

    test('accepts commands.version.linkToCommits == true if repository exists',
        () {
      expect(
        () => MelosWorkspaceConfig(
          name: '',
          repository: const GitHubRepository(owner: 'invertase', name: 'melos'),
          packages: const [],
          commands: const CommandConfigs(
            version: VersionCommandConfigs(linkToCommits: true),
          ),
          path: testWorkspacePath,
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
            path: testWorkspacePath,
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if name is not a String', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap({'name': <Object?>[]}, defaults: configMapDefaults),
            path: testWorkspacePath,
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if name is not a valid dart package name', () {
        void testName(String name) {
          expect(
            () => MelosWorkspaceConfig.fromYaml(
              createYamlMap({'name': name}, defaults: configMapDefaults),
              path: testWorkspacePath,
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
          path: testWorkspacePath,
        );
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'hello2'}, defaults: configMapDefaults),
          path: testWorkspacePath,
        );
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'HELLO'}, defaults: configMapDefaults),
          path: testWorkspacePath,
        );
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'hello-world'}, defaults: configMapDefaults),
          path: testWorkspacePath,
        );
      });

      test('throws if packages is missing', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap({'name': 'package_name'}),
            path: testWorkspacePath,
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
            path: testWorkspacePath,
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
            path: testWorkspacePath,
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
            path: testWorkspacePath,
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
            path: testWorkspacePath,
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
            path: testWorkspacePath,
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
            path: testWorkspacePath,
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
            path: testWorkspacePath,
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
          path: testWorkspacePath,
        );
        final repository = config.repository! as GitHubRepository;

        expect(repository.owner, 'invertase');
        expect(repository.name, 'melos');
      });
    });
  });
}

final testWorkspacePath =
    currentPlatform.isWindows ? r'\\workspace' : '/workspace';

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
