import 'dart:io';

import 'package:melos/src/common/intellij_project.dart';
import 'package:melos/src/common/io.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  // https://github.com/invertase/melos/issues/379
  test(
    'generates correct path for package at root in modules.xml ',
    () async {
      final tempDir = createTestTempDir();
      final workspaceBuilder =
          VirtualWorkspaceBuilder(
            path: tempDir.path,
            '''
        packages:
          - .
        ''',
          )..addPackage(
            '''
          name: root
          ''',
            path: '.',
          );
      final workspace = workspaceBuilder.build();
      final project = IntellijProject.fromWorkspace(workspace);
      await project.generate();
      final modulesXml = readTextFile(project.pathModulesXml);
      expect(modulesXml, contains(r'file://$PROJECT_DIR$/melos_root.iml'));
    },
  );

  // https://github.com/invertase/melos/issues/582
  test(
    'always generates iml paths with `/`',
    () async {
      final tempDir = createTestTempDir();
      final workspaceBuilder =
          VirtualWorkspaceBuilder(
            path: tempDir.path,
            '''
        packages:
          - .
        ''',
          )..addPackage(
            '''
          name: test
          ''',
            path: 'test',
          );
      final workspace = workspaceBuilder.build();
      final project = IntellijProject.fromWorkspace(workspace);
      await project.generate();
      final modulesXml = readTextFile(project.pathModulesXml);
      expect(modulesXml, contains(r'file://$PROJECT_DIR$/test/melos_test.iml'));
    },
  );

  // https://github.com/invertase/melos/issues/788
  test(
    'Use / in relative path for Windows',
    () async {
      final tempDir = createTestTempDir();
      await createProject(
        tempDir,
        Pubspec(
          'test',
          dependencies: {
            'flutter': SdkDependency('flutter'),
          },
        ),
        path: 'packages/test',
      );
      File(
        p.join(tempDir.path, 'packages', 'test', 'lib', 'main.dart'),
      ).createSync(recursive: true);

      final workspaceBuilder = VirtualWorkspaceBuilder(
        path: tempDir.path,
        '''
        packages:
          - packages/test
        ''',
      );
      workspaceBuilder.addPackage(
        File(
          p.join(tempDir.path, 'packages', 'test', 'pubspec.yaml'),
        ).readAsStringSync(),
      );
      final workspace = workspaceBuilder.build();
      final project = IntellijProject.fromWorkspace(workspace);
      await project.generate();
      final runXml = readTextFile(
        p.join(project.runConfigurationsDir.path, 'melos_flutter_run_test.xml'),
      );
      expect(
        runXml,
        contains(r'$PROJECT_DIR$/packages/test/lib/main.dart'),
      );
    },
  );
}
