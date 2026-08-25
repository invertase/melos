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
     └> FAILED (in 1 packages)
        └> c (with exit code 1)
     └> CANCELED (in 2 packages)
        └> a (due to failFast)
        └> b (due to failFast)
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

        createDelayedExitFile(a, delay: 4000);

        final b = await createProject(
          workspaceDir,
          Pubspec('b'),
        );

        createDelayedExitFile(b, delay: 2000);

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

        // Packages run concurrently so any one may fail first on a given
        // platform. Assert structure without pinning which package fails.
        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            allOf([
              contains('''
\$ melos exec
  └> exit 2
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
${'-' * terminalWidth}

\$ melos exec
  └> exit 2
     └> FAILED (in 1 packages)'''),
              contains('(with exit code 2)'),
              contains('CANCELED (in 2 packages)'),
              contains('(due to failFast)'),
            ]),
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

          // b and e are in the same topological layer and run concurrently,
          // so their relative output order is non-deterministic.
          expect(
            logger.output.normalizeLines(),
            anyOf(
              ignoringAnsii(
                '''
\$ melos exec
  └> echo hello world
     └> RUNNING (in 5 packages)

${'-' * terminalWidth}
[d]: hello world
[c]: hello world
[b]: hello world
[e]: hello world
[a]: hello world
${'-' * terminalWidth}

\$ melos exec
  └> echo hello world
     └> SUCCESS
''',
              ),
              ignoringAnsii(
                '''
\$ melos exec
  └> echo hello world
     └> RUNNING (in 5 packages)

${'-' * terminalWidth}
[d]: hello world
[c]: hello world
[e]: hello world
[b]: hello world
[a]: hello world
${'-' * terminalWidth}

\$ melos exec
  └> echo hello world
     └> SUCCESS
''',
              ),
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
[d]: hello world
[e]: hello world
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

    group('group logs', () {
      /// Writes a script that prints two lines with a delay in between, so
      /// that the output of concurrently running packages would interleave if
      /// it was not buffered.
      void createLoggingFile(
        Directory dir, {
        required String package,
        int delay = 0,
        int exitCode = 0,
      }) {
        File('${dir.path}/log_lines.dart').writeAsStringSync('''
        import 'dart:io';
        Future<void> main() async {
          stdout.writeln('$package line 1');
          await Future.delayed(Duration(milliseconds: $delay));
          stdout.writeln('$package line 2');
          exit($exitCode);
        }
        ''');
      }

      test(
        'prints the output of each package grouped once all have finished',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c'],
          );

          final a = await createProject(workspaceDir, Pubspec('a'));
          createLoggingFile(a, package: 'a', delay: 600);

          final b = await createProject(workspaceDir, Pubspec('b'));
          createLoggingFile(b, package: 'b', delay: 300);

          final c = await createProject(workspaceDir, Pubspec('c'));
          createLoggingFile(c, package: 'c');

          final logger = TestLogger();
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);

          await melos.exec(
            ['dart', 'log_lines.dart'],
            concurrency: 3,
            groupLogs: true,
          );

          expect(
            logger.output.normalizeLines(),
            ignoringAnsii(
              '''
\$ melos exec
  └> dart log_lines.dart
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
a:
a line 1
a line 2
a: SUCCESS
${'-' * terminalWidth}
b:
b line 1
b line 2
b: SUCCESS
${'-' * terminalWidth}
c:
c line 1
c line 2
c: SUCCESS
${'-' * terminalWidth}

\$ melos exec
  └> dart log_lines.dart
     └> SUCCESS
''',
            ),
          );
        },
      );

      test('prints the output of failed packages last', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        final a = await createProject(workspaceDir, Pubspec('a'));
        createLoggingFile(a, package: 'a', delay: 600);

        final b = await createProject(workspaceDir, Pubspec('b'));
        createLoggingFile(b, package: 'b', exitCode: 1);

        final c = await createProject(workspaceDir, Pubspec('c'));
        createLoggingFile(c, package: 'c', delay: 300);

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(logger: logger, config: config);

        await melos.exec(
          ['dart', 'log_lines.dart'],
          concurrency: 3,
          groupLogs: true,
        );

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> dart log_lines.dart
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
a:
a line 1
a line 2
a: SUCCESS
${'-' * terminalWidth}
c:
c line 1
c line 2
c: SUCCESS
${'-' * terminalWidth}
b:
b line 1
b line 2
${'-' * terminalWidth}

\$ melos exec
  └> dart log_lines.dart
     └> FAILED (in 1 packages)
        └> b (with exit code 1)
''',
          ),
        );
      });

      test('is a no-op when running with a concurrency of 1', () async {
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

        await melos.exec(
          ['echo', 'hello', 'world'],
          concurrency: 1,
          groupLogs: true,
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

      // `--fail-fast` completes the packages it skips without running them,
      // so those packages never write anything to the group buffer. Flushing
      // the buffer must cope with that, even though the skipped packages are
      // reported as failures and therefore asked to be flushed last.
      //
      // The dependency chain (with `orderDependents`) is only there to make
      // the skipping deterministic: `b` runs and fails in the first layer, so
      // `c` and `a` are skipped in the layers after it.
      test('handles packages that were skipped by failFast', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        final a = await createProject(
          workspaceDir,
          Pubspec(
            'a',
            dependencies: {
              'c': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );
        createLoggingFile(a, package: 'a');

        final b = await createProject(workspaceDir, Pubspec('b'));
        createLoggingFile(b, package: 'b', exitCode: 1);

        final c = await createProject(
          workspaceDir,
          Pubspec(
            'c',
            dependencies: {
              'b': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );
        createLoggingFile(c, package: 'c');

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(logger: logger, config: config);

        await melos.exec(
          ['dart', 'log_lines.dart'],
          concurrency: 3,
          orderDependents: true,
          failFast: true,
          groupLogs: true,
        );

        // Only `b` ran, so only its output is flushed. `c` and `a` have no
        // buffered output at all, but are still listed as failures.
        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> dart log_lines.dart
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
b:
b line 1
b line 2
${'-' * terminalWidth}

\$ melos exec
  └> dart log_lines.dart
     └> FAILED (in 3 packages)
        └> b (with exit code 1)
        └> c (dependency failed)
        └> a (dependency failed)
''',
          ),
        );
      });

      test('groups the output of packages run in dependency order', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        // `a` depends on `b` and `c`, so `b` and `c` run concurrently in the
        // first layer and `a` runs on its own in the second one.
        final a = await createProject(
          workspaceDir,
          Pubspec(
            'a',
            dependencies: {
              'b': HostedDependency(version: VersionConstraint.any),
              'c': HostedDependency(version: VersionConstraint.any),
            },
          ),
        );
        createLoggingFile(a, package: 'a');

        final b = await createProject(workspaceDir, Pubspec('b'));
        createLoggingFile(b, package: 'b', delay: 300);

        final c = await createProject(workspaceDir, Pubspec('c'));
        createLoggingFile(c, package: 'c');

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(logger: logger, config: config);

        await melos.exec(
          ['dart', 'log_lines.dart'],
          concurrency: 3,
          orderDependents: true,
          groupLogs: true,
        );

        // The buffer is flushed once, after the last layer has finished, in
        // the order in which the packages started.
        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> dart log_lines.dart
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
b:
b line 1
b line 2
b: SUCCESS
${'-' * terminalWidth}
c:
c line 1
c line 2
c: SUCCESS
${'-' * terminalWidth}
a:
a line 1
a line 2
a: SUCCESS
${'-' * terminalWidth}

\$ melos exec
  └> dart log_lines.dart
     └> SUCCESS
''',
          ),
        );
      });
    });
  });
}
