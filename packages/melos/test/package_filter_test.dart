import 'package:glob/glob.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/io.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('PackageFilters', () {
    test('dirExists', () async {
      final workspaceDir = await createTemporaryWorkspace();

      final aDir = await createProject(
        workspaceDir,
        Pubspec('a'),
      );
      ensureDir(p.join(aDir.path, 'test'));

      await createProject(
        workspaceDir,
        Pubspec('b'),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger().toMelosLogger(),
        packageFilters: PackageFilters(
          dirExists: const ['test'],
        ),
      );

      expect(
        workspace.allPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'b'),
        ],
      );
      expect(
        workspace.filteredPackages.values,
        [isA<Package>().having((p) => p.name, 'name', 'a')],
      );
    });

    test('fileExists', () async {
      final workspaceDir = await createTemporaryWorkspace();

      final aDir = await createProject(
        workspaceDir,
        Pubspec('a'),
      );
      writeTextFile(p.join(aDir.path, 'log.txt'), '');

      await createProject(
        workspaceDir,
        Pubspec('b'),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger().toMelosLogger(),
        packageFilters: PackageFilters(
          fileExists: const ['log.txt'],
        ),
      );

      expect(
        workspace.allPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'b'),
        ],
      );
      expect(
        workspace.filteredPackages.values,
        [isA<Package>().having((p) => p.name, 'name', 'a')],
      );
    });

    test('ignore', () async {
      final workspaceDir = await createTemporaryWorkspace();

      await createProject(
        workspaceDir,
        Pubspec('a'),
      );

      await createProject(
        workspaceDir,
        Pubspec('b'),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger().toMelosLogger(),
        packageFilters: PackageFilters(
          ignore: [Glob('a')],
        ),
      );

      expect(
        workspace.allPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'b'),
        ],
      );
      expect(
        workspace.filteredPackages.values,
        [isA<Package>().having((p) => p.name, 'name', 'b')],
      );
    });

    test('category', () async {
      MelosWorkspaceConfig configBuilder(String path) {
        return MelosWorkspaceConfig(
          name: 'Melos',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          categories: {
            'a': [
              Glob('packages/a'),
              Glob('packages/c'),
            ],
            'b': [
              Glob('packages/*a*'),
            ],
            'c': [
              Glob('packages/ab*'),
            ],
          },
          path: path,
        );
      }

      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: configBuilder,
      );

      await createProject(
        workspaceDir,
        Pubspec('a'),
      );
      await createProject(
        workspaceDir,
        Pubspec('ab'),
      );
      await createProject(
        workspaceDir,
        Pubspec('abc'),
      );
      await createProject(
        workspaceDir,
        Pubspec('b'),
      );
      await createProject(
        workspaceDir,
        Pubspec('c'),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger().toMelosLogger(),
        packageFilters: PackageFilters(
          categories: [Glob('b')],
        ),
      );

      expect(
        workspace.allPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'ab'),
          isA<Package>().having((p) => p.name, 'name', 'abc'),
          isA<Package>().having((p) => p.name, 'name', 'b'),
          isA<Package>().having((p) => p.name, 'name', 'c'),
        ],
      );
      expect(
        workspace.filteredPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'ab'),
          isA<Package>().having((p) => p.name, 'name', 'abc'),
        ],
      );
    });
  });
}
