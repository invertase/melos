import 'dart:io' as io;

import 'package:melos/melos.dart';
import 'package:melos/src/commands/runner.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

io.Directory createTmpDir() {
  final dir = io.Directory.systemTemp.createTempSync();
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

void main() {
  group('bootstrap', () {
    test(
        'supports path dependencies in the pubspec for dependencies that '
        'are not part of the workspace', () async {
      final absoluteDir = createTmpDir();
      final relativeDir = createTmpDir();
      final relativeOverrideDir = createTmpDir();
      final relativeDevDir = createTmpDir();

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

      final workspaceDir = createTemporaryWorkspaceDirectory();

      final aPath = join(workspaceDir.path, 'packages', 'a');

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
      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(config);
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

Linking workspace packages...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 1 plugins bootstrapped
''',
        ),
      );

      final aConfig = packageConfigForPackageAt(aDir);
      final actualAbsoultePath = prettyUri(
        aConfig.packages.firstWhere((p) => p.name == 'absolute').rootUri,
      );
      expect(
        actualAbsoultePath,
        absoluteProject.path,
      );

      final actualRelativePath = prettyUri(
        aConfig.packages.firstWhere((p) => p.name == 'relative').rootUri,
      );
      expect(
        actualRelativePath,
        relativeProject.path,
      );

      final actualRelativeDevPath = prettyUri(
        aConfig.packages.firstWhere((p) => p.name == 'relative_dev').rootUri,
      );
      expect(
        actualRelativeDevPath,
        relativeDevProject.path,
      );

      final actualRelativeOverridePath = prettyUri(
        aConfig.packages
            .firstWhere((p) => p.name == 'relative_override')
            .rootUri,
      );
      expect(
        actualRelativeOverridePath,
        relativeOverrideProject.path,
      );
      expect(aConfig.generator, 'melos');
    });

    test('resolves workspace packages with path dependency', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory();

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
      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
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
Linking workspace packages...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 4 plugins bootstrapped
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
      expect(aConfig.generator, 'melos');
    });

    test(
      'bootstrap transitive dependencies',
      () => dependencyResolutionTest({
        'a': [],
        'b': ['a'],
        'c': ['b'],
      }),
    );

    test(
      'bootstrap cyclic dependencies',
      () => dependencyResolutionTest({
        'a': ['b'],
        'b': ['a'],
      }),
    );

    group('pubspec overrides', () {
      test(
        'bootstrap transitive dependencies',
        () => dependencyResolutionTest(
          {
            'a': [],
            'b': ['a'],
            'c': ['b'],
          },
          usePubspecOverrides: true,
        ),
        skip: !isPubspecOverridesSupported(),
      );

      test(
        'bootstrap cyclic dependencies',
        () => dependencyResolutionTest(
          {
            'a': ['b'],
            'b': ['a'],
          },
          usePubspecOverrides: true,
        ),
        skip: !isPubspecOverridesSupported(),
      );

      group('mergeMelosPubspecOverrides', () {
        void expectMergedMelosPubspecOverrides({
          required Map<String, String> melosDependencyOverrides,
          required String? currentPubspecOverrides,
          required String? updatedPubspecOverrides,
        }) {
          expect(
            mergeMelosPubspecOverrides(
              melosDependencyOverrides,
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
    });

    test('handles errors in pub get', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory();

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
      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(config);
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
e-    └> Failed to install.

Resolving dependencies...
e-Because a depends on package_that_does_not_exists any which doesn't exist (could not find package package_that_does_not_exists at https://pub.dartlang.org), version solving failed.
''',
        ),
      );
    });

    test('can disable IDE generation using melos config', () {}, skip: true);

    test('can supports package filter', () {}, skip: true);
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
/// ```dart
/// {
///   'a': [],
///   'b': ['a']
/// }
/// ```
///
/// For each entry in [packages] a package with the key as the name will be
/// generated.
///
/// After running `melos bootstrap`, for each package it is verified that all
/// direct and transitive dependencies are path dependencies with the correct
/// path.
Future<void> dependencyResolutionTest(
  Map<String, List<String>> packages, {
  bool usePubspecOverrides = false,
}) async {
  final workspaceDir = createTemporaryWorkspaceDirectory(
    configBuilder: (path) => MelosWorkspaceConfig.fallback(
      path: path,
      usePubspecOverrides: usePubspecOverrides,
    ),
  );

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
  final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
  final melos = Melos(
    logger: logger,
    config: config,
  );

  await runMelosBootstrap(melos, logger);

  await Future.wait<void>(packages.keys.map(validatePackage));
}
