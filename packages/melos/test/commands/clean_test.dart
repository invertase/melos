import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/utils.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group('clean', () {
    test(
      'strips melos-managed dependency_overrides from workspace root '
      'pubspec_overrides.yaml while preserving user-defined entries',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a'],
        );

        await createProject(
          workspaceDir,
          Pubspec('a'),
        );

        final overridesPath = pubspecOverridesPathForDirectory(
          workspaceDir.path,
        );
        writeTextFile(
          overridesPath,
          '''
# melos_managed_dependency_overrides: managed_pkg
dependency_overrides:
  managed_pkg:
    path: ../managed_pkg
  user_pkg:
    path: ../user_pkg
''',
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        await Melos(logger: logger, config: config).clean();

        expect(File(overridesPath).existsSync(), isTrue);
        final after = readTextFile(overridesPath);
        expect(
          after,
          isNot(contains('melos_managed_dependency_overrides')),
        );
        expect(after, isNot(contains('managed_pkg')));
        expect(after, contains('user_pkg'));
      },
    );

    test(
      'deletes workspace pubspec_overrides.yaml when only melos-managed '
      'entries remain',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a'],
        );

        await createProject(
          workspaceDir,
          Pubspec('a'),
        );

        final overridesPath = pubspecOverridesPathForDirectory(
          workspaceDir.path,
        );
        writeTextFile(
          overridesPath,
          '''
# melos_managed_dependency_overrides: managed_pkg
dependency_overrides:
  managed_pkg:
    path: ../managed_pkg
''',
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        await Melos(logger: logger, config: config).clean();

        expect(File(overridesPath).existsSync(), isFalse);
      },
    );
  });
}
