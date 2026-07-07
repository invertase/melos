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

 - `b` - `v0.0.2`
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
          expect(pubspecApp.version, Version.parse('0.0.2'));
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

    // Regression coverage for
    // https://github.com/invertase/melos/issues/1039: a dependent's
    // constraint on a versioned package used to be corrupted (not just left
    // un-rewritten) when it was declared as a quoted, space-separated range
    // (e.g. `">=0.4.0 <1.0.0"`), because the regex used to locate the old
    // constraint stopped matching at the first space, and the caret rewrite
    // was spliced over only that partial match. `crypto_keys_plus` in
    // https://github.com/Bdaya-Dev/oidc is the real-world package that hit
    // this.
    group('dependent constraint rewrite (regression for #1039)', () {
      Future<void> expectDependentPubspecRewrite({
        required String dependentPubspecYaml,
        required String expectedDependentPubspecYaml,
        // Extra real workspace packages to create alongside `a` and `b`,
        // e.g. to give a sibling dependency in `b`'s pubspec something
        // resolvable to point at.
        Map<String, Version> extraWorkspacePackages = const {},
      }) async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: _workspaceConfigBuilder,
          workspacePackages: ['a', 'b', ...extraWorkspacePackages.keys],
          useLocalTmpDirectory: true,
        );

        // `a`'s starting version must be admitted by every constraint used
        // below to declare a dependency on it, or `pub get` will (correctly)
        // fail to resolve the workspace before `melos version` ever runs.
        await createProject(
          workspaceDir,
          Pubspec('a', version: Version(0, 4, 0)),
        );

        for (final entry in extraWorkspacePackages.entries) {
          await createProject(
            workspaceDir,
            Pubspec(entry.key, version: entry.value),
          );
        }

        await createProject(
          workspaceDir,
          Pubspec.parse(dependentPubspecYaml),
          rawPubspecContent: dependentPubspecYaml,
        );

        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(config: config, logger: logger);

        await melos.bootstrap(offline: true);
        await melos.version(
          // Avoids the "provide an additional changelog entry message?"
          // prompt this test has no commits to answer for; irrelevant to the
          // dependent pubspec rewrite under test.
          updateChangelog: false,
          // Isolates the dependent *constraint* rewrite under test from the
          // unrelated (and separately covered) cascading dependent *version*
          // bump, which would otherwise also touch `b`'s own `version:`.
          updateDependentsVersions: false,
          versionPrivatePackages: true,
          gitCommit: false,
          gitTag: false,
          force: true,
          manualVersions: {
            'a': ManualVersionChange(Version(0, 6, 0)),
          },
        );

        final actual = File(
          p.join(workspaceDir.path, 'packages/b/pubspec.yaml'),
        ).readAsStringSync();

        // The rewritten pubspec must always remain valid, parseable YAML -
        // this is the assertion that would have caught #1039 even without
        // pinning the exact expected output below.
        expect(() => Pubspec.parse(actual), returnsNormally);

        expect(actual, expectedDependentPubspecYaml);
      }

      test(
        'quoted, space-separated range constraint (exact bug from #1039)',
        () async {
          const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ">=0.4.0 <1.0.0"
''';
          await expectDependentPubspecRewrite(
            dependentPubspecYaml: dependentPubspecYaml,
            expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ^0.6.0
''',
          );
        },
      );

      test('single-quoted, space-separated range constraint', () async {
        const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: '>=0.4.0 <1.0.0'
''';
        await expectDependentPubspecRewrite(
          dependentPubspecYaml: dependentPubspecYaml,
          expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ^0.6.0
''',
        );
      });

      test('unquoted caret constraint (regression guard)', () async {
        const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ^0.4.0
''';
        await expectDependentPubspecRewrite(
          dependentPubspecYaml: dependentPubspecYaml,
          expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ^0.6.0
''',
        );
      });

      test('"any" constraint (regression guard)', () async {
        const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: any
''';
        await expectDependentPubspecRewrite(
          dependentPubspecYaml: dependentPubspecYaml,
          expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ^0.6.0
''',
        );
      });

      test(
        'exact pinned version constraint is replaced with an exact pin '
        '(regression guard)',
        () async {
          const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: 0.4.0
''';
          await expectDependentPubspecRewrite(
            dependentPubspecYaml: dependentPubspecYaml,
            expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: 0.6.0
''',
          );
        },
      );

      test(
        'prerelease and build metadata suffix constraint (regression guard)',
        () async {
          // An explicit range (rather than `^0.4.0-dev.1+001`) is used here
          // so the constraint still admits `a`'s actual starting version,
          // `0.4.0` - a caret range anchored on a pre-release only admits
          // versions up to (but excluding) the associated stable release.
          const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ">=0.4.0-dev.1+001 <1.0.0"
''';
          await expectDependentPubspecRewrite(
            dependentPubspecYaml: dependentPubspecYaml,
            expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ^0.6.0
''',
          );
        },
      );

      test(
        'trailing comment on the constraint line is preserved '
        '(regression guard)',
        () async {
          const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ">=0.4.0 <1.0.0" # keep this note
''';
          await expectDependentPubspecRewrite(
            dependentPubspecYaml: dependentPubspecYaml,
            expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a: ^0.6.0 # keep this note
''',
          );
        },
      );

      test(
        'sibling dependencies are left untouched (regression guard)',
        () async {
          const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  c: ^2.0.0
  a: ">=0.4.0 <1.0.0"
''';
          await expectDependentPubspecRewrite(
            dependentPubspecYaml: dependentPubspecYaml,
            expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  c: ^2.0.0
  a: ^0.6.0
''',
            extraWorkspacePackages: {'c': Version(2, 0, 0)},
          );
        },
      );

      test(
        'quoted, space-separated range constraint on an externally hosted '
        'dependency',
        () async {
          const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a:
    hosted: https://my-registry.example.com
    version: ">=0.4.0 <1.0.0"
''';
          await expectDependentPubspecRewrite(
            dependentPubspecYaml: dependentPubspecYaml,
            expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a:
    hosted: https://my-registry.example.com
    version: ^0.6.0
''',
          );
        },
      );

      test(
        'quoted, space-separated range constraint on a git tag pattern '
        'dependency',
        () async {
          const dependentPubspecYaml = '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a:
    git:
      url: github.com/a/a.git
      path: packages/a
      tag_pattern: a-v{{version}}
    version: ">=0.4.0 <1.0.0"
''';
          // Git tag pattern dependencies preserve whether the *existing*
          // constraint used caret syntax; `">=0.4.0 <1.0.0"` above has no
          // leading `^`, so the rewritten value doesn't gain one either.
          await expectDependentPubspecRewrite(
            dependentPubspecYaml: dependentPubspecYaml,
            expectedDependentPubspecYaml: '''
name: b
resolution: workspace
version: 1.0.0
environment:
  sdk: ^3.10.0
dependencies:
  a:
    git:
      url: github.com/a/a.git
      path: packages/a
      tag_pattern: a-v{{version}}
    version: 0.6.0
''',
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
