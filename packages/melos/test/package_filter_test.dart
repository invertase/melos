import 'package:melos/melos.dart';
import 'package:melos/src/common/io.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('PackageFilters', () {
    test('dirExists', () async {
      final workspaceDir = await createTemporaryWorkspace();

      final aDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );
      ensureDir(p.join(aDir.path, 'test'));

      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
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
        const PubSpec(name: 'a'),
      );
      writeTextFile(p.join(aDir.path, 'log.txt'), '');

      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
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
  });
}
