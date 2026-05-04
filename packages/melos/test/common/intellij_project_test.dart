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

  // https://github.com/invertase/melos/issues/1004
  group('runArguments', () {
    test(
      'generates single default config when no runArguments specified',
      () async {
        final tempDir = createTestTempDir();
        await createProject(
          tempDir,
          Pubspec(
            'my_app',
            dependencies: {
              'flutter': SdkDependency('flutter'),
            },
          ),
          path: 'packages/my_app',
        );
        File(
          p.join(tempDir.path, 'packages', 'my_app', 'lib', 'main.dart'),
        ).createSync(recursive: true);

        final workspaceBuilder = VirtualWorkspaceBuilder(
          path: tempDir.path,
          '''
          packages:
            - packages/my_app
          ''',
        );
        workspaceBuilder.addPackage(
          File(
            p.join(tempDir.path, 'packages', 'my_app', 'pubspec.yaml'),
          ).readAsStringSync(),
        );

        final workspace = workspaceBuilder.build();
        final project = IntellijProject.fromWorkspace(workspace);
        await project.writeFlutterRunScripts();

        final defaultXml = p.join(
          project.runConfigurationsDir.path,
          'melos_flutter_run_my_app.xml',
        );
        expect(File(defaultXml).existsSync(), isTrue);
        final content = readTextFile(defaultXml);
        expect(content, isNot(contains('additionalArgs')));
      },
    );

    test(
      'generates one config per named runArguments entry',
      () async {
        final tempDir = createTestTempDir();
        await createProject(
          tempDir,
          Pubspec(
            'my_app',
            dependencies: {
              'flutter': SdkDependency('flutter'),
            },
          ),
          path: 'packages/my_app',
        );
        File(
          p.join(tempDir.path, 'packages', 'my_app', 'lib', 'main.dart'),
        ).createSync(recursive: true);

        final workspaceBuilder = VirtualWorkspaceBuilder(
          path: tempDir.path,
          '''
          packages:
            - packages/my_app
          ide:
            intellij:
              runArguments:
                my_app:
                  - name: local
                    args: "--flavor local --dart-define-from-file=local.json"
                  - name: prod
                    args: "--flavor prod --dart-define-from-file=prod.json"
          ''',
        );
        workspaceBuilder.addPackage(
          File(
            p.join(tempDir.path, 'packages', 'my_app', 'pubspec.yaml'),
          ).readAsStringSync(),
        );

        final workspace = workspaceBuilder.build();
        final project = IntellijProject.fromWorkspace(workspace);
        await project.writeFlutterRunScripts();

        final localXml = p.join(
          project.runConfigurationsDir.path,
          'melos_flutter_run_my_app_local.xml',
        );
        final prodXml = p.join(
          project.runConfigurationsDir.path,
          'melos_flutter_run_my_app_prod.xml',
        );

        expect(File(localXml).existsSync(), isTrue);
        expect(File(prodXml).existsSync(), isTrue);

        final localContent = readTextFile(localXml);
        expect(localContent, contains('--flavor local'));
        expect(localContent, contains('additionalArgs'));

        final prodContent = readTextFile(prodXml);
        expect(prodContent, contains('--flavor prod'));
        expect(prodContent, contains('additionalArgs'));
      },
    );

    test(
      'entry with default: true generates config with package name as filename',
      () async {
        final tempDir = createTestTempDir();
        await createProject(
          tempDir,
          Pubspec(
            'my_app',
            dependencies: {
              'flutter': SdkDependency('flutter'),
            },
          ),
          path: 'packages/my_app',
        );
        File(
          p.join(tempDir.path, 'packages', 'my_app', 'lib', 'main.dart'),
        ).createSync(recursive: true);

        final workspaceBuilder = VirtualWorkspaceBuilder(
          path: tempDir.path,
          '''
          packages:
            - packages/my_app
          ide:
            intellij:
              runArguments:
                my_app:
                  - default: true
                    args: "--flavor dev"
          ''',
        );
        workspaceBuilder.addPackage(
          File(
            p.join(tempDir.path, 'packages', 'my_app', 'pubspec.yaml'),
          ).readAsStringSync(),
        );

        final workspace = workspaceBuilder.build();
        final project = IntellijProject.fromWorkspace(workspace);
        await project.writeFlutterRunScripts();

        final defaultXml = p.join(
          project.runConfigurationsDir.path,
          'melos_flutter_run_my_app.xml',
        );
        expect(File(defaultXml).existsSync(), isTrue);
        final content = readTextFile(defaultXml);
        expect(content, contains('--flavor dev'));
        expect(content, contains('additionalArgs'));
      },
    );

    test(
      'escapes XML special characters in args',
      () async {
        final tempDir = createTestTempDir();
        await createProject(
          tempDir,
          Pubspec(
            'my_app',
            dependencies: {
              'flutter': SdkDependency('flutter'),
            },
          ),
          path: 'packages/my_app',
        );
        File(
          p.join(tempDir.path, 'packages', 'my_app', 'lib', 'main.dart'),
        ).createSync(recursive: true);

        final workspaceBuilder = VirtualWorkspaceBuilder(
          path: tempDir.path,
          '''
          packages:
            - packages/my_app
          ide:
            intellij:
              runArguments:
                my_app:
                  - name: local
                    args: '--dart-define=KEY="value"'
          ''',
        );
        workspaceBuilder.addPackage(
          File(
            p.join(tempDir.path, 'packages', 'my_app', 'pubspec.yaml'),
          ).readAsStringSync(),
        );

        final workspace = workspaceBuilder.build();
        final project = IntellijProject.fromWorkspace(workspace);
        await project.writeFlutterRunScripts();

        final xmlFile = p.join(
          project.runConfigurationsDir.path,
          'melos_flutter_run_my_app_local.xml',
        );
        expect(File(xmlFile).existsSync(), isTrue);
        final content = readTextFile(xmlFile);
        expect(content, contains('&quot;'));
        expect(content, isNot(contains('"value"')));
      },
    );
  });
}
