import 'dart:io';

import 'package:melos/src/common/environment_variable_key.dart';
import 'package:melos/src/common/intellij_project.dart';
import 'package:melos/src/common/io.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart' show FakePlatform;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import '../mock_env.dart';
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

  // https://github.com/invertase/melos/issues/644
  group('Dart package run configurations', () {
    Future<IntellijProject> createDartProject(
      Directory tempDir, {
      required String packageName,
      required List<String> executableNames,
      Map<String, Dependency> devDependencies = const {},
      bool withTests = false,
    }) async {
      await createProject(
        tempDir,
        Pubspec(packageName, devDependencies: devDependencies),
        path: 'packages/$packageName',
      );
      final packagePath = p.join(tempDir.path, 'packages', packageName);
      for (final executableName in executableNames) {
        File(
          p.join(packagePath, 'bin', executableName),
        ).createSync(recursive: true);
      }
      if (withTests) {
        File(
          p.join(packagePath, 'test', '${packageName}_test.dart'),
        ).createSync(recursive: true);
      }

      final workspaceBuilder = VirtualWorkspaceBuilder(
        path: tempDir.path,
        '''
        packages:
          - packages/$packageName
        ''',
      );
      workspaceBuilder.addPackage(
        File(p.join(packagePath, 'pubspec.yaml')).readAsStringSync(),
      );
      return IntellijProject.fromWorkspace(workspaceBuilder.build());
    }

    test('generates a Dart run configuration per executable in bin', () async {
      final tempDir = createTestTempDir();
      final project = await createDartProject(
        tempDir,
        packageName: 'my_cli',
        executableNames: ['my_cli.dart', 'other.dart', 'notes.txt'],
      );
      await project.generate();

      final myCliXml = readTextFile(
        p.join(
          project.runConfigurationsDir.path,
          'melos_dart_run_my_cli-my_cli.xml',
        ),
      );
      expect(myCliXml, contains('type="DartCommandLineRunConfigurationType"'));
      expect(myCliXml, contains("name=\"Dart Run -&gt; 'my_cli' (my_cli)\""));
      expect(
        myCliXml,
        contains(
          r'name="filePath" value="$PROJECT_DIR$/packages/my_cli/bin/my_cli.dart"',
        ),
      );
      expect(
        myCliXml,
        contains(
          r'name="workingDirectory" value="$PROJECT_DIR$/packages/my_cli"',
        ),
      );

      final otherXml = readTextFile(
        p.join(
          project.runConfigurationsDir.path,
          'melos_dart_run_my_cli-other.xml',
        ),
      );
      expect(otherXml, contains("name=\"Dart Run -&gt; 'my_cli' (other)\""));
      expect(
        otherXml,
        contains(r'$PROJECT_DIR$/packages/my_cli/bin/other.dart'),
      );

      expect(
        File(
          p.join(
            project.runConfigurationsDir.path,
            'melos_dart_run_my_cli-notes.xml',
          ),
        ).existsSync(),
        isFalse,
      );
    });

    test(
      'omits the executable name when a package has a single executable',
      () async {
        final tempDir = createTestTempDir();
        final project = await createDartProject(
          tempDir,
          packageName: 'my_cli',
          executableNames: ['main.dart'],
        );
        await project.writeDartRunScripts();

        final content = readTextFile(
          p.join(
            project.runConfigurationsDir.path,
            'melos_dart_run_my_cli-main.xml',
          ),
        );
        expect(content, contains("name=\"Dart Run -&gt; 'my_cli'\""));
      },
    );

    test('escapes XML characters in executable names', () async {
      final tempDir = createTestTempDir();
      final project = await createDartProject(
        tempDir,
        packageName: 'my_cli',
        executableNames: ['build&run.dart'],
      );
      await project.writeDartRunScripts();

      final content = readTextFile(
        p.join(
          project.runConfigurationsDir.path,
          'melos_dart_run_my_cli-build&run.xml',
        ),
      );
      expect(content, contains('bin/build&amp;run.dart'));
      expect(content, isNot(contains('build&run')));
      expect(() => XmlDocument.parse(content), returnsNormally);
    });

    test('uses the project directory directly for the root package', () async {
      final tempDir = createTestTempDir();
      File(
        p.join(tempDir.path, 'bin', 'root.dart'),
      ).createSync(recursive: true);
      File(
        p.join(tempDir.path, 'test', 'root_test.dart'),
      ).createSync(recursive: true);
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
      final project = IntellijProject.fromWorkspace(workspaceBuilder.build());
      await project.generate();

      final runXml = readTextFile(
        p.join(
          project.runConfigurationsDir.path,
          'melos_dart_run_root-root.xml',
        ),
      );
      expect(
        runXml,
        contains(r'name="filePath" value="$PROJECT_DIR$/bin/root.dart"'),
      );
      expect(
        runXml,
        contains(r'name="workingDirectory" value="$PROJECT_DIR$"'),
      );

      final testXml = readTextFile(
        p.join(project.runConfigurationsDir.path, 'melos_dart_test_root.xml'),
      );
      expect(testXml, contains(r'name="filePath" value="$PROJECT_DIR$/test"'));
    });

    test(
      'does not generate Dart configurations for packages using Flutter',
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
        await createProject(
          tempDir,
          Pubspec(
            'my_widgets',
            devDependencies: {
              'flutter_test': SdkDependency('flutter'),
            },
          ),
          path: 'packages/my_widgets',
        );
        for (final packageName in ['my_app', 'my_widgets']) {
          final packagePath = p.join(tempDir.path, 'packages', packageName);
          File(p.join(packagePath, 'bin', 'main.dart')).createSync(
            recursive: true,
          );
          File(
            p.join(packagePath, 'test', '${packageName}_test.dart'),
          ).createSync(recursive: true);
        }

        final workspaceBuilder = VirtualWorkspaceBuilder(
          path: tempDir.path,
          '''
          packages:
            - packages/my_app
            - packages/my_widgets
          ''',
        );
        for (final packageName in ['my_app', 'my_widgets']) {
          workspaceBuilder.addPackage(
            File(
              p.join(tempDir.path, 'packages', packageName, 'pubspec.yaml'),
            ).readAsStringSync(),
          );
        }
        final project = IntellijProject.fromWorkspace(workspaceBuilder.build());
        await project.generate();

        for (final fileName in [
          'melos_dart_run_my_app-main.xml',
          'melos_dart_run_my_widgets-main.xml',
          'melos_dart_test_my_app.xml',
          'melos_dart_test_my_widgets.xml',
        ]) {
          expect(
            File(
              p.join(project.runConfigurationsDir.path, fileName),
            ).existsSync(),
            isFalse,
            reason: '$fileName should not be generated',
          );
        }
      },
    );

    test(
      'generates a Dart test configuration for Dart packages with tests',
      () async {
        final tempDir = createTestTempDir();
        final project = await createDartProject(
          tempDir,
          packageName: 'my_lib',
          executableNames: [],
          withTests: true,
        );
        await project.generate();

        final testXml = readTextFile(
          p.join(
            project.runConfigurationsDir.path,
            'melos_dart_test_my_lib.xml',
          ),
        );
        expect(testXml, contains('type="DartTestRunConfigurationType"'));
        expect(testXml, contains("name=\"Dart Test -&gt; 'my_lib'\""));
        expect(
          testXml,
          contains(
            r'name="filePath" value="$PROJECT_DIR$/packages/my_lib/test"',
          ),
        );
        expect(testXml, contains('name="scope" value="FOLDER"'));
        expect(
          File(
            p.join(
              project.runConfigurationsDir.path,
              'melos_flutter_test_my_lib.xml',
            ),
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'warns when runArguments references a package that is not a Flutter app',
      () async {
        final tempDir = createTestTempDir();
        await createProject(
          tempDir,
          Pubspec('my_cli'),
          path: 'packages/my_cli',
        );
        final logger = TestLogger();
        final workspaceBuilder = VirtualWorkspaceBuilder(
          path: tempDir.path,
          logger: logger,
          '''
          packages:
            - packages/my_cli
          ide:
            intellij:
              runArguments:
                my_cli:
                  - name: verbose
                    args: "--verbose"
          ''',
        );
        workspaceBuilder.addPackage(
          File(
            p.join(tempDir.path, 'packages', 'my_cli', 'pubspec.yaml'),
          ).readAsStringSync(),
        );
        final project = IntellijProject.fromWorkspace(workspaceBuilder.build());
        await project.writeFlutterRunScripts();

        expect(
          logger.output,
          contains(
            'runArguments references package "my_cli" which is not a Flutter '
            'app, so it has no effect.',
          ),
        );
      },
    );
  });

  group('Melos script run configurations', () {
    test('uses the default script name prefix', () async {
      final tempDir = createTestTempDir();
      final workspaceBuilder =
          VirtualWorkspaceBuilder(
            path: tempDir.path,
            '''
        packages:
          - .
        scripts:
          format: dart format .
        ''',
          )..addPackage(
            '''
          name: root
          ''',
            path: '.',
          );
      final workspace = workspaceBuilder.build();
      final project = IntellijProject.fromWorkspace(workspace);
      await project.writeMelosScripts();

      final content = readTextFile(
        p.join(project.runConfigurationsDir.path, 'melos_run_format.xml'),
      );
      expect(content, contains("name=\"Melos Run -&gt; 'format'\""));
    });

    test('supports a custom script name prefix', () async {
      final tempDir = createTestTempDir();
      final workspaceBuilder =
          VirtualWorkspaceBuilder(
            path: tempDir.path,
            '''
        packages:
          - .
        ide:
          intellij:
            scriptNamePrefix: "Workspace -> "
        scripts:
          format: dart format .
        ''',
          )..addPackage(
            '''
          name: root
          ''',
            path: '.',
          );
      final workspace = workspaceBuilder.build();
      final project = IntellijProject.fromWorkspace(workspace);
      await project.writeMelosScripts();

      final content = readTextFile(
        p.join(project.runConfigurationsDir.path, 'melos_run_format.xml'),
      );
      expect(content, contains("name=\"Workspace -&gt; 'format'\""));
    });

    test('supports an empty script name prefix', () async {
      final tempDir = createTestTempDir();
      final workspaceBuilder =
          VirtualWorkspaceBuilder(
            path: tempDir.path,
            '''
        packages:
          - .
        ide:
          intellij:
            scriptNamePrefix: ""
        scripts:
          format: dart format .
        ''',
          )..addPackage(
            '''
          name: root
          ''',
            path: '.',
          );
      final workspace = workspaceBuilder.build();
      final project = IntellijProject.fromWorkspace(workspace);
      await project.writeMelosScripts();

      final content = readTextFile(
        p.join(project.runConfigurationsDir.path, 'melos_run_format.xml'),
      );
      expect(content, contains("name=\"'format'\""));
    });

    test(
      'keeps resolving melos from PATH via SCRIPT_TEXT when PUB_CACHE is set',
      withMockPlatform(
        () async {
          final tempDir = createTestTempDir();
          final workspaceBuilder =
              VirtualWorkspaceBuilder(
                path: tempDir.path,
                '''
        packages:
          - .
        scripts:
          format: dart format .
        ''',
              )..addPackage(
                '''
          name: root
          ''',
                path: '.',
              );
          final workspace = workspaceBuilder.build();
          final project = IntellijProject.fromWorkspace(workspace);
          await project.writeMelosScripts();

          final content = readTextFile(
            p.join(project.runConfigurationsDir.path, 'melos_run_format.xml'),
          );
          // A fixed path into PUB_CACHE would break for anyone not installing
          // melos there (see invertase/melos#789), so the run configuration
          // must keep resolving melos from PATH.
          expect(
            content,
            contains('name="SCRIPT_TEXT" value="melos run format"'),
          );
          expect(content, contains('name="EXECUTE_SCRIPT_FILE" value="false"'));
          expect(content, isNot(contains('/custom/.pub-cache')));
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: const {
            EnvironmentVariableKey.pubCache: '/custom/.pub-cache',
            'HOME': '/root',
          },
        ),
      ),
    );
  });

  group('getMelosBinForIde', () {
    test(
      'falls back to the default IntelliJ pub-cache path',
      withMockPlatform(
        () {
          final tempDir = createTestTempDir();
          final workspace = VirtualWorkspaceBuilder(
            path: tempDir.path,
            '''
        packages:
          - .
        ''',
          ).build();
          final project = IntellijProject.fromWorkspace(workspace);
          expect(
            project.getMelosBinForIde(),
            r'$USER_HOME$/.pub-cache/bin/melos',
          );
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: const {'HOME': '/root'},
        ),
      ),
    );
  });
}
