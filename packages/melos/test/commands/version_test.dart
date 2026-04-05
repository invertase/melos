import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:glob/glob.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/command_configs/command_configs.dart';
import 'package:melos/src/common/git_tag_pattern_dependency.dart';
import 'package:melos/src/common/glob.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  late TestLogger logger;

  setUp(() async {
    logger = TestLogger();
  });

  group('version', () {
    test('Correctly updates min version in git tag pattern dependency '
        'on major version change', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: _workspaceConfigBuilder,
        workspacePackages: ['foo', 'bar'],
        useLocalTmpDirectory: true,
      );

      const barPubspecYaml = '''
name: bar
resolution: workspace
version: 1.0.0
environment: 
  sdk: ^3.10.0
dependencies:
  foo:
    git:
      url: github.com/foo/foo.git
      path: packages/foo
      tag_pattern: foo-v{{version}}
    version: ^1.0.0
''';

      await createProject(
        workspaceDir,
        Pubspec(
          'foo',
          version: Version(1, 0, 0),
        ),
      );

      await createProject(
        workspaceDir,
        Pubspec.parse(barPubspecYaml),
        rawPubspecContent: barPubspecYaml,
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(config: config, logger: logger);
      await melos.bootstrap(offline: true);
      await melos.version(
        versionPrivatePackages: true,
        gitCommit: false,
        force: true,
        manualVersions: {
          'foo': ManualVersionChange(Version(2, 0, 0)),
        },
      );

      final barPubspecFile = File(
        p.join(workspaceDir.path, 'packages/bar/pubspec.yaml'),
      );

      final gitTagDependency = GitTagPatternDependency.fromRawCommit(
        pubspec: barPubspecFile.readAsStringSync(),
        name: 'foo',
      );

      expect(gitTagDependency, isNotNull);
      expect(gitTagDependency!.version, Version(2, 0, 0));
    });
    test('Does min version in git tag pattern dependency'
        ' on minor version change', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: _workspaceConfigBuilder,
        workspacePackages: ['foo', 'bar'],
        useLocalTmpDirectory: true,
      );

      const barPubspecYaml = '''
name: bar
resolution: workspace
version: 1.0.0
environment: 
  sdk: ^3.10.0
dependencies:
  foo:
    git:
      url: github.com/foo/foo.git
      path: packages/foo
      tag_pattern: foo-v{{version}}
    version: ^1.0.0
''';

      await createProject(
        workspaceDir,
        Pubspec(
          'foo',
          version: Version(1, 0, 0),
        ),
      );

      await createProject(
        workspaceDir,
        Pubspec.parse(barPubspecYaml),
        rawPubspecContent: barPubspecYaml,
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(config: config, logger: logger);
      await melos.bootstrap(offline: true);
      await melos.version(
        versionPrivatePackages: true,
        gitCommit: false,
        force: true,
        manualVersions: {
          'foo': ManualVersionChange(Version(1, 1, 0)),
        },
      );

      final barPubspecFile = File(
        p.join(workspaceDir.path, 'packages/bar/pubspec.yaml'),
      );

      final gitTagDependency = GitTagPatternDependency.fromRawCommit(
        pubspec: barPubspecFile.readAsStringSync(),
        name: 'foo',
      );

      expect(gitTagDependency, isNotNull);
      expect(gitTagDependency!.version, Version(1, 1, 0));
    });
    test('Does min version in git tag pattern dependency'
        ' on patch version change', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: _workspaceConfigBuilder,
        workspacePackages: ['foo', 'bar'],
        useLocalTmpDirectory: true,
      );

      const barPubspecYaml = '''
name: bar
resolution: workspace
version: 1.0.0
environment: 
  sdk: ^3.10.0
dependencies:
  foo:
    git:
      url: github.com/foo/foo.git
      path: packages/foo
      tag_pattern: foo-v{{version}}
    version: ^1.0.0
''';

      await createProject(
        workspaceDir,
        Pubspec(
          'foo',
          version: Version(1, 0, 0),
        ),
      );

      await createProject(
        workspaceDir,
        Pubspec.parse(barPubspecYaml),
        rawPubspecContent: barPubspecYaml,
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(config: config, logger: logger);
      await melos.bootstrap(offline: true);
      await melos.version(
        versionPrivatePackages: true,
        gitCommit: false,
        force: true,
        manualVersions: {
          'foo': ManualVersionChange(Version(1, 0, 1)),
        },
      );

      final barPubspecFile = File(
        p.join(workspaceDir.path, 'packages/bar/pubspec.yaml'),
      );

      final gitTagDependency = GitTagPatternDependency.fromRawCommit(
        pubspec: barPubspecFile.readAsStringSync(),
        name: 'foo',
      );

      expect(gitTagDependency, isNotNull);
      expect(gitTagDependency!.version, Version(1, 0, 1));
    });
    test('Does fix version in git tag pattern dependency'
        ' on version change', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: _workspaceConfigBuilder,
        workspacePackages: ['foo', 'bar'],
        useLocalTmpDirectory: true,
      );

      const barPubspecYaml = '''
name: bar
resolution: workspace
version: 1.0.0
environment: 
  sdk: ^3.10.0
dependencies:
  foo:
    git:
      url: github.com/foo/foo.git
      path: packages/foo
      tag_pattern: foo-v{{version}}
    version: 1.0.0
''';

      await createProject(
        workspaceDir,
        Pubspec(
          'foo',
          version: Version(1, 0, 0),
        ),
      );

      await createProject(
        workspaceDir,
        Pubspec.parse(barPubspecYaml),
        rawPubspecContent: barPubspecYaml,
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(config: config, logger: logger);
      await melos.bootstrap(offline: true);
      await melos.version(
        versionPrivatePackages: true,
        gitCommit: false,
        force: true,
        manualVersions: {
          'foo': ManualVersionChange(Version(1, 1, 0)),
        },
      );

      final barPubspecFile = File(
        p.join(workspaceDir.path, 'packages/bar/pubspec.yaml'),
      );

      final gitTagDependency = GitTagPatternDependency.fromRawCommit(
        pubspec: barPubspecFile.readAsStringSync(),
        name: 'foo',
      );

      expect(gitTagDependency, isNotNull);
      expect(gitTagDependency!.version, Version(1, 1, 0));
    });
    test('Correctly updates package version', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: _workspaceConfigBuilder,
        workspacePackages: ['a'],
        useLocalTmpDirectory: true,
      );
      await createProject(
        workspaceDir,
        Pubspec('a', version: Version(0, 0, 1)),
      );
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(config: config, logger: logger);

      await melos.bootstrap();
      await melos.version(
        updateDependentsConstraints: false,
        updateDependentsVersions: false,
        versionPrivatePackages: true,
        gitCommit: false,
        gitTag: false,
        force: true,
        manualVersions: {
          'a': ManualVersionChange(Version(0, 1, 0)),
        },
      );

      final loggerOutput = logger.output;
      expect(
        loggerOutput,
        contains(
          AnsiStyles.strip('''
The following 1 packages will be updated:
'''),
        ),
      );

      final pubspec = Pubspec.parse(
        File(
          p.join(workspaceDir.path, 'packages/a/pubspec.yaml'),
        ).readAsStringSync(),
      );
      expect(pubspec.version, Version(0, 1, 0));
    });

    // Regression test for: https://github.com/invertase/melos/issues/531
    test(
      '--no-dependent-versions does not modify workspace changelog',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: _workspaceConfigBuilder,
          workspacePackages: ['a', 'b'],
          useLocalTmpDirectory: true,
        );
        await createProject(
          workspaceDir,
          Pubspec('a', version: Version(0, 0, 1)),
        );
        await createProject(
          workspaceDir,
          Pubspec(
            'b',
            version: Version(0, 0, 1),
            dependencies: {
              'a': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(config: config, logger: logger);

        await melos.bootstrap();
        await melos.version(
          updateDependentsConstraints: false,
          updateDependentsVersions: false,
          versionPrivatePackages: true,
          gitCommit: false,
          gitTag: false,
          force: true,
          manualVersions: {
            'a': ManualVersionChange(Version(0, 1, 0)),
          },
        );

        final workspaceChangelogContent = File(
          p.join(workspaceDir.path, 'CHANGELOG.md'),
        ).readAsStringSync();

        final loggerOutput = logger.output;
        expect(
          loggerOutput,
          contains(
            AnsiStyles.strip('''
The following 1 packages will be updated:
'''),
          ),
        );

        expect(
          workspaceChangelogContent,
          isNot(
            contains(
              AnsiStyles.strip('''
> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `b` - `v0.0.1+1`
'''),
            ),
          ),
        );
        expect(
          workspaceChangelogContent,
          contains(
            AnsiStyles.strip('''
#### `a` - `v0.1.0`

 - Bump "a" to `0.1.0`.
'''),
          ),
        );
      },
    );

    group('--ignore', () {
      test('ignores packages matching the ignore glob', () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: _workspaceConfigBuilder,
          workspacePackages: ['a', 'b'],
          useLocalTmpDirectory: true,
        );
        await createProject(
          workspaceDir,
          Pubspec('a', version: Version(0, 0, 1)),
        );
        await createProject(
          workspaceDir,
          Pubspec('b', version: Version(0, 0, 1)),
        );
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(config: config, logger: logger);

        await melos.bootstrap(offline: true);
        await melos.version(
          packageFilters: PackageFilters(ignore: [Glob('b')]),
          updateDependentsConstraints: false,
          updateDependentsVersions: false,
          versionPrivatePackages: true,
          gitCommit: false,
          gitTag: false,
          force: true,
          manualVersions: {
            'a': ManualVersionChange(Version(0, 1, 0)),
          },
        );

        final pubspecA = Pubspec.parse(
          File(
            p.join(workspaceDir.path, 'packages/a/pubspec.yaml'),
          ).readAsStringSync(),
        );
        final pubspecB = Pubspec.parse(
          File(
            p.join(workspaceDir.path, 'packages/b/pubspec.yaml'),
          ).readAsStringSync(),
        );
        expect(pubspecA.version, Version(0, 1, 0));
        expect(pubspecB.version, Version(0, 0, 1));
      });

      test(
        'skips manual version for ignored package and logs warning',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            configBuilder: _workspaceConfigBuilder,
            workspacePackages: ['a'],
            useLocalTmpDirectory: true,
          );
          await createProject(
            workspaceDir,
            Pubspec('a', version: Version(0, 0, 1)),
          );
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(config: config, logger: logger);

          await melos.bootstrap(offline: true);
          await melos.version(
            packageFilters: PackageFilters(ignore: [Glob('a')]),
            updateDependentsConstraints: false,
            updateDependentsVersions: false,
            versionPrivatePackages: true,
            gitCommit: false,
            gitTag: false,
            force: true,
            manualVersions: {
              'a': ManualVersionChange(Version(0, 1, 0)),
            },
          );

          final pubspec = Pubspec.parse(
            File(
              p.join(workspaceDir.path, 'packages/a/pubspec.yaml'),
            ).readAsStringSync(),
          );
          // Package should NOT have been versioned since it was ignored.
          expect(pubspec.version, Version(0, 0, 1));
          expect(
            logger.output,
            contains('excluded by package filters'),
          );
        },
      );

      test(
        'does not version dependents of ignored intermediate packages',
        () async {
          // Setup: core -> mid -> app
          // core is versioned, mid is ignored.
          // app depends on mid, so it should NOT get a dependent version bump
          // since mid (the intermediate) is ignored and won't be bumped.
          final workspaceDir = await createTemporaryWorkspace(
            configBuilder: _workspaceConfigBuilder,
            workspacePackages: ['core', 'mid', 'app'],
            useLocalTmpDirectory: true,
          );
          await createProject(
            workspaceDir,
            Pubspec('core', version: Version(0, 0, 1)),
          );
          await createProject(
            workspaceDir,
            Pubspec(
              'mid',
              version: Version(0, 0, 1),
              dependencies: {
                'core': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );
          await createProject(
            workspaceDir,
            Pubspec(
              'app',
              version: Version(0, 0, 1),
              dependencies: {
                'mid': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(config: config, logger: logger);

          await melos.bootstrap(offline: true);
          await melos.version(
            packageFilters: PackageFilters(ignore: [Glob('mid')]),
            versionPrivatePackages: true,
            gitCommit: false,
            gitTag: false,
            force: true,
            manualVersions: {
              'core': ManualVersionChange(Version(0, 1, 0)),
            },
          );

          final pubspecCore = Pubspec.parse(
            File(
              p.join(workspaceDir.path, 'packages/core/pubspec.yaml'),
            ).readAsStringSync(),
          );
          final pubspecMid = Pubspec.parse(
            File(
              p.join(workspaceDir.path, 'packages/mid/pubspec.yaml'),
            ).readAsStringSync(),
          );
          final pubspecApp = Pubspec.parse(
            File(
              p.join(workspaceDir.path, 'packages/app/pubspec.yaml'),
            ).readAsStringSync(),
          );
          // core was manually versioned.
          expect(pubspecCore.version, Version(0, 1, 0));
          // mid is ignored, should NOT have been bumped.
          expect(pubspecMid.version, Version(0, 0, 1));
          // app depends only on mid (which is ignored), so it should also NOT
          // have been bumped.
          expect(pubspecApp.version, Version(0, 0, 1));
        },
      );

      test(
        'versions dependents that have a non-ignored path to the versioned '
        'package',
        () async {
          // Setup: core -> mid (ignored), core -> app, mid -> app
          // core is versioned, mid is ignored.
          // app depends on both core and mid. Since app directly depends on
          // core (non-ignored path), it should still get a dependent bump.
          final workspaceDir = await createTemporaryWorkspace(
            configBuilder: _workspaceConfigBuilder,
            workspacePackages: ['core', 'mid', 'app'],
            useLocalTmpDirectory: true,
          );
          await createProject(
            workspaceDir,
            Pubspec('core', version: Version(0, 0, 1)),
          );
          await createProject(
            workspaceDir,
            Pubspec(
              'mid',
              version: Version(0, 0, 1),
              dependencies: {
                'core': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );
          await createProject(
            workspaceDir,
            Pubspec(
              'app',
              version: Version(0, 0, 1),
              dependencies: {
                'core': HostedDependency(version: VersionConstraint.any),
                'mid': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(config: config, logger: logger);

          await melos.bootstrap(offline: true);
          await melos.version(
            packageFilters: PackageFilters(ignore: [Glob('mid')]),
            versionPrivatePackages: true,
            gitCommit: false,
            gitTag: false,
            force: true,
            manualVersions: {
              'core': ManualVersionChange(Version(0, 1, 0)),
            },
          );

          final pubspecApp = Pubspec.parse(
            File(
              p.join(workspaceDir.path, 'packages/app/pubspec.yaml'),
            ).readAsStringSync(),
          );
          // app directly depends on core, so it should get a dependent bump
          // even though mid is ignored.
          expect(pubspecApp.version, Version.parse('0.0.1+1'));
        },
      );

      test(
        'skips package with own changes if it depends on ignored package '
        'with changes',
        () async {
          // Setup: a depends on b, both have manual versions specified.
          // b is ignored. a should NOT be versioned because its dependency
          // on b (which has pending changes) would produce a broken release.
          final workspaceDir = await createTemporaryWorkspace(
            configBuilder: _workspaceConfigBuilder,
            workspacePackages: ['a', 'b'],
            useLocalTmpDirectory: true,
          );
          await createProject(
            workspaceDir,
            Pubspec(
              'a',
              version: Version(0, 0, 1),
              dependencies: {
                'b': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );
          await createProject(
            workspaceDir,
            Pubspec('b', version: Version(0, 0, 1)),
          );
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(config: config, logger: logger);

          await melos.bootstrap(offline: true);
          await melos.version(
            packageFilters: PackageFilters(ignore: [Glob('b')]),
            updateDependentsConstraints: false,
            updateDependentsVersions: false,
            versionPrivatePackages: true,
            gitCommit: false,
            gitTag: false,
            force: true,
            manualVersions: {
              'a': ManualVersionChange(Version(0, 1, 0)),
              'b': ManualVersionChange(Version(0, 1, 0)),
            },
          );

          final pubspecA = Pubspec.parse(
            File(
              p.join(workspaceDir.path, 'packages/a/pubspec.yaml'),
            ).readAsStringSync(),
          );
          final pubspecB = Pubspec.parse(
            File(
              p.join(workspaceDir.path, 'packages/b/pubspec.yaml'),
            ).readAsStringSync(),
          );
          // b is ignored, should not be versioned.
          expect(pubspecB.version, Version(0, 0, 1));
          // a depends on ignored b which has pending changes, so a should
          // also be skipped to avoid a broken release.
          expect(pubspecA.version, Version(0, 0, 1));
          expect(
            logger.output,
            contains('depends on an ignored package'),
          );
        },
      );
    });
  });
}

MelosWorkspaceConfig _workspaceConfigBuilder(String path) {
  return MelosWorkspaceConfig(
    path: path,
    name: 'test_workspace',
    packages: [
      createGlob('packages/**', currentDirectoryPath: path),
    ],
    commands: const CommandConfigs(
      version: VersionCommandConfigs(
        fetchTags: false,
        updateGitTagRefs: true,
      ),
    ),
  );
}
