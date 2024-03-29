import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/commands/runner.dart';
import 'package:melos/src/common/environment_variable_key.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:pubspec/pubspec.dart';
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
          runPubGet: true,
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
        );

        final aDir = await createProject(
          workspaceDir,
          const PubSpec(name: 'a'),
        );
        writeTextFile(p.join(aDir.path, 'log.txt'), '');

        await createProject(
          workspaceDir,
          const PubSpec(name: 'b'),
        );

        final logger = TestLogger();
        final config =
            await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.run(scriptName: 'test_script', noSelect: true);

        expect(
          logger.output.normalizeNewLines(),
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

melos run test_script
  └> melos exec -- "echo hello"
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
            runPubGet: true,
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
          );

          final aDir = await createProject(
            workspaceDir,
            const PubSpec(name: 'a'),
          );
          writeTextFile(p.join(aDir.path, 'log.txt'), '');

          await createProject(
            workspaceDir,
            const PubSpec(name: 'b'),
          );

          final cDir = await createProject(
            workspaceDir,
            const PubSpec(name: 'c'),
          );
          writeTextFile(p.join(cDir.path, 'log.txt'), '');

          final logger = TestLogger();
          final config =
              await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
          final melos = Melos(
            logger: logger,
            config: config,
          );

          await melos.run(scriptName: 'test_script', noSelect: true);

          expect(
            logger.output.normalizeNewLines(),
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

melos run test_script
  └> melos exec -- "echo hello"
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
        runPubGet: true,
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
        logger.output.normalizeNewLines(),
        ignoringDependencyMessages(
          '''
melos run hello
  └> echo foo bar baz
     └> RUNNING

foo bar baz

melos run hello
  └> echo foo bar baz
     └> SUCCESS
''',
        ),
      );
    });

    test('supports passing additional arguments to scripts (exec)', () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
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
      );

      await createProject(workspaceDir, const PubSpec(name: 'a'));

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
        logger.output.normalizeNewLines(),
        ignoringDependencyMessages(
          r'''
melos run hello
  └> melos exec -- "echo foo bar baz"
     └> RUNNING

$ melos exec
  └> echo foo bar baz
     └> RUNNING (in 1 packages)

--------------------------------------------------------------------------------
a:
foo bar baz
a: SUCCESS
--------------------------------------------------------------------------------

$ melos exec
  └> echo foo bar baz
     └> SUCCESS

melos run hello
  └> melos exec -- "echo foo bar baz"
     └> SUCCESS
''',
        ),
      );
    });

    test('supports running "melos exec" script with "exec" options', () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
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
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'test_script', noSelect: true);

      expect(
        logger.output.normalizeNewLines(),
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

melos run test_script
  └> melos exec --concurrency 1 -- "echo \\"hello\\""
     └> SUCCESS
''',
        ),
      );
    });

    test('throws an error if neither run, steps, nor exec are provided',
        () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
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
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

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
        runPubGet: true,
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
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

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
    late Directory aDir;

    test(
        'verifies that a melos script can successfully call another '
        'script as a step and execute commands', () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
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
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'hello_script', noSelect: true);

      expect(
        logger.output.normalizeNewLines(),
        ignoringDependencyMessages(
          '''
melos run hello_script
  └> test_script
     └> RUNNING

melos run test_script
  └> echo "test_script"
     └> RUNNING

${currentPlatform.isWindows ? '"test_script"' : 'test_script'}

melos run test_script
  └> echo "test_script"
     └> SUCCESS

melos run hello_script
  └> test_script
     └> SUCCESS

melos run hello_script
  └> echo "hello world"
     └> RUNNING

${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

melos run hello_script
  └> echo "hello world"
     └> SUCCESS

''',
        ),
      );
    });

    test(
        'throws an error if a script defined with steps also includes exec '
        'options', () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
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
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

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
        runPubGet: true,
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
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'hello_script', noSelect: true);

      expect(
        logger.output.normalizeNewLines(),
        ignoringDependencyMessages(
          '''
melos run hello_script
  └> test_script
     └> RUNNING

melos run test_script
  └> echo "test_script_1"
     └> RUNNING

${currentPlatform.isWindows ? '"test_script_1"' : 'test_script_1'}

melos run test_script
  └> echo "test_script_1"
     └> SUCCESS

melos run test_script
  └> echo "test_script_2"
     └> RUNNING

${currentPlatform.isWindows ? '"test_script_2"' : 'test_script_2'}

melos run test_script
  └> echo "test_script_2"
     └> SUCCESS


melos run hello_script
  └> test_script
     └> SUCCESS

melos run hello_script
  └> echo "hello world"
     └> RUNNING

${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

melos run hello_script
  └> echo "hello world"
     └> SUCCESS

''',
        ),
      );
    });

    test(
        'verifies that a melos script can call another script containing '
        'melos commands, and ensures the script is successfully executed',
        () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              steps: ['analyze', 'echo "hello world"'],
            ),
          }),
        ),
      );

      aDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );

      await createProject(
        workspaceDir,
        const PubSpec(
          name: 'c',
        ),
      );

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

      expect(
        logger.output.normalizeNewLines(),
        ignoringDependencyMessages(
          '''
melos run hello_script
  └> analyze
     └> RUNNING

\$ melos analyze
  └> dart analyze 
     └> RUNNING (in 3 packages)

--------------------------------------------------------------------------------
a:
Analyzing a...

   info - main.dart:3:13 - Don't invoke 'print' in production code. Try using a logging framework. - avoid_print
   info - main.dart:5:10 - Missing a newline at the end of the file. Try adding a newline at the end of the file. - eol_at_end_of_file

2 issues found.
a: SUCCESS
--------------------------------------------------------------------------------
b:
Analyzing b...
No issues found!
b: SUCCESS
--------------------------------------------------------------------------------
c:
Analyzing c...
No issues found!
c: SUCCESS
--------------------------------------------------------------------------------

\$ melos analyze
  └> dart analyze 
     └> SUCCESS

melos run hello_script
  └> analyze
     └> SUCCESS

melos run hello_script
  └> echo "hello world"
     └> RUNNING

${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

melos run hello_script
  └> echo "hello world"
     └> SUCCESS

''',
        ),
      );
    });

    test(
        'verifies that a Melos script can call another script containing '
        'a script with a name equal to a melos command,  and ensures the '
        'script group successfully runs instead of the command', () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
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
      );

      aDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );

      await createProject(
        workspaceDir,
        const PubSpec(
          name: 'c',
        ),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'hello_script', noSelect: true);

      expect(
        logger.output.normalizeNewLines(),
        ignoringDependencyMessages(
          '''
melos run hello_script
  └> list
     └> RUNNING

melos run list
  └> echo "list script"
     └> RUNNING

${currentPlatform.isWindows ? '"list script"' : 'list script'}

melos run list
  └> echo "list script"
     └> SUCCESS

melos run hello_script
  └> list
     └> SUCCESS

melos run hello_script
  └> echo "hello world"
     └> RUNNING

${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

melos run hello_script
  └> echo "hello world"
     └> SUCCESS

''',
        ),
      );
    });

    test(
        'verifies that a melos script can call another script containing '
        'melos commands with flags, and ensures the script is successfully '
        'executed', () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              steps: ['analyze --fatal-infos', 'echo "hello world"'],
            ),
          }),
        ),
      );

      aDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );

      await createProject(
        workspaceDir,
        const PubSpec(
          name: 'c',
        ),
      );

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

      expect(
        logger.output.normalizeNewLines(),
        ignoringDependencyMessages(
          '''
melos run hello_script
  └> analyze --fatal-infos
     └> RUNNING

\$ melos analyze
  └> dart analyze --fatal-infos
     └> RUNNING (in 3 packages)

--------------------------------------------------------------------------------
a:
Analyzing a...

   info - main.dart:3:13 - Don't invoke 'print' in production code. Try using a logging framework. - avoid_print
   info - main.dart:5:10 - Missing a newline at the end of the file. Try adding a newline at the end of the file. - eol_at_end_of_file

2 issues found.
--------------------------------------------------------------------------------
b:
Analyzing b...
No issues found!
b: SUCCESS
--------------------------------------------------------------------------------
c:
Analyzing c...
No issues found!
c: SUCCESS
--------------------------------------------------------------------------------

\$ melos analyze
  └> dart analyze --fatal-infos
     └> FAILED (in 1 packages)
        └> a (with exit code 1)

melos run hello_script
  └> analyze --fatal-infos
     └> FAILED

melos run hello_script
  └> echo "hello world"
     └> RUNNING

${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

melos run hello_script
  └> echo "hello world"
     └> SUCCESS

''',
        ),
      );
    });

    test(
        'throw an error if correctly identifies when a script indirectly '
        'calls itself through another script, leading to a recursive call',
        () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
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
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );

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
}
