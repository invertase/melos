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
          ignoringAnsii(
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
            ignoringAnsii(
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
        ignoringAnsii(
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
        ignoringAnsii(
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
        ignoringAnsii(
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
        ignoringAnsii(
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
        ignoringAnsii(
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
