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
            scripts: const Scripts({
              'test_script': Script(
                name: 'test_script',
                run: 'melos exec -- "echo hello"',
                packageFilters: PackageFilters(
                  fileExists: ['log.txt'],
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
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
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
              scripts: const Scripts({
                'test_script': Script(
                  name: 'test_script',
                  run: 'melos exec -- "echo hello"',
                  packageFilters: PackageFilters(
                    fileExists: ['log.txt'],
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
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
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

    test('expands `env` variables regardless of the platform shell', () async {
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
              run: r'echo $FOO',
              env: {'FOO': 'bar'},
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

      await melos.run(scriptName: 'hello', noSelect: true);

      expect(
        logger.output.normalizeLines(),
        ignoringDependencyMessages(
          r'''
melos run hello
  └> echo $FOO
     └> RUNNING

bar
''',
        ),
      );
    });

    test('keeps shell quoting semantics for `env` values (POSIX)', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            // Single quotes suppress expansion (escape hatch) and a value
            // containing shell metacharacters is treated as literal data
            // rather than being re-parsed by the shell.
            'literal': Script(
              name: 'literal',
              run: r"echo '$FOO' && echo $FOO",
              env: {'FOO': 'a && echo pwned'},
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

      await melos.run(scriptName: 'literal', noSelect: true);

      expect(
        logger.output.normalizeLines(),
        ignoringDependencyMessages(
          r'''
melos run literal
  └> echo '$FOO' && echo $FOO
     └> RUNNING

$FOO
a && echo pwned
''',
        ),
      );
    }, testOn: '!windows');

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

    test(
      'skips the packages with unchanged "sources" unless forced',
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
                run: 'echo run >> runs.txt',
                exec: ExecOptions(sources: ['lib/**.dart']),
              ),
            }),
          ),
          workspacePackages: ['a'],
        );

        final aDir = await createProject(workspaceDir, Pubspec('a'));
        writeTextFile(
          p.join(aDir.path, 'lib', 'source.dart'),
          '// a',
          recursive: true,
        );
        await runPubGet(workspaceDir.path);

        int runCount() => 'run'
            .allMatches(readTextFile(p.join(aDir.path, 'runs.txt')))
            .length;

        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(logger: TestLogger(), config: config);

        await melos.run(scriptName: 'test_script', noSelect: true);
        expect(runCount(), 1);

        await melos.run(scriptName: 'test_script', noSelect: true);
        expect(runCount(), 1);

        await melos.run(scriptName: 'test_script', noSelect: true, force: true);
        expect(runCount(), 2);
      },
    );

    test(
      'throws an error if neither run, steps, nor exec are provided',
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
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        expect(() => melos.run(scriptName: 'test_script'), throwsException);
      },
    );

    test('throws an error if neither run or steps are provided, and exec '
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

      await expectLater(
        MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir),
        throwsA(isA<MelosConfigException>()),
      );
    });

    group('command', () {
      test('uses "melos" by default for "exec" scripts', () {
        const script = Script(
          name: 'test_script',
          run: 'echo "hello"',
          exec: ExecOptions(),
        );

        expect(script.command(), ['melos', 'exec', '--', r'"echo \"hello\""']);
      });

      test('passes the sources of "exec" scripts to "melos exec"', () {
        const script = Script(
          name: 'test_script',
          run: 'echo hello',
          exec: ExecOptions(sources: ['lib/**.dart', 'pubspec.yaml']),
        );

        expect(script.command(), [
          'melos',
          'exec',
          '--sources',
          '"lib/**.dart"',
          '--sources',
          '"pubspec.yaml"',
          '--',
          '"echo hello"',
        ]);
      });

      test(
        'uses the provided melosCommand for "exec" scripts when Melos is '
        'installed locally',
        () {
          // Simulates a local installation, where Melos is not on the PATH and
          // must be invoked through the Dart SDK.
          // https://github.com/invertase/melos/issues/511
          const script = Script(
            name: 'test_script',
            run: 'echo "hello"',
            exec: ExecOptions(),
          );

          expect(
            script.command(melosCommand: const ['dart', 'run', 'melos:melos']),
            [
              'dart',
              'run',
              'melos:melos',
              'exec',
              '--',
              r'"echo \"hello\""',
            ],
          );
        },
      );

      // https://github.com/invertase/melos/issues/564
      group('references to the variables that are defined per package', () {
        const script = Script(
          name: 'test_script',
          run:
              r'echo $MELOS_ROOT_PATH $MELOS_PACKAGE_NAME '
              r'${MELOS_PARENT_PACKAGE_PATH} \$MELOS_PACKAGE_VERSION '
              r'$MELOS_PACKAGE_NAME_SUFFIX',
          exec: ExecOptions(),
        );

        test(
          'are left for the shell of "melos exec" to expand on POSIX',
          withMockPlatform(
            () {
              expect(
                script.command().last,
                [
                  r'"echo $MELOS_ROOT_PATH \$MELOS_PACKAGE_NAME',
                  r'\${MELOS_PARENT_PACKAGE_PATH} \$MELOS_PACKAGE_VERSION',
                  r'$MELOS_PACKAGE_NAME_SUFFIX"',
                ].join(' '),
              );
            },
            platform: FakePlatform(operatingSystem: 'linux'),
          ),
        );

        test(
          'are left untouched on Windows',
          withMockPlatform(
            () {
              expect(script.command().last, '"${script.run}"');
            },
            platform: FakePlatform(operatingSystem: 'windows'),
          ),
        );
      });
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
            scripts: Scripts({
              'cd_script': Script(
                name: 'cd_script',
                steps: [
                  'cd packages',
                  if (currentPlatform.isWindows) 'dir' else 'ls -la',
                  if (currentPlatform.isWindows) 'cd' else 'pwd',
                ],
              ),
            }),
          ),
          workspacePackages: ['this_is_package_a'],
        );

        await createProject(workspaceDir, Pubspec('this_is_package_a'));
        await runPubGet(workspaceDir.path);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
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

    test('expands `env` variables in steps regardless of the platform '
        'shell', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'env_script': Script(
              name: 'env_script',
              env: {'FOO': 'bar'},
              steps: [r'echo $FOO'],
            ),
          }),
        ),
        workspacePackages: [],
      );

      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'env_script', noSelect: true);

      expect(
        logger.output.normalizeLines(),
        contains('bar'),
      );
    });

    test('verifies that a melos script can successfully call another '
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
➡️  Step: melos run test_script --include-private
melos run test_script
  └> echo "test_script"
     └> RUNNING

${currentPlatform.isWindows ? '"test_script"' : 'test_script'}

➡️  Step: echo ${currentPlatform.isWindows ? '"hello world"' : 'hello world'}
${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

SUCCESS
''',
        ),
      );
    });

    test('throws an error if a script defined with steps also includes exec '
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

      await expectLater(
        MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir),
        throwsA(isA<MelosConfigException>()),
      );
    });

    test('verifies that a melos script can call another script containing '
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
➡️  Step: melos run test_script --include-private
melos run test_script
➡️  Step: echo ${currentPlatform.isWindows ? '"test_script_1"' : 'test_script_1'}
${currentPlatform.isWindows ? '"test_script_1"' : 'test_script_1'}

➡️  Step: echo ${currentPlatform.isWindows ? '"test_script_2"' : 'test_script_2'}
${currentPlatform.isWindows ? '"test_script_2"' : 'test_script_2'}

SUCCESS

➡️  Step: echo ${currentPlatform.isWindows ? '"hello world"' : 'hello world'}
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
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
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
      },
    );

    test('verifies that a Melos script can call another script containing '
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
➡️  Step: melos run list --include-private
melos run list
  └> echo "list script"
     └> RUNNING

${currentPlatform.isWindows ? '"list script"' : 'list script'}

➡️  Step: echo ${currentPlatform.isWindows ? '"hello world"' : 'hello world'}
${currentPlatform.isWindows ? '"hello world"' : 'hello world'}

SUCCESS
''',
        ),
      );
    });

    test('verifies that a script can call another script containing commands '
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
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        expect(
          () => melos.run(scriptName: 'hello_script', noSelect: true),
          throwsA(const TypeMatcher<RecursiveScriptCallException>()),
        );
      },
    );
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
          '➡️  Step: absolute_bogus_command',
          if (currentPlatform.isLinux)
            'e-ERROR: /bin/sh: 1: absolute_bogus_command: not found',
          if (currentPlatform.isMacOS)
            'e-ERROR: /bin/sh: line 1: absolute_bogus_command: command not found',
          'e-',
          'test_script',
          '  └> FAILED',
        ]),
      );
    });
  });

  group('dependsOn', () {
    Future<Melos> createMelos(TestLogger logger, Scripts scripts) async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: scripts,
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      return Melos(logger: logger, config: config);
    }

    test(
      'runs the scripts that a script depends on first, each of them once',
      () async {
        final logger = TestLogger();
        final melos = await createMelos(
          logger,
          const Scripts({
            'generate': Script(name: 'generate', run: 'echo ran_generate'),
            'build': Script(
              name: 'build',
              run: 'echo ran_build',
              dependsOn: ['generate'],
            ),
            'check': Script(
              name: 'check',
              steps: ['echo ran_check'],
              dependsOn: ['generate'],
              isPrivate: true,
            ),
            'verify': Script(
              name: 'verify',
              run: 'echo ran_verify',
              dependsOn: ['build', 'check'],
            ),
          }),
        );

        await melos.run(
          scriptName: 'verify',
          noSelect: true,
          extraArgs: ['extra_argument'],
        );

        final lines = logger.output.normalizeLines().split('\n');
        expect(
          lines,
          containsAllInOrder([
            'melos run generate',
            'ran_generate',
            'melos run build',
            'ran_build',
            'melos run check',
            'ran_check',
            'melos run verify',
            'ran_verify extra_argument',
          ]),
        );
        expect(lines.where((line) => line == 'ran_generate'), hasLength(1));
        expect(lines, isNot(contains('ran_build extra_argument')));
      },
    );

    test(
      'does not run a script if a script that it depends on fails',
      () async {
        final logger = TestLogger();
        final melos = await createMelos(
          logger,
          const Scripts({
            'failing': Script(name: 'failing', run: 'absolute_bogus_command'),
            'test_script': Script(
              name: 'test_script',
              run: 'echo ran_test_script',
              dependsOn: ['failing'],
            ),
          }),
        );

        await expectLater(
          () => melos.run(scriptName: 'test_script', noSelect: true),
          throwsA(
            isA<ScriptException>().having(
              (exception) => exception.scriptName,
              'scriptName',
              'failing',
            ),
          ),
        );

        expect(
          logger.output.normalizeLines().split('\n'),
          isNot(contains('ran_test_script')),
        );
      },
    );

    test('supports a script that only consists of dependsOn', () async {
      final logger = TestLogger();
      final melos = await createMelos(
        logger,
        const Scripts({
          'first': Script(name: 'first', run: 'echo ran_first'),
          'second': Script(name: 'second', run: 'echo ran_second'),
          'all': Script(name: 'all', dependsOn: ['first', 'second']),
        }),
      );

      await melos.run(scriptName: 'all', noSelect: true);

      expect(
        logger.output.normalizeLines().split('\n'),
        containsAllInOrder([
          'ran_first',
          'ran_second',
          'melos run all',
          'SUCCESS',
        ]),
      );
    });

    test(
      'reports a script without a command before any of the scripts run',
      () async {
        final logger = TestLogger();
        final melos = await createMelos(
          logger,
          const Scripts({
            'first': Script(name: 'first', run: 'echo ran_first'),
            'broken': Script(name: 'broken'),
            'all': Script(name: 'all', dependsOn: ['first', 'broken']),
          }),
        );

        await expectLater(
          () => melos.run(scriptName: 'all', noSelect: true),
          throwsA(isA<MissingScriptCommandException>()),
        );

        expect(
          logger.output.normalizeLines().split('\n'),
          isNot(contains('ran_first')),
        );
      },
    );

    test(
      'skips a script that is depended on if no package matches its filters',
      () async {
        final logger = TestLogger();
        final melos = await createMelos(
          logger,
          const Scripts({
            'generate': Script(
              name: 'generate',
              run: 'echo ran_generate',
              exec: ExecOptions(),
              packageFilters: PackageFilters(fileExists: ['build.yaml']),
            ),
            'test_script': Script(
              name: 'test_script',
              run: 'echo ran_test_script',
              dependsOn: ['generate'],
            ),
          }),
        );

        await melos.run(scriptName: 'test_script', noSelect: true);

        final lines = logger.output.normalizeLines().split('\n');
        expect(lines, contains('ran_test_script'));
        expect(lines, isNot(contains('ran_generate')));
        expect(
          logger.output.normalizeLines(),
          contains('Skipping the script generate'),
        );
      },
    );

    test(
      'throws an error if a script is called recursively through a mix of '
      'dependsOn and steps',
      () async {
        final logger = TestLogger();
        final melos = await createMelos(
          logger,
          const Scripts({
            'hello_script': Script(
              name: 'hello_script',
              run: 'echo hello',
              dependsOn: ['test_script'],
            ),
            'test_script': Script(
              name: 'test_script',
              steps: ['echo "test_script_1"', 'hello_script'],
            ),
          }),
        );

        expect(
          () => melos.run(scriptName: 'hello_script', noSelect: true),
          throwsA(const TypeMatcher<RecursiveScriptCallException>()),
        );
      },
    );
  });

  group('quiet', () {
    Future<(Melos, TestLogger)> createQuietMelos(Scripts scripts) async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: scripts,
        ),
        workspacePackages: ['a'],
      );

      await createProject(workspaceDir, Pubspec('a'));
      await runPubGet(workspaceDir.path);

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: MelosLogger(logger, isQuiet: true),
        config: config,
      );

      return (melos, logger);
    }

    test('prints nothing when the script succeeds', () async {
      final (melos, logger) = await createQuietMelos(
        const Scripts({
          'test_script': Script(name: 'test_script', run: 'echo "hello"'),
        }),
      );

      await melos.run(scriptName: 'test_script', noSelect: true);

      expect(logger.output, isEmpty);
    });

    test('prints the output of the script when it fails', () async {
      final (melos, logger) = await createQuietMelos(
        const Scripts({
          'test_script': Script(
            name: 'test_script',
            run: 'echo hello && exit 1',
          ),
        }),
      );

      await expectLater(
        () => melos.run(scriptName: 'test_script', noSelect: true),
        throwsA(const TypeMatcher<ScriptException>()),
      );

      expect(
        logger.output
            .normalizeLines()
            .split('\n')
            .map((line) => line.trimRight()),
        ['hello', '', 'test_script', '  └> FAILED', ''],
      );
    });

    test('only prints the output of the step that fails', () async {
      final (melos, logger) = await createQuietMelos(
        const Scripts({
          'test_script': Script(
            name: 'test_script',
            steps: ['echo first', 'echo second && absolute_bogus_command'],
          ),
        }),
      );

      await expectLater(
        () => melos.run(scriptName: 'test_script', noSelect: true),
        throwsA(const TypeMatcher<ScriptException>()),
      );

      final output = logger.output.normalizeLines();
      expect(output, isNot(contains('first')));
      expect(
        output.split('\n').map((line) => line.trimRight()),
        containsAllInOrder(['second', 'test_script', '  └> FAILED']),
      );
    });

    test('makes nested Melos commands quiet', () async {
      final (melos, logger) = await createQuietMelos(
        const Scripts({
          'test_script': Script(
            name: 'test_script',
            run:
                'echo "quiet=\$${EnvironmentVariableKey.melosQuiet}" '
                '&& exit 1',
          ),
        }),
      );

      await expectLater(
        () => melos.run(scriptName: 'test_script', noSelect: true),
        throwsA(const TypeMatcher<ScriptException>()),
      );

      expect(logger.output.normalizeLines(), contains('quiet=true'));
    }, skip: currentPlatform.isWindows);
  });

  group('flags', () {
    test(
      'verifies that the --list flag lists all scripts in the config',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_package',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            scripts: const Scripts({
              'test_script_1': Script(
                name: 'test_script',
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_2': Script(
                name: 'test_script',
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_3': Script(
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

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.run(listScripts: true);

        expect(
          logger.output.normalizeLines().split('\n'),
          containsAllInOrder([
            'melos run --list',
            '',
            'test_script_1',
            'test_script_2',
            'test_script_3',
          ]),
        );
      },
    );

    test(
      'verifies that the --list flag in combination with '
      '--json lists all scripts in the config in json format',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_package',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            scripts: const Scripts({
              'test_script_1': Script(
                name: 'test_script',
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_2': Script(
                name: 'test_script',
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_3': Script(
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

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.run(listScripts: true, listScriptsAsJson: true);

        expect(
          logger.output.normalizeLines().split('\n'),
          containsAllInOrder([
            'melos run --list --json',
            '',
            r'{"test_script_1":{"name":"test_script_1","run":null,"steps":["absolute_bogus_command","echo \"test_script_2\""],"private":false,"groups":[]},"test_script_2":{"name":"test_script_2","run":null,"steps":["absolute_bogus_command","echo \"test_script_2\""],"private":false,"groups":[]},"test_script_3":{"name":"test_script_3","run":null,"steps":["absolute_bogus_command","echo \"test_script_2\""],"private":false,"groups":[]}}',
          ]),
        );
      },
    );

    test(
      'verifies that the --groups option hides all scripts '
      'not belonging to the specified group',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_package',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            scripts: const Scripts({
              'test_script_1': Script(
                name: 'test_script',
                groups: ['group_1', 'group_2'],
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_2': Script(
                name: 'test_script',
                groups: ['group_2'],
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_3': Script(
                name: 'test_script',
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_3"',
                ],
              ),
              'test_script_4': Script(
                name: 'test_script',
                groups: ['group_3'],
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_4"',
                ],
              ),
            }),
          ),
          workspacePackages: ['a'],
        );

        await createProject(workspaceDir, Pubspec('a'));

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.run(group: 'group_2', listScripts: true);

        expect(
          logger.output.normalizeLines().split('\n'),
          containsAllInOrder([
            'melos run --group group_2 --list',
            '',
            'test_script_1',
            'test_script_2',
          ]),
        );
      },
    );

    test(
      'verifies that the --groups option hides all scripts '
      'and hidden scripts cannot be executed',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_package',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            scripts: const Scripts({
              'test_script_1': Script(
                name: 'test_script',
                groups: ['group_1', 'group_2'],
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_2': Script(
                name: 'test_script',
                groups: ['group_2'],
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_3': Script(
                name: 'test_script',
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_3"',
                ],
              ),
              'test_script_4': Script(
                name: 'test_script',
                groups: ['group_3'],
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_4"',
                ],
              ),
            }),
          ),
          workspacePackages: ['a'],
        );

        await createProject(workspaceDir, Pubspec('a'));

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        expect(
          () => melos.run(group: 'group_2', scriptName: 'test_script_3'),
          throwsA(isA<ScriptNotFoundException>()),
        );
      },
    );

    test(
      'explains that "x-" keys are not scripts when one is run',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_package',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            scripts: const Scripts({
              'a': Script(name: 'a', run: 'echo a'),
            }),
          ),
          workspacePackages: ['a'],
        );

        await createProject(workspaceDir, Pubspec('a'));

        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(logger: TestLogger(), config: config);

        expect(
          () => melos.run(scriptName: 'x-analyze'),
          throwsA(
            isA<ScriptNotFoundException>().having(
              (exception) => exception.toString(),
              'toString()',
              contains('extension fields for YAML anchors'),
            ),
          ),
        );
      },
    );

    test(
      'verifies that the --groups option shows an error '
      'if the specified group is empty',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_package',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            scripts: const Scripts({
              'test_script_1': Script(
                name: 'test_script',
                groups: ['group_1', 'group_2'],
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_2': Script(
                name: 'test_script',
                groups: ['group_2'],
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_2"',
                ],
              ),
              'test_script_3': Script(
                name: 'test_script',
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_3"',
                ],
              ),
              'test_script_4': Script(
                name: 'test_script',
                groups: ['group_3'],
                steps: [
                  'absolute_bogus_command',
                  'echo "test_script_4"',
                ],
              ),
            }),
          ),
          workspacePackages: ['a'],
        );

        await createProject(workspaceDir, Pubspec('a'));

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        expect(
          () => melos.run(group: 'group_42'),
          throwsA(isA<EmptyGroupException>()),
        );
      },
    );
  });

  group('CLI package filters', () {
    test(
      'CLI --scope overrides script-defined packageFilters scope',
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
                  scope: [
                    createGlob('a', currentDirectoryPath: path),
                  ],
                ),
              ),
            }),
          ),
          workspacePackages: ['a', 'b'],
        );

        await createProject(workspaceDir, Pubspec('a'));
        await createProject(workspaceDir, Pubspec('b'));
        await runPubGet(workspaceDir.path);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        // CLI --scope=b should override script's scope of 'a'
        await melos.run(
          scriptName: 'test_script',
          noSelect: true,
          packageFilters: PackageFilters(
            scope: [
              createGlob('b', currentDirectoryPath: workspaceDir.path),
            ],
          ),
        );

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
b:
hello
b: SUCCESS
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
      'CLI --flutter is combined with script-defined packageFilters',
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
                  scope: [createGlob('a', currentDirectoryPath: path)],
                ),
              ),
            }),
          ),
          workspacePackages: ['a'],
        );
        await createProject(workspaceDir, Pubspec('a'));

        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(logger: TestLogger(), config: config);

        await expectLater(
          melos.run(
            scriptName: 'test_script',
            noSelect: true,
            packageFilters: const PackageFilters(flutter: true),
          ),
          throwsA(isA<NoPackageFoundScriptException>()),
        );
      },
    );

    test(
      'CLI --scope applies to script without packageFilters',
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
                run: 'melos exec -- "echo hello"',
              ),
            }),
          ),
          workspacePackages: ['a', 'b'],
        );

        await createProject(workspaceDir, Pubspec('a'));
        await createProject(workspaceDir, Pubspec('b'));
        await runPubGet(workspaceDir.path);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        // CLI --scope=a should filter to only package 'a'
        await melos.run(
          scriptName: 'test_script',
          noSelect: true,
          packageFilters: PackageFilters(
            scope: [
              createGlob('a', currentDirectoryPath: workspaceDir.path),
            ],
          ),
        );

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
      'CLI --scope preserves script-defined non-scope filters',
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
                run: 'melos exec -- "echo hello"',
                packageFilters: PackageFilters(
                  fileExists: ['log.txt'],
                ),
              ),
            }),
          ),
          workspacePackages: ['a', 'b', 'c'],
        );

        // 'a' has log.txt, 'b' has log.txt, 'c' does not
        final aDir = await createProject(workspaceDir, Pubspec('a'));
        writeTextFile(p.join(aDir.path, 'log.txt'), '');
        final bDir = await createProject(workspaceDir, Pubspec('b'));
        writeTextFile(p.join(bDir.path, 'log.txt'), '');
        await createProject(workspaceDir, Pubspec('c'));
        await runPubGet(workspaceDir.path);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        // CLI --scope=a,b should combine with script's fileExists filter.
        // Only 'a' matches both scope and fileExists (b also matches both).
        // But we scope to just 'a'.
        await melos.run(
          scriptName: 'test_script',
          noSelect: true,
          packageFilters: PackageFilters(
            scope: [
              createGlob('a', currentDirectoryPath: workspaceDir.path),
            ],
          ),
        );

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
      'CLI --scope overrides script-defined scope',
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
                  scope: [
                    createGlob('b', currentDirectoryPath: path),
                  ],
                ),
              ),
            }),
          ),
          workspacePackages: ['a', 'b'],
        );

        await createProject(workspaceDir, Pubspec('a'));
        await createProject(workspaceDir, Pubspec('b'));
        await runPubGet(workspaceDir.path);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        // CLI --scope=a should override script's scope=b
        await melos.run(
          scriptName: 'test_script',
          noSelect: true,
          packageFilters: PackageFilters(
            scope: [
              createGlob('a', currentDirectoryPath: workspaceDir.path),
            ],
          ),
        );

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
  });

  group('config', () {
    test(
      'noSelect skips the package selection prompt for filtered scripts',
      () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_package',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            commands: const CommandConfigs(
              run: RunCommandConfigs(noSelect: true),
            ),
            scripts: Scripts({
              'test_script': Script(
                name: 'test_script',
                run: 'melos exec -- "echo hello"',
                packageFilters: PackageFilters(
                  scope: [
                    createGlob('*', currentDirectoryPath: path),
                  ],
                ),
              ),
            }),
          ),
          workspacePackages: ['a', 'b'],
        );

        await createProject(workspaceDir, Pubspec('a'));
        await createProject(workspaceDir, Pubspec('b'));
        await runPubGet(workspaceDir.path);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );

        await Melos(logger: logger, config: config).run(
          scriptName: 'test_script',
        );

        expect(
          logger.output.normalizeLines(),
          isNot(contains('Select a package to run')),
        );
        expect(
          logger.output.normalizeLines(),
          contains('RUNNING (in 2 packages)'),
        );
      },
    );

    test(
      'CLI --post-filter is applied after the script-defined '
      'includeDependencies',
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
                  scope: [
                    createGlob('a', currentDirectoryPath: path),
                  ],
                  includeDependencies: true,
                ),
              ),
            }),
          ),
          workspacePackages: ['a', 'b'],
        );

        await createProject(
          workspaceDir,
          Pubspec('a', dependencies: {'b': HostedDependency()}),
        );
        await createProject(workspaceDir, Pubspec('b'));
        await runPubGet(workspaceDir.path);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );

        await Melos(logger: logger, config: config).run(
          scriptName: 'test_script',
          noSelect: true,
          packageFilters: const PackageFilters(
            postFilters: PackageFilters(noDependsOn: ['b']),
          ),
        );

        expect(
          logger.output.normalizeLines(),
          contains('RUNNING (in 1 packages)'),
        );
        expect(logger.output.normalizeLines(), contains('b: SUCCESS'));
      },
    );
  });
}
