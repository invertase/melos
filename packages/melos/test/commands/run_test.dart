import 'package:melos/melos.dart';
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
  });
}
