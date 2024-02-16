import 'dart:io' as io;

import 'package:melos/melos.dart';
import 'package:melos/src/commands/runner.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';
import '../workspace_config_test.dart';

void main() {
  group('bootstrap', () {
    test(
        'supports path dependencies in the pubspec for dependencies that '
        'are not part of the workspace', () async {
      final absoluteDir = createTestTempDir();
      final relativeDir = createTestTempDir();
      final relativeOverrideDir = createTestTempDir();
      final relativeDevDir = createTestTempDir();

      final absoluteProject = await createProject(
        absoluteDir,
        const PubSpec(name: 'absolute'),
        path: '',
      );
      final relativeProject = await createProject(
        relativeDir,
        const PubSpec(name: 'relative'),
        path: '',
      );
      final relativeDevProject = await createProject(
        relativeDevDir,
        const PubSpec(name: 'relative_dev'),
        path: '',
      );
      final relativeOverrideProject = await createProject(
        relativeOverrideDir,
        const PubSpec(name: 'relative_override'),
        path: '',
      );

      final workspaceDir = await createTemporaryWorkspace();

      final aPath = p.join(workspaceDir.path, 'packages', 'a');

      final aDir = await createProject(
        workspaceDir,
        PubSpec(
          name: 'a',
          dependencies: {
            'relative': PathReference(
              relativePath(relativeProject.path, aPath),
            ),
            'absolute': PathReference(absoluteProject.path),
          },
          dependencyOverrides: {
            'relative_override': PathReference(
              relativePath(relativeOverrideProject.path, aPath),
            ),
          },
          devDependencies: {
            'relative_dev': PathReference(
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

Running "${pubExecArgs.join(' ')} get" in workspace packages...
  ✓ a
    └> packages/a
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 1 packages bootstrapped
''',
        ),
      );

      final aPackageConfigPath = packageConfigPath(aDir.path);
      String resolvePathRelativeToPackageConfig(String path) =>
          p.canonicalize(p.join(p.dirname(aPackageConfigPath), path));

      final aConfig = packageConfigForPackageAt(aDir);
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

    test('resolves workspace packages with path dependency', () async {
      final workspaceDir = await createTemporaryWorkspace();

      final aDir = await createProject(
        workspaceDir,
        PubSpec(
          name: 'a',
          dependencies: {'b': HostedReference(VersionConstraint.any)},
        ),
      );
      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );

      await createProject(
        workspaceDir,
        pubSpecFromJsonFile(fileName: 'add_to_app_json.json'),
      );

      await createProject(
        workspaceDir,
        pubSpecFromJsonFile(fileName: 'plugin_json.json'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
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

Running "flutter pub get" in workspace packages...''',
              '''
  ✓ a
    └> packages/a
''',
              '''
  ✓ b
    └> packages/b
''',
              '''
  ✓ c
    └> packages/c
''',
              '''
  ✓ d
    └> packages/d
''',
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

      final aConfig = packageConfigForPackageAt(aDir);

      expect(
        aConfig.packages.firstWhere((p) => p.name == 'b').rootUri,
        '../../b',
      );
    });

    test(
      'bootstrap transitive dependencies',
      () async => dependencyResolutionTest(
        {
          'a': [],
          'b': ['a'],
          'c': ['b'],
        },
      ),
    );

    test(
      'bootstrap cyclic dependencies',
      () async => dependencyResolutionTest(
        {
          'a': ['b'],
          'b': ['a'],
        },
      ),
    );

    test('respects user dependency_overrides', () async {
      final workspaceDir = await createTemporaryWorkspace();

      final pkgA = await createProject(
        workspaceDir,
        PubSpec(
          name: 'a',
          dependencies: {'path': HostedReference(VersionConstraint.any)},
          dependencyOverrides: {'path': HostedReference(VersionConstraint.any)},
        ),
      );

      await createProject(
        workspaceDir,
        const PubSpec(
          name: 'path',
        ),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await runMelosBootstrap(melos, logger);

      final packageConfig = packageConfigForPackageAt(pkgA);
      expect(
        packageConfig.packages
            .firstWhere((package) => package.name == 'path')
            .rootUri,
        contains('hosted/pub.dev/path'),
      );
    });

    test('bootstrap flutter example packages', () async {
      final workspaceDir = await createTemporaryWorkspace();

      await createProject(
        workspaceDir,
        const PubSpec(
          name: 'a',
          dependencies: {
            'flutter': SdkReference('flutter'),
          },
        ),
        path: 'packages/a',
      );

      final examplePkg = await createProject(
        workspaceDir,
        PubSpec(
          name: 'example',
          dependencies: {
            'a': HostedReference(VersionConstraint.any),
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

      final examplePkgConfig = packageConfigForPackageAt(examplePkg);
      final aPkgDependencyConfig = examplePkgConfig.packages
          .firstWhere((package) => package.name == 'a');
      expect(aPkgDependencyConfig.rootUri, '../../');
    });

    group('mergeMelosPubspecOverrides', () {
      void expectMergedMelosPubspecOverrides({
        required Map<String, String> melosDependencyOverrides,
        required String? currentPubspecOverrides,
        required String? updatedPubspecOverrides,
      }) {
        expect(
          mergeMelosPubspecOverrides(
            {
              for (final entry in melosDependencyOverrides.entries)
                entry.key: PathReference(entry.value),
            },
            currentPubspecOverrides,
          ),
          updatedPubspecOverrides,
        );
      }

      test('pubspec_overrides.yaml does not exist', () {
        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {},
          currentPubspecOverrides: null,
          updatedPubspecOverrides: null,
        );
        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {'a': '../a'},
          currentPubspecOverrides: null,
          updatedPubspecOverrides: '''
# melos_managed_dependency_overrides: a
dependency_overrides:
  a:
    path: ../a
''',
        );
      });

      test('existing pubspec_overrides.yaml is empty', () {
        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {},
          currentPubspecOverrides: '',
          updatedPubspecOverrides: null,
        );
        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {'a': '../a'},
          currentPubspecOverrides: '',
          updatedPubspecOverrides: '''
# melos_managed_dependency_overrides: a
dependency_overrides:
  a:
    path: ../a
''',
        );
      });

      test('existing pubspec_overrides.yaml has dependency_overrides', () {
        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {'a': '../a'},
          currentPubspecOverrides: '''
dependency_overrides: null
''',
          updatedPubspecOverrides: '''
# melos_managed_dependency_overrides: a
dependency_overrides:
  a:
    path: ../a
''',
        );

        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {'a': '../a'},
          currentPubspecOverrides: '''
dependency_overrides:
  x: any
''',
          updatedPubspecOverrides: '''
# melos_managed_dependency_overrides: a
dependency_overrides:
  a:
    path: ../a
  x: any
''',
        );
      });

      test('add melos managed dependency', () {
        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {'a': '../a', 'b': '../b'},
          currentPubspecOverrides: '''
# melos_managed_dependency_overrides: a
dependency_overrides:
  a:
    path: ../a
''',
          updatedPubspecOverrides: '''
# melos_managed_dependency_overrides: a,b
dependency_overrides:
  a:
    path: ../a
  b:
    path: ../b
''',
        );
      });

      test('remove melos managed dependency', () {
        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {},
          currentPubspecOverrides: '''
# melos_managed_dependency_overrides: a
dependency_overrides:
  a:
    path: ../a
''',
          updatedPubspecOverrides: '',
        );
      });

      test('update melos managed dependency', () {
        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {'a': '../aa'},
          currentPubspecOverrides: '''
# melos_managed_dependency_overrides: a
dependency_overrides:
  a:
    path: ../a
''',
          updatedPubspecOverrides: '''
# melos_managed_dependency_overrides: a
dependency_overrides:
  a:
    path: ../aa
''',
        );
      });

      test('add, update and remove melos managed dependency', () {
        expectMergedMelosPubspecOverrides(
          melosDependencyOverrides: {'b': '../bb', 'c': '../c'},
          currentPubspecOverrides: '''
# melos_managed_dependency_overrides: a,b
dependency_overrides:
  a:
    path: ../a
  b:
    path: ../b
''',
          updatedPubspecOverrides: '''
# melos_managed_dependency_overrides: b,c
dependency_overrides:
  b:
    path: ../bb
  c:
    path: ../c
''',
        );
      });
    });

    test('handles errors in pub get', () async {
      final workspaceDir = await createTemporaryWorkspace();

      await createProject(
        workspaceDir,
        PubSpec(
          name: 'a',
          dependencies: {
            'package_that_does_not_exists': HostedReference(
              VersionConstraint.parse('^1.2.3-no-way-this-exists'),
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
          isA<BootstrapException>()
              .having((e) => e.package.name, 'package.name', 'a'),
        ),
      );

      expect(
        logger.output,
        ignoringAnsii(
          '''
melos bootstrap
  └> ${workspaceDir.path}

Running "${pubExecArgs.join(' ')} get" in workspace packages...
  - a
    └> packages/a
e-       └> Failed to install.

Resolving dependencies...
e-Because a depends on package_that_does_not_exists any which doesn't exist (could not find package package_that_does_not_exists at https://pub.dev), version solving failed.
''',
        ),
      );
    });

    test('can run pub get offline', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {
              'command': {
                'bootstrap': {
                  'runPubGetOffline': true,
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

Running "${pubExecArgs.join(' ')} get --offline" in workspace packages...
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
        configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
          createYamlMap(
            {
              'command': {
                'bootstrap': {
                  'enforceLockfile': true,
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

Running "${pubExecArgs.join(' ')} get --enforce-lockfile" in workspace packages...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 0 packages bootstrapped
''',
        ),
      );
    });

    test(
      'applies dependencies from melos config',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            name: 'Melos',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            commands: CommandConfigs(
              bootstrap: BootstrapCommandConfigs(
                environment: Environment(
                  VersionConstraint.parse('>=2.18.0 <3.0.0'),
                  {'flutter': '>=2.18.0 <3.0.0'},
                ),
                dependencies: {
                  'intl': HostedReference(
                    VersionConstraint.compatibleWith(Version.parse('0.18.1')),
                  ),
                  'integral_isolates': HostedReference(
                    VersionConstraint.compatibleWith(Version.parse('0.4.1')),
                  ),
                  'path': HostedReference(
                    VersionConstraint.compatibleWith(Version.parse('1.8.3')),
                  ),
                },
                devDependencies: {
                  'build_runner': HostedReference(
                    VersionConstraint.compatibleWith(Version.parse('2.4.6')),
                  ),
                },
              ),
            ),
            path: path,
          ),
        );

        final pkgA = await createProject(
          workspaceDir,
          PubSpec(
            name: 'a',
            environment: Environment(
              VersionConstraint.any,
              {},
            ),
            dependencies: {
              'intl': HostedReference(
                VersionConstraint.compatibleWith(Version.parse('0.18.1')),
              ),
              'path': HostedReference(
                VersionConstraint.compatibleWith(Version.parse('1.7.2')),
              ),
            },
            devDependencies: {
              'build_runner': HostedReference(
                VersionConstraint.compatibleWith(Version.parse('2.4.0')),
              ),
            },
          ),
        );

        final pkgB = await createProject(
          workspaceDir,
          PubSpec(
            name: 'b',
            environment: Environment(
              VersionRange(
                min: Version.parse('2.12.0'),
                max: Version.parse('3.0.0'),
                includeMin: true,
              ),
              {
                'flutter': '>=2.12.0 <3.0.0',
              },
            ),
            dependencies: {
              'integral_isolates': HostedReference(
                VersionConstraint.compatibleWith(Version.parse('0.4.1')),
              ),
              'intl': HostedReference(
                VersionConstraint.compatibleWith(Version.parse('0.17.0')),
              ),
              'path': HostedReference(VersionConstraint.any),
            },
          ),
        );

        final logger = TestLogger();
        final config =
            await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await runMelosBootstrap(melos, logger);

        final pubspecA = pubSpecFromYamlFile(directory: pkgA.path);
        final pubspecB = pubSpecFromYamlFile(directory: pkgB.path);

        expect(
          pubspecA.environment?.sdkConstraint,
          equals(VersionConstraint.parse('>=2.18.0 <3.0.0')),
        );
        expect(
          pubspecA.environment?.unParsedYaml,
          equals({}),
        );
        expect(
          pubspecA.dependencies,
          equals({
            'intl': HostedReference(
              VersionConstraint.compatibleWith(Version.parse('0.18.1')),
            ),
            'path': HostedReference(
              VersionConstraint.compatibleWith(Version.parse('1.8.3')),
            ),
          }),
        );
        expect(
          pubspecA.devDependencies,
          equals({
            'build_runner': HostedReference(
              VersionConstraint.compatibleWith(Version.parse('2.4.6')),
            ),
          }),
        );

        expect(
          pubspecB.environment?.sdkConstraint,
          equals(VersionConstraint.parse('>=2.18.0 <3.0.0')),
        );
        expect(
          pubspecB.environment?.unParsedYaml,
          equals({'flutter': '>=2.18.0 <3.0.0'}),
        );
        expect(
          pubspecB.dependencies,
          equals({
            'integral_isolates': HostedReference(
              VersionConstraint.compatibleWith(Version.parse('0.4.1')),
            ),
            'intl': HostedReference(
              VersionConstraint.compatibleWith(Version.parse('0.18.1')),
            ),
            'path': HostedReference(
              VersionConstraint.compatibleWith(Version.parse('1.8.3')),
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
  });
}

Future<void> runMelosBootstrap(Melos melos, TestLogger logger) async {
  try {
    await melos.bootstrap();
  } on BootstrapException {
    // ignore: avoid_print
    print(logger.output);
    rethrow;
  }
}

/// Tests whether dependencies are resolved correctly.
///
/// [packages] is a map where keys are package names and values are lists of
/// packages names on which the package in the corresponding key depends.
///
/// In the example below **a** has no dependencies and **b** depends only on
/// **a**:
///
/// ```dart main
/// final packages = {
///   'a': [],
///   'b': ['a']
/// };
/// ```
///
/// For each entry in [packages] a package with the key as the name will be
/// generated.
///
/// After running `melos bootstrap`, for each package it is verified that all
/// direct and transitive dependencies are path dependencies with the correct
/// path.
Future<void> dependencyResolutionTest(
  Map<String, List<String>> packages,
) async {
  final workspaceDir = await createTemporaryWorkspace();

  Future<MapEntry<String, io.Directory>> createPackage(
    MapEntry<String, List<String>> entry,
  ) async {
    final package = entry.key;
    final dependencies = entry.value;
    final directory = await createProject(
      workspaceDir,
      PubSpec(
        name: package,
        dependencies: {
          for (final dependency in dependencies)
            dependency: HostedReference(VersionConstraint.any),
        },
      ),
    );

    return MapEntry(package, directory);
  }

  final packageDirs = Map.fromEntries(
    await Future.wait(packages.entries.map(createPackage)),
  );

  List<String> transitiveDependenciesOfPackage(String root) {
    final transitiveDependencies = <String>[];
    final workingSet = packages[root]!.toList();

    while (workingSet.isNotEmpty) {
      final current = workingSet.removeLast();

      if (current == root) {
        continue;
      }

      if (!transitiveDependencies.contains(current)) {
        transitiveDependencies.add(current);
        workingSet.addAll(packages[current]!);
      }
    }

    return transitiveDependencies;
  }

  Future<void> validatePackage(String package) async {
    final packageConfig = packageConfigForPackageAt(packageDirs[package]!);
    final transitiveDependencies = transitiveDependenciesOfPackage(package);

    for (final dependency in transitiveDependencies) {
      final dependencyConfig =
          packageConfig.packages.firstWhere((e) => e.name == dependency);
      expect(dependencyConfig.rootUri, '../../$dependency');
    }
  }

  final logger = TestLogger();
  final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
  final melos = Melos(
    logger: logger,
    config: config,
  );

  await runMelosBootstrap(melos, logger);

  await Future.wait<void>(packages.keys.map(validatePackage));
}
