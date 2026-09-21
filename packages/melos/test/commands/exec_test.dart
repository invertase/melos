import 'dart:io';

import 'package:glob/glob.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/common/fingerprint.dart';
import 'package:melos/src/common/glob.dart';
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
        packageFilters: const PackageFilters(
          fileExists: ['log.txt'],
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

    group('no tests ran', () {
      test('treats the no tests ran exit code as a success', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a'],
        );

        await createProject(
          workspaceDir,
          Pubspec('a'),
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: logger,
          config: config,
        );

        final previousExitCode = exitCode;
        await melos.exec(
          ['exit', '79'],
          concurrency: 1,
          failFast: true,
        );

        expect(exitCode, previousExitCode);
        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            allOf([
              contains('a: SUCCESS (no tests ran)'),
              contains(r'''
$ melos exec
  └> exit 79
     └> SUCCESS'''),
              isNot(contains('FAILED')),
            ]),
          ),
        );
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
          packageFilters: const PackageFilters(
            fileExists: ['log.txt'],
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

      test('only prints the output of failed packages when quiet', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b', 'c'],
        );

        final a = await createProject(workspaceDir, Pubspec('a'));
        createLoggingFile(a, package: 'a');

        final b = await createProject(workspaceDir, Pubspec('b'));
        createLoggingFile(b, package: 'b', exitCode: 1);

        final c = await createProject(workspaceDir, Pubspec('c'));
        createLoggingFile(c, package: 'c');

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: MelosLogger(logger, isQuiet: true),
          config: config,
        );

        await melos.exec(['dart', 'log_lines.dart'], concurrency: 1);

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
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

      test('prints nothing when quiet and all packages succeed', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b'],
        );

        final a = await createProject(workspaceDir, Pubspec('a'));
        createLoggingFile(a, package: 'a');

        final b = await createProject(workspaceDir, Pubspec('b'));
        createLoggingFile(b, package: 'b');

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        final melos = Melos(
          logger: MelosLogger(logger, isQuiet: true),
          config: config,
        );

        await melos.exec(['dart', 'log_lines.dart'], concurrency: 2);

        expect(logger.output, isEmpty);
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

    group('sources', () {
      const sources = ['lib/**.dart'];
      const command = ['echo', 'run', '>>', 'runs.txt'];

      int runCount(Directory packageDir) {
        final runsFile = File(p.join(packageDir.path, 'runs.txt'));
        return runsFile.existsSync()
            ? 'run'.allMatches(runsFile.readAsStringSync()).length
            : 0;
      }

      void writeSource(Directory packageDir, String contents) {
        writeTextFile(
          p.join(packageDir.path, 'lib', 'source.dart'),
          contents,
          recursive: true,
        );
      }

      Future<(Melos, TestLogger)> createMelos(Directory workspaceDir) async {
        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );
        return (Melos(logger: logger, config: config), logger);
      }

      test('skips the packages with unchanged sources', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a', 'b'],
        );
        final aDir = await createProject(workspaceDir, Pubspec('a'));
        final bDir = await createProject(workspaceDir, Pubspec('b'));
        writeSource(aDir, '// a');
        writeSource(bDir, '// b');

        final (melos, _) = await createMelos(workspaceDir);
        await melos.exec(command, concurrency: 1, sources: sources);
        expect(runCount(aDir), 1);
        expect(runCount(bDir), 1);

        writeSource(bDir, '// b changed');

        final (secondMelos, logger) = await createMelos(workspaceDir);
        await secondMelos.exec(command, concurrency: 1, sources: sources);
        expect(runCount(aDir), 1);
        expect(runCount(bDir), 2);

        expect(
          logger.output.normalizeLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> echo run >> runs.txt
     └> RUNNING (in 2 packages)

${'-' * terminalWidth}
a: SKIPPED (sources are unchanged)
${'-' * terminalWidth}
b:
b: SUCCESS
${'-' * terminalWidth}

\$ melos exec
  └> echo run >> runs.txt
     └> SUCCESS
     └> SKIPPED (in 1 packages with unchanged sources)
''',
          ),
        );
      });

      test(
        'runs in the dependents of a package with changed sources',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c'],
          );
          final aDir = await createProject(
            workspaceDir,
            Pubspec(
              'a',
              dependencies: {
                'b': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );
          final bDir = await createProject(workspaceDir, Pubspec('b'));
          final cDir = await createProject(workspaceDir, Pubspec('c'));
          writeSource(aDir, '// a');
          writeSource(bDir, '// b');
          writeSource(cDir, '// c');

          final (melos, _) = await createMelos(workspaceDir);
          await melos.exec(command, concurrency: 1, sources: sources);

          writeSource(bDir, '// b changed');

          final (secondMelos, _) = await createMelos(workspaceDir);
          await secondMelos.exec(command, concurrency: 1, sources: sources);
          expect(runCount(aDir), 2);
          expect(runCount(bDir), 2);
          expect(runCount(cDir), 1);
        },
      );

      group('with a dependent', () {
        late Directory workspaceDir;
        late Directory dependentDir;
        late Directory dependencyDir;

        setUp(() async {
          workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b'],
          );
          dependentDir = await createProject(
            workspaceDir,
            Pubspec(
              'a',
              dependencies: {
                'b': HostedDependency(version: VersionConstraint.any),
              },
            ),
          );
          dependencyDir = await createProject(workspaceDir, Pubspec('b'));
          writeSource(dependentDir, '// a');
          writeSource(dependencyDir, '// b');
        });

        void deleteFingerprints(Directory packageDir) {
          Directory(
            p.join(packageDir.path, fingerprintsDirectory),
          ).deleteSync(recursive: true);
        }

        test(
          'runs in the dependents of a package in which the command runs',
          () async {
            final (melos, _) = await createMelos(workspaceDir);
            await melos.exec(command, sources: sources);

            deleteFingerprints(dependencyDir);

            final (secondMelos, _) = await createMelos(workspaceDir);
            await secondMelos.exec(command, sources: sources);
            expect(runCount(dependentDir), 2);
            expect(runCount(dependencyDir), 2);
          },
        );

        test(
          'runs again in a dependent in which the command failed while it was '
          'only running because of its dependency',
          () async {
            File(p.join(dependentDir.path, 'run.dart')).writeAsStringSync('''
import 'dart:io';

void main() {
  File('runs.txt').writeAsStringSync('run', mode: FileMode.append);
  exit(File('fail.txt').existsSync() ? 1 : 0);
}
''');
            copyFile(
              p.join(dependentDir.path, 'run.dart'),
              p.join(dependencyDir.path, 'run.dart'),
            );
            const dartCommand = ['dart', 'run.dart'];

            final (melos, _) = await createMelos(workspaceDir);
            await melos.exec(dartCommand, sources: sources);

            deleteFingerprints(dependencyDir);
            final failFile = File(p.join(dependentDir.path, 'fail.txt'))
              ..createSync();

            final (secondMelos, _) = await createMelos(workspaceDir);
            await secondMelos.exec(dartCommand, sources: sources);
            exitCode = 0;
            expect(runCount(dependentDir), 2);
            expect(runCount(dependencyDir), 2);

            failFile.deleteSync();

            final (thirdMelos, _) = await createMelos(workspaceDir);
            await thirdMelos.exec(dartCommand, sources: sources);
            expect(runCount(dependentDir), 3);
            expect(runCount(dependencyDir), 2);
          },
        );

        group('when the command generates files that match the sources', () {
          final generatingCommand = [
            ...command,
            '&&',
            'echo',
            'generated',
            '>',
            p.join('lib', 'source.g.dart'),
          ];

          test(
            'warns and runs again in a dependent that started before its '
            'dependency generated the files',
            () async {
              final (melos, logger) = await createMelos(workspaceDir);
              await melos.exec(
                generatingCommand,
                concurrency: 1,
                sources: sources,
              );
              expect(
                logger.output.normalizeLines(),
                ignoringAnsii(
                  allOf([
                    contains('WARNING: The command changed files'),
                    contains('  a (b)'),
                    contains('Specify "orderDependents"'),
                  ]),
                ),
              );

              for (var i = 0; i < 2; i++) {
                final (nextMelos, nextLogger) = await createMelos(workspaceDir);
                await nextMelos.exec(
                  generatingCommand,
                  concurrency: 1,
                  sources: sources,
                );
                expect(nextLogger.output, isNot(contains('WARNING')));
              }

              expect(runCount(dependentDir), 2);
              expect(runCount(dependencyDir), 1);
            },
          );

          test(
            'does not run again in a dependent when the dependents are ordered',
            () async {
              for (var i = 0; i < 2; i++) {
                final (melos, logger) = await createMelos(workspaceDir);
                await melos.exec(
                  generatingCommand,
                  concurrency: 1,
                  orderDependents: true,
                  sources: sources,
                );
                expect(logger.output, isNot(contains('WARNING')));
              }

              expect(runCount(dependentDir), 1);
              expect(runCount(dependencyDir), 1);
            },
          );
        });
      });

      test('runs again in the packages in which the command failed', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a'],
        );
        final aDir = await createProject(workspaceDir, Pubspec('a'));
        writeSource(aDir, '// a');
        const failingCommand = [...command, '&&', 'exit', '1'];

        for (var i = 0; i < 2; i++) {
          final (melos, _) = await createMelos(workspaceDir);
          await melos.exec(failingCommand, concurrency: 1, sources: sources);
        }
        exitCode = 0;

        expect(runCount(aDir), 2);
      });

      test('runs in the packages with unchanged sources when forced', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a'],
        );
        final aDir = await createProject(workspaceDir, Pubspec('a'));
        writeSource(aDir, '// a');

        for (var i = 0; i < 2; i++) {
          final (melos, _) = await createMelos(workspaceDir);
          await melos.exec(
            command,
            concurrency: 1,
            sources: sources,
            force: true,
          );
        }

        expect(runCount(aDir), 2);
      });

      test('tracks the sources of every command separately', () async {
        final workspaceDir = await createTemporaryWorkspace(
          workspacePackages: ['a'],
        );
        final aDir = await createProject(workspaceDir, Pubspec('a'));
        writeSource(aDir, '// a');

        final (melos, _) = await createMelos(workspaceDir);
        await melos.exec(command, concurrency: 1, sources: sources);
        await melos.exec(
          [...command, '&&', 'echo', 'done'],
          concurrency: 1,
          sources: sources,
        );

        expect(runCount(aDir), 2);
      });

      test(
        'does not run again when the command generates files that match the '
        'sources',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a'],
          );
          final aDir = await createProject(workspaceDir, Pubspec('a'));
          writeSource(aDir, '// a');
          final generatingCommand = [
            ...command,
            '&&',
            'echo',
            'generated',
            '>',
            p.join('lib', 'source.g.dart'),
          ];

          for (var i = 0; i < 2; i++) {
            final (melos, _) = await createMelos(workspaceDir);
            await melos.exec(
              generatingCommand,
              concurrency: 1,
              sources: sources,
            );
          }

          expect(runCount(aDir), 1);
        },
      );
    });

    group('config', () {
      void createDelayedExitFile(Directory dir, {int delay = 0}) {
        File('${dir.path}/delayed_exit.dart').writeAsStringSync('''
        import 'dart:io';
        Future<void> main() async {
          await Future.delayed(Duration(milliseconds: $delay));
          exit(1);
        }
        ''');
      }

      Future<TestLogger> runExecWith(
        ExecCommandConfigs execConfigs, {
        bool? failFast,
      }) async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_workspace',
            packages: [createGlob('packages/**', currentDirectoryPath: path)],
            commands: CommandConfigs(exec: execConfigs),
          ),
          workspacePackages: ['a', 'b', 'c'],
        );

        createDelayedExitFile(
          await createProject(workspaceDir, Pubspec('a')),
          delay: 1000,
        );
        createDelayedExitFile(
          await createProject(workspaceDir, Pubspec('b')),
          delay: 500,
        );
        createDelayedExitFile(await createProject(workspaceDir, Pubspec('c')));

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
          workspaceDir,
        );

        await Melos(logger: logger, config: config).exec(
          ['dart', 'delayed_exit.dart'],
          concurrency: 3,
          orderDependents: true,
          failFast: failFast,
        );

        return logger;
      }

      test('uses the configured failFast', () async {
        final logger = await runExecWith(
          const ExecCommandConfigs(failFast: true),
        );

        expect(
          logger.output.normalizeLines(),
          contains('CANCELED (in 2 packages)'),
        );
      });

      test('command line options take precedence over the config', () async {
        final logger = await runExecWith(
          const ExecCommandConfigs(failFast: true),
          failFast: false,
        );

        expect(
          logger.output.normalizeLines(),
          isNot(contains('CANCELED')),
        );
      });
    });
  });
}
