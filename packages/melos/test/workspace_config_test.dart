import 'package:melos/melos.dart';
import 'package:melos/src/command_configs/command_configs.dart';
import 'package:melos/src/common/git_repository.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/workspace_configs.dart';
import 'package:test/test.dart';

import 'matchers.dart';

void main() {
  group('BootstrapCommandConfigs', () {
    test('runPubGetInParallel is optional', () {
      // ignore: use_named_constants
      const value = BootstrapCommandConfigs();

      expect(value.runPubGetInParallel, true);
    });

    group('fromYaml', () {
      test('accepts empty object', () {
        expect(
          BootstrapCommandConfigs.fromYaml(const {}, workspacePath: '.'),
          BootstrapCommandConfigs.empty,
        );
      });

      test('throws if runPubGetInParallel is not a bool', () {
        expect(
          () => BootstrapCommandConfigs.fromYaml(
            const {
              'runPubGetInParallel': 42,
            },
            workspacePath: '.',
          ),
          throwsMelosConfigException(),
        );
      });

      test('can decode values', () {
        expect(
          BootstrapCommandConfigs.fromYaml(
            const {
              'runPubGetInParallel': false,
              'runPubGetOffline': true,
              'enforceLockfile': true,
              'dependencyOverridePaths': ['a'],
            },
            workspacePath: '.',
          ),
          BootstrapCommandConfigs(
            runPubGetInParallel: false,
            runPubGetOffline: true,
            enforceLockfile: true,
            dependencyOverridePaths: [
              createGlob('a', currentDirectoryPath: '.'),
            ],
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
      expect(value.includeScopes, true);
      expect(value.includeCommitId, false);
      expect(value.linkToCommits, false);
      expect(value.updateGitTagRefs, false);
      expect(value.aggregateChangelogs, [
        AggregateChangelogConfig.workspace(),
      ]);
    });

    group('fromYaml', () {
      test('accepts empty object', () {
        expect(
          VersionCommandConfigs.fromYaml(const {}, workspacePath: '.'),
          VersionCommandConfigs.empty,
        );
      });

      test('throws if branch is not a string', () {
        expect(
          () => VersionCommandConfigs.fromYaml(
            const {'branch': 42},
            workspacePath: '.',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if message is not a string', () {
        expect(
          () => VersionCommandConfigs.fromYaml(
            const {'message': 42},
            workspacePath: '.',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if includeScopes is not a bool', () {
        expect(
          () => VersionCommandConfigs.fromYaml(
            const {'includeScopes': 42},
            workspacePath: '.',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if linkToCommits is not a bool', () {
        expect(
          () => VersionCommandConfigs.fromYaml(
            const {'linkToCommits': 42},
            workspacePath: '.',
          ),
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
              'changelogs': [
                {
                  'path': 'FOO_CHANGELOG.md',
                  'packageFilters': {'flutter': true},
                  'description': 'Changelog for all foo packages.',
                }
              ],
            },
            workspacePath: '.',
          ),
          VersionCommandConfigs(
            branch: 'branch',
            message: 'message',
            includeCommitId: true,
            linkToCommits: true,
            updateGitTagRefs: true,
            aggregateChangelogs: [
              AggregateChangelogConfig.workspace(),
              AggregateChangelogConfig(
                path: 'FOO_CHANGELOG.md',
                packageFilters: PackageFilters(flutter: true),
                description: 'Changelog for all foo packages.',
              ),
            ],
          ),
        );
      });

      test('can decode packageFilters values', () {
        expect(
          VersionCommandConfigs.fromYaml(
            const {
              'changelogs': [
                {
                  'path': 'FOO_CHANGELOG.md',
                  'packageFilters': {
                    'flutter': true,
                    'includeDependencies': true,
                    'includeDependents': true,
                  },
                }
              ],
            },
            workspacePath: '.',
          ),
          VersionCommandConfigs(
            aggregateChangelogs: [
              AggregateChangelogConfig.workspace(),
              AggregateChangelogConfig(
                path: 'FOO_CHANGELOG.md',
                packageFilters: PackageFilters(
                  flutter: true,
                  includeDependencies: true,
                  includeDependents: true,
                ),
              ),
            ],
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
          CommandConfigs.fromYaml(
            const {},
            workspacePath: '.',
          ),
          CommandConfigs.empty,
        );
      });

      test('can decode `bootstrap`', () {
        expect(
          CommandConfigs.fromYaml(
            const {
              'bootstrap': {
                'runPubGetInParallel': true,
              },
            },
            workspacePath: '.',
          ),
          // ignore: use_named_constants
          const CommandConfigs(
            // ignore: avoid_redundant_argument_values, use_named_constants
            bootstrap: BootstrapCommandConfigs(
              // ignore: avoid_redundant_argument_values
              runPubGetInParallel: true,
            ),
          ),
        );
      });

      test('can decode `bootstrap` with pub get offline', () {
        expect(
          CommandConfigs.fromYaml(
            const {
              'bootstrap': {
                'runPubGetOffline': true,
              },
            },
            workspacePath: '.',
          ),
          const CommandConfigs(
            bootstrap: BootstrapCommandConfigs(
              runPubGetOffline: true,
            ),
          ),
        );
      });

      test('can decode `bootstrap` with pub get --enforce-lockfile', () {
        expect(
          CommandConfigs.fromYaml(
            const {
              'bootstrap': {
                'enforceLockfile': true,
              },
            },
            workspacePath: '.',
          ),
          const CommandConfigs(
            bootstrap: BootstrapCommandConfigs(
              enforceLockfile: true,
            ),
          ),
        );
      });
      test('can decode `version`', () {
        expect(
          CommandConfigs.fromYaml(
            const {
              'version': {
                'message': 'Hello world',
                'branch': 'main',
                'linkToCommits': true,
              },
            },
            workspacePath: '.',
          ),
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
          () => CommandConfigs.fromYaml(
            const {'bootstrap': 42},
            workspacePath: '.',
          ),
          throwsMelosConfigException(),
        );
      });

      test('throws if `version` is not a map', () {
        expect(
          () => CommandConfigs.fromYaml(
            const {'version': 42},
            workspacePath: '.',
          ),
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
          IntelliJConfig.fromYaml(const <Object?, Object?>{}),
          IntelliJConfig.empty,
        );
      });

      test('supports "enabled"', () {
        expect(
          IntelliJConfig.fromYaml(const {'enabled': false}),
          const IntelliJConfig(enabled: false),
        );
        expect(
          IntelliJConfig.fromYaml(const {'enabled': true}),
          IntelliJConfig.empty,
        );
      });

      test('supports "moduleNamePrefix" override', () {
        expect(
          IntelliJConfig.fromYaml(const {'moduleNamePrefix': 'prefix1'}),
          const IntelliJConfig(moduleNamePrefix: 'prefix1'),
        );
      });

      test('yields "moduleNamePrefix" of "melos_" by default', () {
        expect(
          IntelliJConfig.fromYaml(const <Object?, Object?>{}).moduleNamePrefix,
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
        expect(scripts['a']!.exec, const ExecOptions());
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
        expect(scripts['a']!.exec, const ExecOptions());
      });

      test('supports specifying exec options', () {
        final scripts = Scripts.fromYaml(
          createYamlMap({
            'a': {
              'run': 'b',
              'exec': {
                'concurrency': 1,
                'failFast': true,
                'orderDependents': true,
              },
            },
          }),
          workspacePath: testWorkspacePath,
        );
        expect(scripts['a']!.run, 'b');
        expect(
          scripts['a']!.exec,
          const ExecOptions(
            concurrency: 1,
            failFast: true,
            orderDependents: true,
          ),
        );
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

      test('throws when using "melos exec" in "run" and specifying "exec"', () {
        expect(
          () => Scripts.fromYaml(
            createYamlMap({
              'a': {
                'run': 'melos exec a',
                'exec': {
                  'concurrency': 1,
                },
              },
            }),
            workspacePath: testWorkspacePath,
          ).validate(),
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
          repository: GitHubRepository(owner: 'invertase', name: 'melos'),
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
              'packages': <Object?>['*'],
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
                'packages': [42],
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
                'ignore': [42],
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
