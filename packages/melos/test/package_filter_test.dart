import 'dart:io';

import 'package:melos/melos.dart';
import 'package:path/path.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('PackageFilter', () {
    test('dirExists', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory();

      final aDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );
      Directory(join(aDir.path, 'test')).createSync();

      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );

      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger(),
        filter: PackageFilter(
          dirExists: ['test'],
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
      final workspaceDir = createTemporaryWorkspaceDirectory();

      final aDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );
      File(join(aDir.path, 'log.txt')).createSync();

      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );

      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger(),
        filter: PackageFilter(
          fileExists: ['log.txt'],
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
