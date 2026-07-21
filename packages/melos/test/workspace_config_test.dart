import 'package:melos/melos.dart';
import 'package:melos/src/command_configs/command_configs.dart';
import 'package:melos/src/command_configs/publish.dart';
import 'package:melos/src/common/git_repository.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/common/retry_backoff.dart';
import 'package:melos/src/workspace_config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'matchers.dart';
import 'utils.dart';

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
      expect(value.lockstep, false);
      expect(value.includeDateInChangelogEntry, false);
      expect(value.groupChangelogEntriesByType, false);
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

      test('throws if lockstep is not a bool', () {
        expect(
          () => VersionCommandConfigs.fromYaml(
            const {'lockstep': 42},
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
              'lockstep': true,
              'workspaceChangelog': true,
              'changelogs': [
                {
                  'path': 'FOO_CHANGELOG.md',
                  'packageFilters': {'flutter': true},
                  'description': 'Changelog for all foo packages.',
                },
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
            lockstep: true,
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

      test('throws if changelogFormat/groupByType is not a bool', () {
        expect(
          () => VersionCommandConfigs.fromYaml(
            const {
              'changelogFormat': {'groupByType': 42},
            },
            workspacePath: '.',
          ),
          throwsMelosConfigException(),
        );
      });

      test('can decode changelogFormat values', () {
        expect(
          VersionCommandConfigs.fromYaml(
            const {
              'changelogFormat': {
                'includeDate': true,
                'groupByType': true,
              },
            },
            workspacePath: '.',
          ),
          const VersionCommandConfigs(
            includeDateInChangelogEntry: true,
            groupChangelogEntriesByType: true,
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
                },
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

      test('can decode publish pubServer', () {
        expect(
          CommandConfigs.fromYaml(
            const {
              'publish': {
                'pubServer': 'https://pub.flutter-io.cn',
              },
            },
            workspacePath: '.',
          ),
          const CommandConfigs(
            publish: PublishCommandConfigs(
              pubServer: 'https://pub.flutter-io.cn',
            ),
          ),
        );
      });
    });
  });

  group('PublishCommandConfigs', () {
    group('fromYaml', () {
      test('accepts empty object', () {
        expect(
          PublishCommandConfigs.fromYaml(const {}, workspacePath: '.'),
          PublishCommandConfigs.empty,
        );
      });

      test('can decode pubServer', () {
        expect(
          PublishCommandConfigs.fromYaml(
            const {'pubServer': 'https://pub.flutter-io.cn'},
            workspacePath: '.',
          ),
          const PublishCommandConfigs(
            pubServer: 'https://pub.flutter-io.cn',
          ),
        );
      });

      test('throws if pubServer is not a string', () {
        expect(
          () => PublishCommandConfigs.fromYaml(
            const {'pubServer': 42},
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

    test('executeInTerminal is true by default', () {
      expect(
        IDEConfigs.empty.intelliJ.executeInTerminal,
        true,
      );
    });

    group('fromYaml', () {
      test('supports empty map', () {
        expect(
          IDEConfigs.fromYaml(const {}),
          isA<IDEConfigs>()
              .having((e) => e.intelliJ.enabled, 'intelliJ.enabled', true)
              .having(
                (e) => e.intelliJ.executeInTerminal,
                'intelliJ.executeInTerminal',
                true,
              ),
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
          isA<IDEConfigs>().having(
            (e) => e.intelliJ.enabled,
            'intelliJ.enabled',
            true,
          ),
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

    test('has "Melos Run -> " scriptNamePrefix by default', () {
      expect(
        IntelliJConfig.empty.scriptNamePrefix,
        'Melos Run -> ',
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

      test('supports "scriptNamePrefix" override', () {
        expect(
          IntelliJConfig.fromYaml(const {'scriptNamePrefix': 'prefix1'}),
          const IntelliJConfig(scriptNamePrefix: 'prefix1'),
        );
      });

      test('supports empty "scriptNamePrefix"', () {
        expect(
          IntelliJConfig.fromYaml(const {'scriptNamePrefix': ''}),
          const IntelliJConfig(scriptNamePrefix: ''),
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
      test('supports specifying command as a string through "exec"', () {
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

      test('supports specifying command through "exec.command"', () {
        final scripts = Scripts.fromYaml(
          createYamlMap({
            'a': {
              'exec': {
                'command': 'b',
              },
            },
          }),
          workspacePath: testWorkspacePath,
        );
        expect(scripts['a']!.run, 'b');
        expect(scripts['a']!.exec, const ExecOptions());
      });

      test('supports specifying exec options alongside "exec.command"', () {
        final scripts = Scripts.fromYaml(
          createYamlMap({
            'a': {
              'exec': {
                'command': 'b',
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

      test('throws when specifying a string command in "run" and "exec"', () {
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

      test('throws with migration hint for the old "run" + "exec" format', () {
        expect(
          () => Scripts.fromYaml(
            createYamlMap({
              'a': {
                'run': 'b',
                'exec': {
                  'concurrency': 1,
                },
              },
            }),
            workspacePath: testWorkspacePath,
          ),
          throwsA(
            isA<MelosConfigException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('mutually exclusive'),
                contains('command: b'),
                contains('concurrency: 1'),
              ),
            ),
          ),
        );
      });

      test('throws when "exec" is an object without a command', () {
        expect(
          () => Scripts.fromYaml(
            createYamlMap({
              'a': {
                'exec': {
                  'concurrency': 1,
                },
              },
            }),
            workspacePath: testWorkspacePath,
          ),
          throwsA(
            isA<MelosConfigException>().having(
              (e) => e.message,
              'message',
              contains('without a command'),
            ),
          ),
        );
      });

      test('throws when using "melos exec" in "exec.command"', () {
        expect(
          () => Scripts.fromYaml(
            createYamlMap({
              'a': {
                'exec': {
                  'command': 'melos exec a',
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

    group('steps', () {
      test('parses a list of string steps', () {
        final scripts = Scripts.fromYaml(
          loadYaml('''
a:
  steps:
    - echo hello
    - echo world
''')
              as Map<Object?, Object?>,
          workspacePath: testWorkspacePath,
        );
        expect(scripts['a']!.steps, ['echo hello', 'echo world']);
      });

      test('parses quoted steps containing a colon', () {
        final scripts = Scripts.fromYaml(
          loadYaml('''
a:
  steps:
    - "echo Checking python version:"
    - "echo Building: app"
''')
              as Map<Object?, Object?>,
          workspacePath: testWorkspacePath,
        );
        expect(
          scripts['a']!.steps,
          ['echo Checking python version:', 'echo Building: app'],
        );
      });

      test('throws a helpful error for unquoted steps containing a colon', () {
        expect(
          () => Scripts.fromYaml(
            loadYaml('''
a:
  steps:
    - echo Building: app
''')
                as Map<Object?, Object?>,
            workspacePath: testWorkspacePath,
          ),
          throwsA(
            isA<MelosConfigException>().having(
              (e) => e.message,
              'message',
              allOf(contains('Wrap the step in quotes'), contains('":"')),
            ),
          ),
        );
      });
    });

    group('stdio', () {
      test('defaults to ProcessStdio.pipe when the key is omitted', () {
        final scripts = Scripts.fromYaml(
          createYamlMap({
            'a': {
              'run': 'b',
            },
          }),
          workspacePath: testWorkspacePath,
        );
        expect(scripts['a']!.stdio, ProcessStdio.pipe);
      });

      test('parses "stdio: inherit"', () {
        final scripts = Scripts.fromYaml(
          createYamlMap({
            'a': {
              'run': 'b',
              'stdio': 'inherit',
            },
          }),
          workspacePath: testWorkspacePath,
        );
        expect(scripts['a']!.stdio, ProcessStdio.inherit);
      });

      test('throws when "stdio" is set to an unknown value', () {
        expect(
          () => Scripts.fromYaml(
            createYamlMap({
              'a': {
                'run': 'b',
                'stdio': 'bogus',
              },
            }),
            workspacePath: testWorkspacePath,
          ),
          throwsA(isA<MelosConfigException>()),
        );
      });

      test('throws when "stdio: inherit" is combined with "exec"', () {
        expect(
          () => Scripts.fromYaml(
            createYamlMap({
              'a': {
                'stdio': 'inherit',
                'exec': {
                  'command': 'b',
                },
              },
            }),
            workspacePath: testWorkspacePath,
          ).validate(),
          throwsA(isA<MelosConfigException>()),
        );
      });

      test('throws when "stdio: inherit" is combined with "steps"', () {
        expect(
          () => Scripts.fromYaml(
            createYamlMap({
              'a': {
                'stdio': 'inherit',
                'steps': ['echo hi'],
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
            name: 'melos_test',
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

    test(
      'accepts commands.version.linkToCommits == true if repository exists',
      () async {
        final workspace = await createTemporaryWorkspace(workspacePackages: []);
        expect(
          () => MelosWorkspaceConfig(
            name: 'melos_test',
            repository: GitHubRepository(owner: 'invertase', name: 'melos'),
            packages: const [],
            commands: const CommandConfigs(
              version: VersionCommandConfigs(linkToCommits: true),
            ),
            path: workspace.path,
          ),
          returnsNormally,
        );
      },
    );

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

      test('accepts valid dart package name', () async {
        final workspace = await createTemporaryWorkspace(workspacePackages: []);
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'hello_world'}, defaults: configMapDefaults),
          path: workspace.path,
        );
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'hello2'}, defaults: configMapDefaults),
          path: workspace.path,
        );
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'HELLO'}, defaults: configMapDefaults),
          path: workspace.path,
        );
        MelosWorkspaceConfig.fromYaml(
          createYamlMap({'name': 'hello-world'}, defaults: configMapDefaults),
          path: workspace.path,
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

      test(
        'throws if repository is not from a supported git repository host',
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
        },
      );

      test('accepts a GitHub repository', () async {
        final workspace = await createTemporaryWorkspace(workspacePackages: []);
        final config = MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {'repository': 'https://github.com/invertase/melos'},
            defaults: configMapDefaults,
          ),
          path: workspace.path,
        );
        final repository = config.repository! as GitHubRepository;

        expect(repository.owner, 'invertase');
        expect(repository.name, 'melos');
      });

      test('useRootAsPackage defaults to false', () async {
        final workspace = await createTemporaryWorkspace(workspacePackages: []);
        final config = MelosWorkspaceConfig.fromYaml(
          createYamlMap({}, defaults: configMapDefaults),
          path: workspace.path,
        );

        expect(config.useRootAsPackage, false);
      });

      test('useRootAsPackage can be set to true', () async {
        final workspace = await createTemporaryWorkspace(workspacePackages: []);
        final config = MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {
              'melos': {'useRootAsPackage': true},
            },
            defaults: configMapDefaults,
          ),
          path: workspace.path,
        );

        expect(config.useRootAsPackage, true);
      });

      test('useRootAsPackage can be set to false explicitly', () async {
        final workspace = await createTemporaryWorkspace(workspacePackages: []);
        final config = MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {
              'melos': {'useRootAsPackage': false},
            },
            defaults: configMapDefaults,
          ),
          path: workspace.path,
        );

        expect(config.useRootAsPackage, false);
      });

      test('throws if useRootAsPackage is not a boolean', () {
        expect(
          () => MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {
                'melos': {'useRootAsPackage': 'not_a_bool'},
              },
              defaults: configMapDefaults,
            ),
            path: testWorkspacePath,
          ),
          throwsMelosConfigException(),
        );
      });

      group('pub config', () {
        test('defaults to retry/backoff defaults with no timeout', () async {
          final workspace = await createTemporaryWorkspace(
            workspacePackages: [],
          );
          final config = MelosWorkspaceConfig.fromYaml(
            createYamlMap({}, defaults: configMapDefaults),
            path: workspace.path,
          );

          expect(config.pub.requestTimeout, isNull);
          expect(
            config.pub.retryBackoff,
            const RetryBackoff(),
          );
        });

        test('decodes timeout and retry options', () async {
          final workspace = await createTemporaryWorkspace(
            workspacePackages: [],
          );
          final config = MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {
                'melos': {
                  'pub': {
                    'timeoutSeconds': 5,
                    'retry': {
                      'delayFactorMillis': 100,
                      'randomizationFactor': 0.1,
                      'maxDelaySeconds': 10,
                      'maxAttempts': 4,
                    },
                  },
                },
              },
              defaults: configMapDefaults,
            ),
            path: workspace.path,
          );

          expect(config.pub.requestTimeout, const Duration(seconds: 5));
          expect(
            config.pub.retryBackoff,
            const RetryBackoff(
              delayFactor: Duration(milliseconds: 100),
              randomizationFactor: 0.1,
              maxDelay: Duration(seconds: 10),
              maxAttempts: 4,
            ),
          );
        });

        test('uses retry defaults when only timeout is provided', () async {
          final workspace = await createTemporaryWorkspace(
            workspacePackages: [],
          );
          final config = MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {
                'melos': {
                  'pub': {
                    'timeoutSeconds': 2,
                  },
                },
              },
              defaults: configMapDefaults,
            ),
            path: workspace.path,
          );

          expect(config.pub.requestTimeout, const Duration(seconds: 2));
          expect(config.pub.retryBackoff, const RetryBackoff());
        });

        test('treats timeoutSeconds 0 as no timeout', () async {
          final workspace = await createTemporaryWorkspace(
            workspacePackages: [],
          );
          final config = MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {
                'melos': {
                  'pub': {
                    'timeoutSeconds': 0,
                  },
                },
              },
              defaults: configMapDefaults,
            ),
            path: workspace.path,
          );

          expect(config.pub.requestTimeout, isNull);
        });

        test('treats missing timeoutSeconds  no timeout', () async {
          final workspace = await createTemporaryWorkspace(
            workspacePackages: [],
          );
          final config = MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {
                'melos': {
                  'pub': <String, String>{},
                },
              },
              defaults: configMapDefaults,
            ),
            path: workspace.path,
          );

          expect(config.pub.requestTimeout, isNull);
        });

        test('throws if pub is not a map', () {
          expect(
            () => MelosWorkspaceConfig.fromYaml(
              createYamlMap(
                {
                  'melos': {'pub': 'invalid'},
                },
                defaults: configMapDefaults,
              ),
              path: testWorkspacePath,
            ),
            throwsMelosConfigException(),
          );
        });
      });
    });
  });
}

final testWorkspacePath = currentPlatform.isWindows
    ? r'\\workspace'
    : '/workspace';

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
  'workspace': <String>[],
};
