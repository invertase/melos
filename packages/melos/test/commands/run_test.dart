import 'package:melos/melos.dart';
import 'package:melos/src/commands/runner.dart';
import 'package:melos/src/common/environment_variable_key.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../mock_env.dart';
import '../utils.dart';

void main() {
  group('script', () {
    test(
      'supports passing package filter options to "melos exec" scripts',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_package',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            scripts: Scripts({
              'test_script': Script(
                name: 'test_script',
                run: 'melos exec -- "echo hello"',
                packageFilters: PackageFilters(
                  fileExists: const ['log.txt'],
                ),
              ),
            }),
          ),
          workspacePackages: ['a', 'b'],
        );

        final aDir = await createProject(workspaceDir, Pubspec('a'));
        writeTextFile(p.join(aDir.path, 'log.txt'), '');

        await createProject(workspaceDir, Pubspec('b'));
        await runPubGet(workspaceDir.path);

        final logger = TestLogger();
        final config =
            await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.run(scriptName: 'test_script', noSelect: true);

        expect(
          logger.output.normalizeLines(),
          ignoringDependencyMessages(
            '''
melos run test_script
  └> melos exec -- "echo hello"
     └> RUNNING

\$ melos exec
  └> echo hello
     └> RUNNING (in 1 packages)

${'-' * terminalWidth}
a:
hello
a: SUCCESS
${'-' * terminalWidth}

\$ melos exec
  └> echo hello
     └> SUCCESS
''',
          ),
        );
      },
    );

    test(
      'merges filters from `packageFilters` and '
      '`${EnvironmentVariableKey.melosPackages}`',
      withMockPlatform(
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            configBuilder: (path) => MelosWorkspaceConfig(
              path: path,
              name: 'test_package',
              packages: [
                createGlob('packages/**', currentDirectoryPath: path),
              ],
              scripts: Scripts({
                'test_script': Script(
                  name: 'test_script',
                  run: 'melos exec -- "echo hello"',
                  packageFilters: PackageFilters(
                    fileExists: const ['log.txt'],
                  ),
                ),
              }),
            ),
            workspacePackages: ['a', 'b', 'c'],
          );

          final aDir = await createProject(workspaceDir, Pubspec('a'));
          writeTextFile(p.join(aDir.path, 'log.txt'), '');
          await createProject(workspaceDir, Pubspec('b'));
          final cDir = await createProject(workspaceDir, Pubspec('c'));
          writeTextFile(p.join(cDir.path, 'log.txt'), '');
          await runPubGet(workspaceDir.path);

          final logger = TestLogger();
          final config =
              await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
          final melos = Melos(
            logger: logger,
            config: config,
          );

          await melos.run(scriptName: 'test_script', noSelect: true);

          expect(
            logger.output.normalizeLines(),
            ignoringDependencyMessages(
              '''
melos run test_script
  └> melos exec -- "echo hello"
     └> RUNNING

\$ melos exec
  └> echo hello
     └> RUNNING (in 1 packages)

${'-' * terminalWidth}
c:
hello
c: SUCCESS
${'-' * terminalWidth}

\$ melos exec
  └> echo hello
     └> SUCCESS
''',
            ),
          );
        },
        platform: FakePlatform.fromPlatform(const LocalPlatform())
          ..environment[EnvironmentVariableKey.melosPackages] = 'b,c',
      ),
    );

    test('supports passing additional arguments to scripts', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello': Script(
              name: 'hello',
              run: 'echo',
            ),
          }),
        ),
        workspacePackages: [],
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(
        scriptName: 'hello',
        noSelect: true,
        extraArgs: [
          'foo',
          'bar',
          'baz',
        ],
      );

      expect(
        logger.output.normalizeLines(),
        ignoringDependencyMessages(
          '''
melos run hello
  └> echo foo bar baz
     └> RUNNING

foo bar baz
''',
        ),
      );
    });

    test('supports passing additional arguments to scripts (exec)', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello': Script(
              name: 'hello',
              run: 'echo',
              exec: ExecOptions(),
            ),
          }),
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(
        scriptName: 'hello',
        noSelect: true,
        extraArgs: [
          'foo',
          'bar',
          'baz',
        ],
      );

      expect(
        logger.output.normalizeLines(),
        ignoringDependencyMessages(
          '''
melos run hello
  └> melos exec -- "echo foo bar baz"
     └> RUNNING

\$ melos exec
  └> echo foo bar baz
     └> RUNNING (in 1 packages)

${'-' * terminalWidth}
a:
foo bar baz
a: SUCCESS
${'-' * terminalWidth}

\$ melos exec
  └> echo foo bar baz
     └> SUCCESS
''',
        ),
      );
    });

    test('supports running "melos exec" script with "exec" options', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'test_script': Script(
              name: 'test_script',
              run: 'echo "hello"',
              exec: ExecOptions(
                concurrency: 1,
              ),
            ),
          }),
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'test_script', noSelect: true);

      expect(
        logger.output.normalizeLines(),
        ignoringDependencyMessages(
          '''
melos run test_script
  └> melos exec --concurrency 1 -- "echo \\"hello\\""
     └> RUNNING

\$ melos exec
  └> echo "hello"
     └> RUNNING (in 1 packages)

${'-' * terminalWidth}
a:
${currentPlatform.isWindows ? '"hello"' : 'hello'}
a: SUCCESS
${'-' * terminalWidth}

\$ melos exec
  └> echo "hello"
     └> SUCCESS
''',
        ),
      );
    });

    test('throws an error if neither run, steps, nor exec are provided',
        () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'test_script': Script(
              name: 'test_script',
            ),
          }),
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      expect(() => melos.run(scriptName: 'test_script'), throwsException);
    });

    test(
        'throws an error if neither run or steps are provided, and exec '
        'are options', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'test_script': Script(
              name: 'test_script',
              exec: ExecOptions(),
            ),
          }),
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      expect(() => melos.run(scriptName: 'test_script'), throwsException);
    });
  });

  group('multiple scripts', () {
    test(
      '''
Verify that multiple script steps are executed sequentially in a persistent 
shell. When the script changes directory to "packages" and runs "ls -la", 
it should list the contents including the package named "this_is_package_a".
          ''',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_package',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            scripts: const Scripts({
              'cd_script': Script(
                name: 'cd_script',
                steps: ['cd packages', 'ls -la', 'pwd'],
              ),
            }),
          ),
          workspacePackages: ['this_is_package_a'],
        );

        await createProject(workspaceDir, Pubspec('this_is_package_a'));
        await runPubGet(workspaceDir.path);

        final logger = TestLogger();
        final config =
            await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.run(scriptName: 'cd_script', noSelect: true);

        expect(
          logger.output.normalizeLines(),
          contains('this_is_package_a'),
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
        'verifies that a melos script can successfully call another '
        'script as a step and execute commands', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              steps: ['test_script', 'echo "hello world"'],
            ),
            'test_script': Script(
              name: 'test_script',
              run: 'echo "test_script"',
            ),
          }),
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'hello_script', noSelect: true);

      expect(
        logger.output.normalizeLines(),
        ignoringDependencyMessages(
          '''
melos run hello_script
➡️ step: melos run test_script
melos run test_script
  └> echo "test_script"
     └> RUNNING

${currentPlatform.isWindows ? '"test_script"' : 'test_script'}

➡️ step: echo hello world
${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

SUCCESS
''',
        ),
      );
    });

    test(
        'throws an error if a script defined with steps also includes exec '
        'options', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              steps: ['test_script', 'echo "hello world"'],
              exec: ExecOptions(
                concurrency: 5,
              ),
            ),
            'test_script': Script(
              name: 'test_script',
              run: 'echo "test_script"',
            ),
          }),
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      expect(
        () => melos.run(scriptName: 'hello_script'),
        throwsException,
      );
    });

    test(
        'verifies that a melos script can call another script containing '
        'steps, and ensures all commands in those steps are executed '
        'successfully', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              steps: ['test_script', 'echo "hello world"'],
            ),
            'test_script': Script(
              name: 'test_script',
              steps: ['echo "test_script_1"', 'echo "test_script_2"'],
            ),
          }),
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'hello_script', noSelect: true);

      expect(
        logger.output.normalizeLines(),
        ignoringDependencyMessages(
          '''
melos run hello_script
➡️ step: melos run test_script
melos run test_script
➡️ step: echo test_script_1
${currentPlatform.isWindows ? '"test_script_1"' : 'test_script_1'}

➡️ step: echo test_script_2
${currentPlatform.isWindows ? '"test_script_2"' : 'test_script_2'}

SUCCESS

➡️ step: echo hello world
${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

SUCCESS
''',
        ),
      );
    });

    test(
        'verifies that a melos script can call another script containing '
        'melos commands, and ensures the script is successfully executed',
        () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              steps: ['format', 'echo "hello world"'],
            ),
          }),
        ),
        workspacePackages: ['a', 'b', 'c'],
      );

      final aDir = await createProject(workspaceDir, Pubspec('a'));
      await createProject(workspaceDir, Pubspec('b'));
      await createProject(workspaceDir, Pubspec('c'));
      await runPubGet(workspaceDir.path);

      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {
          for (var i = 0; i < 10; i++) {
            print('hello ${i + 1}');
          }
        }
      ''',
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'hello_script', noSelect: true);
      final normalizedLines = logger.output.normalizeLines().split('\n');
      expect(
        normalizedLines,
        containsAll(
          [
            r'$ melos format',
            '  └> dart format .',
            '     └> RUNNING (in 3 packages)',
            'a:',
            'Formatted main.dart',
            'a: SUCCESS',
            'b:',
            'b: SUCCESS',
            'c:',
            'c: SUCCESS',
          ],
        ),
      );
    });

    test(
        'verifies that a Melos script can call another script containing '
        'a script with a name equal to a melos command,  and ensures the '
        'script group successfully runs instead of the command', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              steps: ['list', 'echo "hello world"'],
            ),
            'list': Script(
              name: 'list script',
              run: 'echo "list script"',
            ),
          }),
        ),
        workspacePackages: ['a', 'b', 'c'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await createProject(workspaceDir, Pubspec('b'));
      await createProject(workspaceDir, Pubspec('c'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'hello_script', noSelect: true);

      expect(
        logger.output.normalizeLines(),
        ignoringDependencyMessages(
          '''
melos run hello_script
➡️ step: melos run list
melos run list
  └> echo "list script"
     └> RUNNING

${currentPlatform.isWindows ? '"list script"' : 'list script'}

➡️ step: echo hello world
${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

SUCCESS
''',
        ),
      );
    });

    test(
        'verifies that a script can call another script containing commands '
        'with flags, and ensures the first script is successfully executed, '
        'but terminates on failure.', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              steps: ['format --set-exit-if-changed', 'echo "hello world"'],
            ),
          }),
        ),
        workspacePackages: ['a', 'b', 'c'],
      );

      final aDir = await createProject(workspaceDir, Pubspec('a'));
      await createProject(workspaceDir, Pubspec('b'));
      await createProject(workspaceDir, Pubspec('c'));
      await runPubGet(workspaceDir.path);

      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {
          for (var i = 0; i < 10; i++) {
            print('hello ${i + 1}');
          }
        }
      ''',
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await expectLater(
        () => melos.run(scriptName: 'hello_script', noSelect: true),
        throwsA(const TypeMatcher<ScriptException>()),
      );

      final normalizedLines = logger.output.normalizeLines().split('\n');
      expect(
        normalizedLines,
        containsAll(
          [
            r'$ melos format',
            '  └> dart format --set-exit-if-changed .',
            '     └> RUNNING (in 3 packages)',
            'a:',
            'Formatted main.dart',
            'b:',
            'b: SUCCESS',
            'c:',
            'c: SUCCESS',
            r'$ melos format',
            '  └> dart format --set-exit-if-changed .',
            '     └> FAILED (in 1 packages)',
            '        └> a (with exit code 1)',
          ],
        ),
      );
      expect(
        normalizedLines,
        isNot(
          contains(currentPlatform.isWindows ? '"hello world"' : 'hello world'),
        ),
      ); // Ensure the script didn't run
    });

    test(
        'throw an error if correctly identifies when a script indirectly '
        'calls itself through another script, leading to a recursive call',
        () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              steps: ['test_script', 'echo "hello world"'],
            ),
            'test_script': Script(
              name: 'test_script',
              steps: ['echo "test_script_1"', 'hello_script'],
            ),
          }),
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      expect(
        () => melos.run(scriptName: 'hello_script', noSelect: true),
        throwsA(const TypeMatcher<RecursiveScriptCallException>()),
      );
    });
  });

  group('steps', () {
    test('failing step will result in early exit and error code 1', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'test_script': Script(
              name: 'test_script',
              steps: [
                'absolute_bogus_command',
                'echo "test_script_2"',
              ],
            ),
          }),
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await expectLater(
        () => melos.run(scriptName: 'test_script', noSelect: true),
        throwsA(const TypeMatcher<ScriptException>()),
      );

      expect(
        logger.output.normalizeLines().split('\n'),
        containsAllInOrder([
          'melos run test_script',
          '➡️ step: absolute_bogus_command',
          'e-ERROR: /bin/sh: 1: absolute_bogus_command: not found',
          'e-',
          'test_script',
          '  └> FAILED',
        ]),
      );
    });
  });
}
