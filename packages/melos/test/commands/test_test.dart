import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/common/io.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('Melos Test', () {
    test('skips packages without a test/ directory', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a', 'b'],
      );

      final aDir = await createProject(workspaceDir, Pubspec('a'));
      writeTextFile(
        p.join(aDir.path, 'test', 'a_test.dart'),
        '''
import 'package:test/test.dart';

void main() {
  test('passes', () {
    expect(1, 1);
  });
}
''',
        recursive: true,
      );

      await createProject(workspaceDir, Pubspec('b'));

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(logger: logger, config: config);

      await melos.test();

      expect(logger.output.normalizeLines(), contains('a:'));
      expect(logger.output.normalizeLines(), isNot(contains('b:')));
    });

    test(
      'reports no packages found when none have a test/ directory',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b'],
        );
        await createProject(workspaceDir, Pubspec('a'));
        await createProject(workspaceDir, Pubspec('b'));

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(logger: logger, config: config);

        await melos.test();

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            contains('No packages with a test/ directory found.'),
          ),
        );
      },
    );

    test('sets exitCode to 1 when a package test run fails', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a'],
      );
      final aDir = await createProject(workspaceDir, Pubspec('a'));
      writeTextFile(
        p.join(aDir.path, 'test', 'a_test.dart'),
        '''
import 'package:test/test.dart';

void main() {
  test('fails', () {
    expect(1, 2);
  });
}
''',
        recursive: true,
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(logger: logger, config: config);

      final previousExitCode = exitCode;
      await melos.test();

      expect(exitCode, 1);

      exitCode = previousExitCode;
    });
    test(
      'correctly detects a flutter package inside a pub workspace',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a'],
        );

        await createProject(
          workspaceDir,
          Pubspec(
            'a',
            dependencies: {
              'flutter': SdkDependency('flutter'),
            },
          ),
        );

        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(logger: TestLogger(), config: config);
        final workspace = await melos.createWorkspace();

        final package = workspace.filteredPackages.values.first;

        expect(package.name, 'a');
        // Regression check for https://github.com/invertase/melos/issues/830:
        // package-type detection must still work under pub workspace
        // resolution, since `melos test` relies on it to pick
        // `flutter test` vs `dart test`.
        expect(package.isFlutterPackage, isTrue);
      },
    );
  });
}
