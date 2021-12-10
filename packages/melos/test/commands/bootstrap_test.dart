import 'dart:io' as io;

import 'package:melos/melos.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('bootstrap', () {
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

      await melos.bootstrap();

      expect(
        logger.output,
        equalsIgnoringAnsii(
          '''
melos bootstrap
   └> ${workspaceDir.path}

Running "flutter pub get" in workspace packages...
  ✓ a
    └> packages/a
  ✓ b
    └> packages/b
  ✓ c
    └> packages/c
  ✓ d
    └> packages/d

Linking workspace packages...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 4 plugins bootstrapped
''',
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
      final melos = Melos(
        logger: logger,
        config: config,
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
        equalsIgnoringAnsii(
          '''
melos bootstrap
   └> ${workspaceDir.path}

Running "pub get" in workspace packages...
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

/// Tests whether dependencies are resolved correctly.
///
/// [packages] is a map where keys are package names and values are lists of
/// packages names on which the package in the corresponding key depends.
///
/// In this example below **a** has no dependencies and **b** depends only on
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
  Map<String, List<String>> packages,
) async {
  final workspaceDir = createTemporaryWorkspaceDirectory();

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

  await melos.bootstrap();

  await Future.wait<void>(packages.keys.map(validatePackage));
}
