import 'dart:io';

import 'package:glob/glob.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('exec', () {
    test('supports package filters', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a', 'b', 'c'],
      );

      final aDir = await createProject(
        workspaceDir,
        Pubspec('a'),
      );
      writeTextFile(p.join(aDir.path, 'log.txt'), '');

      final bDir = await createProject(
        workspaceDir,
        Pubspec('b'),
      );
      writeTextFile(p.join(bDir.path, 'log.txt'), '');

      await createProject(
        workspaceDir,
        Pubspec('c'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.exec(
        ['echo', 'hello', 'world'],
        concurrency: 1,
        packageFilters: PackageFilters(
          fileExists: const ['log.txt'],
        ),
      );

      expect(
        logger.output.normalizeLines(),
        ignoringAnsii(
          '''
\$ melos exec
  └> echo hello world
     └> RUNNING (in 2 packages)

${'-' * terminalWidth}
a:
hello world
a: SUCCESS
${'-' * terminalWidth}
b:
hello world
b: SUCCESS
${'-' * terminalWidth}

\$ melos exec
  └> echo hello world
     └> SUCCESS
''',
        ),
      );
    });

    group('concurrent processes', () {
      /// Use this file instead of running "exit 1" so the failure
      /// order is more predictable
      void createDelayedExitFile(
        Directory dir, {
        int delay = 0,
        int exitCode = 1,
      }) {
        File('${dir.path}/delayed_exit.dart').writeAsStringSync('''
        import 'dart:io';
        Future<void> main() async {
          await Future.delayed(Duration(milliseconds: $delay));
          exit($exitCode);
        }
        ''');
      }

      test('get cancel on first fail when fail fast is enabled', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        final a = await createProject(
          workspaceDir,
          Pubspec('a'),
        );

        createDelayedExitFile(a, delay: 1000);

        final b = await createProject(
          workspaceDir,
          Pubspec('b'),
        );

        createDelayedExitFile(b, delay: 500);

        final c = await createProject(
          workspaceDir,
          Pubspec('c'),
        );
        createDelayedExitFile(c);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['dart', 'delayed_exit.dart'],
          concurrency: 3,
          orderDependents: true,
          failFast: true,
        );

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> dart delayed_exit.dart
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
${'-' * terminalWidth}

\$ melos exec
  └> dart delayed_exit.dart
     └> FAILED (in 3 packages)
        └> c (with exit code 1)
        └> b (dependency failed)
        └> a (dependency failed)
''',
          ),
        );
      });

      test('keep running when fail fast is not enabled', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        final a = await createProject(
          workspaceDir,
          Pubspec('a'),
        );

        createDelayedExitFile(a, delay: 1000);

        final b = await createProject(
          workspaceDir,
          Pubspec('b'),
        );

        createDelayedExitFile(b, delay: 500);

        final c = await createProject(
          workspaceDir,
          Pubspec('c'),
        );
        createDelayedExitFile(c);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['dart', 'delayed_exit.dart'],
          concurrency: 3,
          orderDependents: true,
        );

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> dart delayed_exit.dart
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
${'-' * terminalWidth}

\$ melos exec
  └> dart delayed_exit.dart
     └> FAILED (in 3 packages)
        └> c (with exit code 1)
        └> b (with exit code 1)
        └> a (with exit code 1)
''',
          ),
        );
      });
    });

    group('fail fast', () {
      test('print error codes correctly', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        await createProject(
          workspaceDir,
          Pubspec('a'),
        );

        await createProject(
          workspaceDir,
          Pubspec('b'),
        );

        await createProject(
          workspaceDir,
          Pubspec('c'),
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['exit', '2'],
          failFast: true,
        );

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> exit 2
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
${'-' * terminalWidth}

\$ melos exec
  └> exit 2
     └> FAILED (in 1 packages)
        └> a (with exit code 2)
     └> CANCELED (in 2 packages)
        └> b (due to failFast)
        └> c (due to failFast)
''',
          ),
        );
      });

      test('propagate error code when fail fast is enabled', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        await createProject(
          workspaceDir,
          Pubspec('a'),
        );

        await createProject(
          workspaceDir,
          Pubspec('b'),
        );

        await createProject(
          workspaceDir,
          Pubspec('c'),
        );

        final result = await Process.run(
          'melos',
          ['exec', '--fail-fast', 'exit', '2'],
          workingDirectory: workspaceDir.path,
          runInShell: Platform.isWindows,
        );

        expect(result.exitCode, equals(2));
      });
    });

    group('order dependents', () {
      test('sorts execution order topologically', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        await createProject(
          workspaceDir,
          Pubspec(
            'a',
            dependencies: {
              'c': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );

        await createProject(
          workspaceDir,
          Pubspec('b'),
        );

        await createProject(
          workspaceDir,
          Pubspec(
            'c',
            dependencies: {
              'b': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['echo', 'hello', 'world'],
          concurrency: 2,
          orderDependents: true,
        );

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> echo hello world
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
[b]: hello world
[c]: hello world
[a]: hello world
${'-' * terminalWidth}

\$ melos exec
  └> echo hello world
     └> SUCCESS
''',
          ),
        );
      });

      test(
        'cancels execution if cyclic dependencies are found',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c'],
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'a',
              dependencies: {
                'b': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'b',
              dependencies: {
                'a': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec('c'),
          );

          final logger = TestLogger();
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(
            logger: logger,
            config: config,
          );

          await melos.exec(
            ['echo', 'hello', 'world'],
            concurrency: 2,
            orderDependents: true,
          );

          expect(
            logger.output.normalizeLines(),
            ignoringAnsii(
              '''
🚨 1 cycles in dependencies found:
[ b -> a ]
''',
            ),
          );
        },
      );

      test(
        'sorts execution order topologically with larger cyclic dependencies',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c', 'd', 'e'],
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'a',
              dependencies: {
                'b': HostedDependency(version: VersionConstraint.any),
                'c': HostedDependency(version: VersionConstraint.any),
                'd': HostedDependency(version: VersionConstraint.any),
                'e': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'b',
              dependencies: {
                'c': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'c',
              dependencies: {
                'd': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec('d'),
          );

          await createProject(
            workspaceDir,
            Pubspec('e'),
          );

          final logger = TestLogger();
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(
            logger: logger,
            config: config,
          );

          await melos.exec(
            ['echo', 'hello', 'world'],
            concurrency: 5,
            orderDependents: true,
          );

          expect(
            logger.output.normalizeLines(),
            ignoringAnsii(
              '''
\$ melos exec
  └> echo hello world
     └> RUNNING (in 5 packages)

${'-' * terminalWidth}
[e]: hello world
[d]: hello world
[c]: hello world
[b]: hello world
[a]: hello world
${'-' * terminalWidth}

\$ melos exec
  └> echo hello world
     └> SUCCESS
''',
            ),
          );
        },
      );

      test(
        'sorts order topologically but executes based on package filter',
        () async {
          const testCategoryName = 'ade';
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c', 'd', 'e'],
            configBuilder: (path) => MelosWorkspaceConfig(
              path: path,
              name: 'workspace',
              packages: const [],
              categories: {
                testCategoryName: [
                  Glob('packages/a'),
                  Glob('packages/d'),
                  Glob('packages/e'),
                ],
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'a',
              dependencies: {
                'b': HostedDependency(version: VersionConstraint.any),
                'c': HostedDependency(version: VersionConstraint.any),
                'd': HostedDependency(version: VersionConstraint.any),
                'e': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'b',
              dependencies: {
                'c': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'c',
              dependencies: {
                'd': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec('d'),
          );

          await createProject(
            workspaceDir,
            Pubspec('e'),
          );

          final logger = TestLogger();
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(
            logger: logger,
            config: config,
          );

          await melos.exec(
            ['echo', 'hello', 'world'],
            concurrency: 5,
            orderDependents: true,
            packageFilters: PackageFilters(
              categories: [Glob(testCategoryName)],
            ),
          );

          expect(
            logger.output.normalizeLines(),
            ignoringAnsii(
              '''
\$ melos exec
  └> echo hello world
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
[e]: hello world
[d]: hello world
[a]: hello world
${'-' * terminalWidth}

\$ melos exec
  └> echo hello world
     └> SUCCESS
''',
            ),
          );
        },
      );

      test('fails fast if dependencies fail', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        await createProject(
          workspaceDir,
          Pubspec(
            'a',
            dependencies: {
              'c': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );

        await createProject(
          workspaceDir,
          Pubspec('b'),
        );

        await createProject(
          workspaceDir,
          Pubspec(
            'c',
            dependencies: {
              'b': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['exit', '1'],
          concurrency: 3,
          orderDependents: true,
          failFast: true,
        );

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> exit 1
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
${'-' * terminalWidth}

\$ melos exec
  └> exit 1
     └> FAILED (in 3 packages)
        └> b (with exit code 1)
        └> c (dependency failed)
        └> a (dependency failed)
''',
          ),
        );
      });

      test(
        'does not fail fast if dependencies fail but failFast is false',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c'],
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'a',
              dependencies: {
                'c': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          await createProject(
            workspaceDir,
            Pubspec('b'),
          );

          await createProject(
            workspaceDir,
            Pubspec(
              'c',
              dependencies: {
                'b': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );

          final logger = TestLogger();
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(
            logger: logger,
            config: config,
          );

          await melos.exec(
            ['exit', '1'],
            concurrency: 3,
            orderDependents: true,
          );

          expect(
            logger.output.normalizeLines(),
            ignoringAnsii(
              '''
\$ melos exec
  └> exit 1
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
${'-' * terminalWidth}

\$ melos exec
  └> exit 1
     └> FAILED (in 3 packages)
        └> b (with exit code 1)
        └> c (with exit code 1)
        └> a (with exit code 1)
''',
            ),
          );
        },
      );

      test('does not fail fast if dependencies is not run', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        final aDir = await createProject(
          workspaceDir,
          Pubspec(
            'a',
            dependencies: {
              'c': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );
        writeTextFile(p.join(aDir.path, 'log.txt'), '');

        await createProject(
          workspaceDir,
          Pubspec('b'),
        );

        final cDir = await createProject(
          workspaceDir,
          Pubspec(
            'c',
            dependencies: {
              'b': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );
        writeTextFile(p.join(cDir.path, 'log.txt'), '');

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['echo', 'hello', 'world'],
          concurrency: 2,
          orderDependents: true,
          packageFilters: PackageFilters(
            fileExists: const ['log.txt'],
          ),
        );

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> echo hello world
     └> RUNNING (in 2 packages)

${'-' * terminalWidth}
[c]: hello world
[a]: hello world
${'-' * terminalWidth}

\$ melos exec
  └> echo hello world
     └> SUCCESS
''',
          ),
        );
      });
    });
  });
}
