import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('exec', () {
    test('supports package filter', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory();

      final aDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );
      writeTextFile(p.join(aDir.path, 'log.txt'), '');

      final bDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );
      writeTextFile(p.join(bDir.path, 'log.txt'), '');

      await createProject(
        workspaceDir,
        const PubSpec(name: 'c'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.exec(
        ['echo', 'hello', 'world'],
        concurrency: 1,
        filter: PackageFilter(
          fileExists: const ['log.txt'],
        ),
      );

      expect(
        logger.output.normalizeNewLines(),
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

    group('requires dependencies', () {
      test("orders exec's topilogically", () async {
        final workspaceDir = createTemporaryWorkspaceDirectory();

        await createProject(
          workspaceDir,
          PubSpec(
            name: 'a',
            dependencies: {'c': HostedReference(VersionConstraint.any)},
          ),
        );

        await createProject(
          workspaceDir,
          const PubSpec(name: 'b'),
        );

        await createProject(
          workspaceDir,
          PubSpec(
            name: 'c',
            dependencies: {'b': HostedReference(VersionConstraint.any)},
          ),
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['echo', 'hello', 'world'],
          concurrency: 2,
          requireDependencies: true,
        );

        expect(
          logger.output.normalizeNewLines(),
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
      test('fails fast if dependencies fail', () async {
        final workspaceDir = createTemporaryWorkspaceDirectory();

        await createProject(
          workspaceDir,
          PubSpec(
            name: 'a',
            dependencies: {'c': HostedReference(VersionConstraint.any)},
          ),
        );

        await createProject(
          workspaceDir,
          const PubSpec(name: 'b'),
        );

        await createProject(
          workspaceDir,
          PubSpec(
            name: 'c',
            dependencies: {'b': HostedReference(VersionConstraint.any)},
          ),
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['unrecognised'],
          concurrency: 2,
          requireDependencies: true,
        );

        late final String platformExitString;

        if (Platform.isWindows) {
          platformExitString = '''
e-[b]: 'unrecognised' is not recognized as an internal or external command,
e-[b]: operable program or batch file.''';
        } else if (Platform.isMacOS) {
          platformExitString = '''
e-[b]: /bin/sh: unrecognised: command not found''';
        } else {
          platformExitString = '''
e-[b]: /bin/sh: 1: eval: unrecognised: not found''';
        }

        expect(
          logger.output.normalizeNewLines(),
          ignoringAnsii(
            '''
\$ melos exec
  └> unrecognised
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
$platformExitString
e-
${'-' * terminalWidth}

\$ melos exec
  └> unrecognised
     └> FAILED (in 3 packages)
        └> b (with exit code ${Platform.isWindows ? 1 : 127})
        └> c (dependency failed)
        └> a (dependency failed)
''',
          ),
        );
      });

      test('does not fail fast if dependencies is not run', () async {
        final workspaceDir = createTemporaryWorkspaceDirectory();

        final aDir = await createProject(
          workspaceDir,
          PubSpec(
            name: 'a',
            dependencies: {'c': HostedReference(VersionConstraint.any)},
          ),
        );
        writeTextFile(p.join(aDir.path, 'log.txt'), '');

        await createProject(
          workspaceDir,
          const PubSpec(name: 'b'),
        );

        final cDir = await createProject(
          workspaceDir,
          PubSpec(
            name: 'c',
            dependencies: {'b': HostedReference(VersionConstraint.any)},
          ),
        );
        writeTextFile(p.join(cDir.path, 'log.txt'), '');

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['echo', 'hello', 'world'],
          concurrency: 2,
          requireDependencies: true,
          filter: PackageFilter(
            fileExists: const ['log.txt'],
          ),
        );

        expect(
          logger.output.normalizeNewLines(),
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

    // TODO test that environment variables are injected
  });
}
