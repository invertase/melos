import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/command_configs/command_configs.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../matchers.dart';
import '../utils.dart';
import '../workspace_config_test.dart';

void main() {
  group('bootstrap', () {
    test('supports path dependencies in the pubspec for dependencies that '
        'are not part of the workspace', () async {
      final absoluteDir = createTestTempDir();
      final relativeDir = createTestTempDir();
      final relativeOverrideDir = createTestTempDir();
      final relativeDevDir = createTestTempDir();

      final absoluteProject = await createProject(
        absoluteDir,
        Pubspec('absolute'),
        path: '',
      );
      final relativeProject = await createProject(
        relativeDir,
        Pubspec('relative'),
        path: '',
      );
      final relativeDevProject = await createProject(
        relativeDevDir,
        Pubspec('relative_dev'),
        path: '',
      );
      final relativeOverrideProject = await createProject(
        relativeOverrideDir,
        Pubspec('relative_override'),
        path: '',
      );

      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a'],
      );

      final aPath = p.join(workspaceDir.path, 'packages', 'a');

      await createProject(
        workspaceDir,
        Pubspec(
          'a',
          dependencies: {
            'relative': PathDependency(
              relativePath(relativeProject.path, aPath),
            ),
            'absolute': PathDependency(absoluteProject.path),
          },
          dependencyOverrides: {
            'relative_override': PathDependency(
              relativePath(relativeOverrideProject.path, aPath),
            ),
          },
          devDependencies: {
            'relative_dev': PathDependency(
              relativePath(relativeDevProject.path, aPath),
            ),
          },
        ),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: logger.toMelosLogger(),
      );
      final melos = Melos(logger: logger, config: config);
      final pubExecArgs = pubCommandExecArgs(
        useFlutter: workspace.isFlutterWorkspace,
        workspace: workspace,
      );

      await runMelosBootstrap(melos, logger);

      expect(
        logger.output,
        ignoringAnsii(
          '''
melos bootstrap
  └> ${workspaceDir.path}

Running "${pubExecArgs.join(' ')} get" in workspace...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 1 packages bootstrapped
''',
        ),
      );

      final workspaceConfigPath = packageConfigPath(workspaceDir.path);
      String resolvePathRelativeToPackageConfig(String path) =>
          p.canonicalize(p.join(p.dirname(workspaceConfigPath), path));

      final aConfig = packageConfigForPackageAt(workspaceDir);
      final actualAbsolutePath = p.prettyUri(
        aConfig.packages.firstWhere((p) => p.name == 'absolute').rootUri,
      );
      expect(
        resolvePathRelativeToPackageConfig(actualAbsolutePath),
        p.canonicalize(absoluteProject.path),
      );

      final actualRelativePath = p.prettyUri(
        aConfig.packages.firstWhere((p) => p.name == 'relative').rootUri,
      );
      expect(
        resolvePathRelativeToPackageConfig(actualRelativePath),
        p.canonicalize(relativeProject.path),
      );

      final actualRelativeDevPath = p.prettyUri(
        aConfig.packages.firstWhere((p) => p.name == 'relative_dev').rootUri,
      );
      expect(
        resolvePathRelativeToPackageConfig(actualRelativeDevPath),
        p.canonicalize(relativeDevProject.path),
      );

      final actualRelativeOverridePath = p.prettyUri(
        aConfig.packages
            .firstWhere((p) => p.name == 'relative_override')
            .rootUri,
      );
      expect(
        resolvePathRelativeToPackageConfig(actualRelativeOverridePath),
        p.canonicalize(relativeOverrideProject.path),
      );
    });

    test(
      'properly compares the path changes on git references',
      () async {
        final temporaryGitRepositoryPath = createTestTempDir().absolute.path;

        await Process.run(
          'git',
          ['init'],
          workingDirectory: temporaryGitRepositoryPath,
        );

        await createProject(
          Directory('$temporaryGitRepositoryPath/dependency1'),
          Pubspec('dependency'),
        );

        await createProject(
          Directory('$temporaryGitRepositoryPath/dependency2'),
          Pubspec('dependency'),
        );

        await Process.run(
          'git',
          ['add', '-A'],
          workingDirectory: temporaryGitRepositoryPath,
        );

        await Process.run(
          'git',
          ['commit', '--message="Initial commit"'],
          workingDirectory: temporaryGitRepositoryPath,
        );

        final workspaceDirectory = await createTemporaryWorkspace(
          workspacePackages: [
            'git_references',
          ],
        );

        final initialReference = {
          'git': {
            'url': 'file://$temporaryGitRepositoryPath',
            'path': 'dependency1/packages/dependency',
          },
        };

        await createProject(
          workspaceDirectory,
          Pubspec(
            'git_references',
            dependencies: {
              'dependency': GitDependency(
                Uri.parse(initialReference['git']!['url']!),
                path: initialReference['git']!['path'],
              ),
            },
          ),
        );

        final logger = TestLogger();
        final initialConfig = MelosWorkspaceConfig.fromYaml(
          {
            'name': 'test',
            'workspace': const ['packages/git_references'],
            'melos': {
              'command': {
                'bootstrap': {
                  'dependencies': {
                    'dependency': initialReference,
                  },
                },
              },
            },
          },
          path: workspaceDirectory.path,
        );

        final melosBeforeChangingPath = Melos(
          logger: logger,
          config: initialConfig,
        );

        await runMelosBootstrap(melosBeforeChangingPath, logger);

        final packageConfig = packageConfigForPackageAt(workspaceDirectory);
        final dependencyPackage = packageConfig.packages.singleWhere(
          (package) => package.name == 'dependency',
        );

        expect(
          dependencyPackage.rootUri,
          contains('dependency1/packages/dependency'),
        );

        final configWithChangedPath = MelosWorkspaceConfig.fromYaml(
          {
            'name': 'test',
            'workspace': const ['packages/git_references'],
            'melos': {
              'command': {
                'bootstrap': {
                  'dependencies': {
                    'dependency': {
                      'git': {
                        'url': 'file://$temporaryGitRepositoryPath',
                        'path': 'dependency2/packages/dependency',
                      },
                    },
                  },
                },
              },
            },
          },
          path: workspaceDirectory.path,
        );

        final melosAfterChangingPath = Melos(
          logger: logger,
          config: configWithChangedPath,
        );

        await runMelosBootstrap(melosAfterChangingPath, logger);

        final alteredPackageConfig = packageConfigForPackageAt(
          workspaceDirectory,
        );
        final alteredDependencyPackage = alteredPackageConfig.packages
            .singleWhere((package) => package.name == 'dependency');

        expect(
          alteredDependencyPackage.rootUri,
          contains('dependency2/packages/dependency'),
        );
      },
      // This test works locally, but we can't create git repositories in CI.
      skip: Platform.environment.containsKey('CI'),
    );

    test(
      'resolves workspace packages with path dependency',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c', 'd'],
        );

        await createProject(
          workspaceDir,
          Pubspec(
            'a',
            dependencies: {
              'b': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );
        await createProject(
          workspaceDir,
          Pubspec('b'),
        );

        await createProject(
          workspaceDir,
          pubspecFromJsonFile(fileName: 'add_to_app_json.json'),
        );

        await createProject(
          workspaceDir,
          pubspecFromJsonFile(fileName: 'plugin_json.json'),
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await runMelosBootstrap(melos, logger);

        expect(
          logger.output,
          ignoringAnsii(
            allOf(
              [
                '''
melos bootstrap
  └> ${workspaceDir.path}

Running "flutter pub get" in workspace...''',
                '''
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 4 packages bootstrapped
''',
              ].map(contains).toList(),
            ),
          ),
        );

        final aConfig = packageConfigForPackageAt(workspaceDir);

        expect(
          aConfig.packages.firstWhere((p) => p.name == 'b').rootUri,
          '../packages/b',
        );
      },
      timeout: Platform.isLinux ? const Timeout(Duration(seconds: 45)) : null,
    );

    test('respects user dependency_overrides', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a'],
      );

      await createProject(
        workspaceDir,
        Pubspec(
          'a',
          dependencies: {
            'path': HostedDependency(version: VersionConstraint.any),
          },
          dependencyOverrides: {
            'path': HostedDependency(version: VersionConstraint.any),
          },
        ),
      );

      await createProject(
        workspaceDir,
        Pubspec('path'),
        inWorkspace: false,
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await runMelosBootstrap(melos, logger);

      final packageConfig = packageConfigForPackageAt(workspaceDir);
      expect(
        packageConfig.packages
            .firstWhere((package) => package.name == 'path')
            .rootUri,
        contains('hosted/pub.dev/path'),
      );
    });

    test('bootstrap flutter example packages', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a'],
        withExamples: true,
      );

      await createProject(
        workspaceDir,
        Pubspec(
          'a',
          dependencies: {
            'flutter': SdkDependency('flutter'),
          },
        ),
        path: 'packages/a',
      );

      await createProject(
        workspaceDir,
        Pubspec(
          'example',
          dependencies: {
            'a': HostedDependency(version: VersionConstraint.any),
          },
        ),
        path: 'packages/a/example',
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await runMelosBootstrap(melos, logger);

      final workspacePkgConfig = packageConfigForPackageAt(workspaceDir);
      final aPkgDependencyConfig = workspacePkgConfig.packages.firstWhere(
        (package) => package.name == 'a',
      );
      expect(aPkgDependencyConfig.rootUri, '../packages/a');
    });

    test('handles errors in pub get', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a'],
      );

      await createProject(
        workspaceDir,
        Pubspec(
          'a',
          dependencies: {
            'package_that_does_not_exists': HostedDependency(
              version: VersionConstraint.parse('^1.2.3-no-way-this-exists'),
            ),
          },
        ),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: logger.toMelosLogger(),
      );
      final melos = Melos(
        logger: logger,
        config: config,
      );
      final pubExecArgs = pubCommandExecArgs(
        useFlutter: workspace.isFlutterWorkspace,
        workspace: workspace,
      );

      await expectLater(
        melos.bootstrap(),
        throwsA(
          isA<BootstrapException>().having(
            (e) => e.package.name,
            'package.name',
            'workspace',
          ),
        ),
      );

      expect(
        logger.output,
        ignoringAnsii(
          '''
melos bootstrap
  └> ${workspaceDir.path}

Running "${pubExecArgs.join(' ')} get" in workspace...
  - workspace
    └> .
e-       └> Failed to run pub get.

Resolving dependencies...
e-Because a depends on package_that_does_not_exists any which doesn't exist (could not find package package_that_does_not_exists at https://pub.dev), version solving failed.
''',
        ),
      );
    });

    test('can run pub get offline', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: [],
        configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {
              'melos': {
                'command': {
                  'bootstrap': {
                    'runPubGetOffline': true,
                  },
                },
              },
            },
            defaults: configMapDefaults,
          ),
          path: path,
        ),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: logger.toMelosLogger(),
      );
      final melos = Melos(logger: logger, config: config);
      final pubExecArgs = pubCommandExecArgs(
        useFlutter: workspace.isFlutterWorkspace,
        workspace: workspace,
      );

      await runMelosBootstrap(melos, logger);

      expect(
        logger.output,
        ignoringAnsii(
          '''
melos bootstrap
  └> ${workspaceDir.path}

Running "${pubExecArgs.join(' ')} get --offline" in workspace...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 0 packages bootstrapped
''',
        ),
      );
    });

    test('can run pub get --enforce-lockfile', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: [],
        configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {
              'melos': {
                'command': {
                  'bootstrap': {
                    'enforceLockfile': true,
                  },
                },
              },
            },
            defaults: configMapDefaults,
          ),
          path: path,
        ),
        createLockfile: true,
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: logger.toMelosLogger(),
      );
      final melos = Melos(logger: logger, config: config);
      final pubExecArgs = pubCommandExecArgs(
        useFlutter: workspace.isFlutterWorkspace,
        workspace: workspace,
      );

      await melos.runPubGetForPackage(
        workspace,
        workspace.rootPackage,
        noExample: true,
        runOffline: false,
        enforceLockfile: false,
      );

      await runMelosBootstrap(melos, logger);

      expect(
        logger.output,
        ignoringAnsii(
          '''
melos bootstrap
  └> ${workspaceDir.path}

Running "${pubExecArgs.join(' ')} get --enforce-lockfile" in workspace...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 0 packages bootstrapped
''',
        ),
      );
    });

    test(
      'can run pub get --no-enforce-lockfile when enforced in config',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: [],
          configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
            createYamlMap(
              {
                'melos': {
                  'command': {
                    'bootstrap': {
                      'enforceLockfile': true,
                    },
                  },
                },
              },
              defaults: configMapDefaults,
            ),
            path: path,
          ),
          createLockfile: true,
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final workspace = await MelosWorkspace.fromConfig(
          config,
          logger: logger.toMelosLogger(),
        );
        final melos = Melos(logger: logger, config: config);
        final pubExecArgs = pubCommandExecArgs(
          useFlutter: workspace.isFlutterWorkspace,
          workspace: workspace,
        );

        await runMelosBootstrap(
          melos,
          logger,
          enforceLockfile: false,
        );

        expect(
          logger.output,
          ignoringAnsii(
            '''
melos bootstrap
  └> ${workspaceDir.path}

Running "${pubExecArgs.join(' ')} get" in workspace...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 0 packages bootstrapped
''',
          ),
        );
      },
    );

    test('can run pub get --enforce-lockfile without lockfile', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: [],
        configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {
              'melos': {
                'command': {
                  'bootstrap': {
                    'enforceLockfile': true,
                  },
                },
              },
            },
            defaults: configMapDefaults,
          ),
          path: path,
        ),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: logger.toMelosLogger(),
      );
      final melos = Melos(logger: logger, config: config);
      final pubExecArgs = pubCommandExecArgs(
        useFlutter: workspace.isFlutterWorkspace,
        workspace: workspace,
      );

      await runMelosBootstrap(melos, logger);

      expect(
        logger.output,
        ignoringAnsii(
          '''
melos bootstrap
  └> ${workspaceDir.path}

Running "${pubExecArgs.join(' ')} get" in workspace...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 0 packages bootstrapped
''',
        ),
      );
    });

    test(
      'applies shared dependencies from melos config',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b'],
          configBuilder: (path) => MelosWorkspaceConfig(
            name: 'Melos',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            commands: CommandConfigs(
              bootstrap: BootstrapCommandConfigs(
                environment: {
                  'sdk': VersionConstraint.parse('>=3.6.0 <4.0.0'),
                  'flutter': VersionConstraint.parse('>=2.18.0 <3.0.0'),
                },
                dependencies: {
                  'intl': HostedDependency(
                    version: VersionConstraint.compatibleWith(
                      Version.parse('0.18.1'),
                    ),
                  ),
                  'integral_isolates': HostedDependency(
                    version: VersionConstraint.compatibleWith(
                      Version.parse('0.4.1'),
                    ),
                  ),
                  'path': HostedDependency(
                    version: VersionConstraint.compatibleWith(
                      Version.parse('1.8.3'),
                    ),
                  ),
                },
                devDependencies: {
                  'flame_lint': HostedDependency(
                    version: VersionConstraint.compatibleWith(
                      Version.parse('1.2.1'),
                    ),
                  ),
                },
              ),
            ),
            path: path,
          ),
        );

        final pkgA = await createProject(
          workspaceDir,
          Pubspec(
            'a',
            environment: {},
            dependencies: {
              'intl': HostedDependency(
                version: VersionConstraint.compatibleWith(
                  Version.parse('0.18.1'),
                ),
              ),
              'path': HostedDependency(
                version: VersionConstraint.compatibleWith(
                  Version.parse('1.7.2'),
                ),
              ),
            },
            devDependencies: {
              'flame_lint': HostedDependency(
                version: VersionConstraint.compatibleWith(
                  Version.parse('1.2.0'),
                ),
              ),
            },
          ),
        );

        final pkgB = await createProject(
          workspaceDir,
          Pubspec(
            'b',
            environment: {
              'sdk': VersionConstraint.parse('>=2.12.0 <3.0.0'),
              'flutter': VersionConstraint.parse('>=2.12.0 <3.0.0'),
            },
            dependencies: {
              'integral_isolates': HostedDependency(
                version: VersionConstraint.compatibleWith(
                  Version.parse('0.4.1'),
                ),
              ),
              'intl': HostedDependency(
                version: VersionConstraint.compatibleWith(
                  Version.parse('0.17.0'),
                ),
              ),
              'path': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        final pubspecAPreBootstrap = pubspecFromYamlFile(directory: pkgA.path);
        final pubspecBPreBootstrap = pubspecFromYamlFile(directory: pkgB.path);

        await runMelosBootstrap(melos, logger);

        final pubspecA = pubspecFromYamlFile(directory: pkgA.path);
        final pubspecB = pubspecFromYamlFile(directory: pkgB.path);

        expect(
          pubspecAPreBootstrap.environment,
          equals(defaultTestEnvironment),
        );
        expect(
          pubspecA.environment['sdk'],
          equals(VersionConstraint.parse('>=3.6.0 <4.0.0')),
        );
        expect(
          pubspecA.dependencies,
          equals({
            'intl': HostedDependency(
              version: VersionConstraint.compatibleWith(
                Version.parse('0.18.1'),
              ),
            ),
            'path': HostedDependency(
              version: VersionConstraint.compatibleWith(Version.parse('1.8.3')),
            ),
          }),
        );
        expect(
          pubspecA.devDependencies,
          equals({
            'flame_lint': HostedDependency(
              version: VersionConstraint.compatibleWith(Version.parse('1.2.1')),
            ),
          }),
        );

        expect(
          pubspecBPreBootstrap.environment['flutter'],
          equals(VersionConstraint.parse('>=2.12.0 <3.0.0')),
        );
        expect(
          pubspecB.environment['flutter'],
          equals(VersionConstraint.parse('>=2.18.0 <3.0.0')),
        );
        expect(
          pubspecB.dependencies,
          equals({
            'integral_isolates': HostedDependency(
              version: VersionConstraint.compatibleWith(Version.parse('0.4.1')),
            ),
            'intl': HostedDependency(
              version: VersionConstraint.compatibleWith(
                Version.parse('0.18.1'),
              ),
            ),
            'path': HostedDependency(
              version: VersionConstraint.compatibleWith(Version.parse('1.8.3')),
            ),
          }),
        );
        expect(
          pubspecB.devDependencies,
          equals({}),
        );
      },
      timeout: const Timeout(Duration(days: 2)),
    );

    test('correctly inlines shared dependencies', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a'],
        configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {
              'melos': {
                'command': {
                  'bootstrap': {
                    'dependencies': {
                      'flame': '^1.21.0',
                    },
                  },
                },
              },
            },
            defaults: configMapDefaults,
          ),
          path: path,
        ),
      );

      final pkgA = await createProject(
        workspaceDir,
        Pubspec(
          'a',
          dependencies: {
            'flame': HostedDependency(version: VersionConstraint.any),
          },
        ),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await runMelosBootstrap(melos, logger);

      final pubspecContent = _pubspecContent(pkgA);
      expect(
        (pubspecContent['dependencies']! as YamlMap)['flame'],
        '^1.21.0',
      );
    });
  });

  test(
    'rollbacks applied shared dependencies on resolution failure',
    () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a', 'b'],
        configBuilder: (path) => MelosWorkspaceConfig(
          name: 'Melos',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          commands: CommandConfigs(
            bootstrap: BootstrapCommandConfigs(
              environment: {
                'sdk': VersionConstraint.parse('>=3.6.0 <4.0.0'),
                'flutter': VersionConstraint.parse('>=2.18.0 <3.0.0'),
              },
              dependencies: {
                'flame': HostedDependency(
                  version: VersionConstraint.compatibleWith(
                    // Should fail since the version is not compatible with
                    // the flutter version.
                    Version.parse('0.1.0'),
                  ),
                ),
              },
              devDependencies: {
                'flame_lint': HostedDependency(
                  version: VersionConstraint.compatibleWith(
                    Version.parse('1.2.1'),
                  ),
                ),
              },
            ),
          ),
          path: path,
        ),
      );

      final pkgA = await createProject(
        workspaceDir,
        Pubspec(
          'a',
          environment: {},
          dependencies: {
            'flame': HostedDependency(
              version: VersionConstraint.compatibleWith(
                Version.parse('1.23.0'),
              ),
            ),
          },
          devDependencies: {
            'flame_lint': HostedDependency(
              version: VersionConstraint.compatibleWith(Version.parse('1.2.0')),
            ),
          },
        ),
      );

      final pkgB = await createProject(
        workspaceDir,
        Pubspec(
          'b',
          environment: {
            'sdk': VersionConstraint.parse('>=2.12.0 <3.0.0'),
            'flutter': VersionConstraint.parse('>=2.12.0 <3.0.0'),
          },
          dependencies: {
            'flame': HostedDependency(
              version: VersionConstraint.compatibleWith(
                Version.parse('1.23.0'),
              ),
            ),
            'integral_isolates': HostedDependency(
              version: VersionConstraint.compatibleWith(Version.parse('0.4.1')),
            ),
            'intl': HostedDependency(
              version: VersionConstraint.compatibleWith(
                Version.parse('0.17.0'),
              ),
            ),
            'path': HostedDependency(version: VersionConstraint.any),
          },
        ),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      final pubspecAPreBootstrap = pubspecFromYamlFile(directory: pkgA.path);
      final pubspecBPreBootstrap = pubspecFromYamlFile(directory: pkgB.path);

      await expectLater(
        () => runMelosBootstrap(melos, logger),
        throwsA(isA<BootstrapException>()),
      );

      final pubspecA = pubspecFromYamlFile(directory: pkgA.path);
      final pubspecB = pubspecFromYamlFile(directory: pkgB.path);

      expect(
        pubspecAPreBootstrap.environment,
        equals(defaultTestEnvironment),
      );
      expect(
        pubspecA.environment['sdk'],
        equals(pubspecAPreBootstrap.environment['sdk']),
      );
      expect(
        pubspecA.dependencies,
        equals(pubspecAPreBootstrap.dependencies),
      );
      expect(
        pubspecA.devDependencies,
        equals(pubspecAPreBootstrap.devDependencies),
      );

      expect(
        pubspecBPreBootstrap.environment['flutter'],
        equals(VersionConstraint.parse('>=2.12.0 <3.0.0')),
      );
      expect(
        pubspecB.dependencies,
        equals(pubspecBPreBootstrap.dependencies),
      );
      expect(
        pubspecB.devDependencies,
        equals(pubspecBPreBootstrap.devDependencies),
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  group('melos bs --offline', () {
    test('should run pub get with --offline', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a'],
      );
      await createProject(
        workspaceDir,
        Pubspec('a'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(logger: logger, config: config);

      await runMelosBootstrap(melos, logger, offline: true);

      expect(
        logger.output,
        ignoringAnsii(
          '''
melos bootstrap
  └> ${workspaceDir.path}

Running "dart pub get --offline" in workspace...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 1 packages bootstrapped
''',
        ),
      );
    });
  });
}

Future<void> runMelosBootstrap(
  Melos melos,
  TestLogger logger, {
  bool? enforceLockfile,
  bool offline = false,
}) async {
  try {
    await melos.bootstrap(
      enforceLockfile: enforceLockfile,
      offline: offline,
    );
  } on BootstrapException {
    // ignore: avoid_print
    print(logger.output);
    rethrow;
  }
}

YamlMap _pubspecContent(Directory directory) {
  final source = readTextFile(pubspecPath(directory.path));
  return loadYaml(source) as YamlMap;
}
