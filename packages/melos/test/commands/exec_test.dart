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
    test('supports package filters', () async {
      final workspaceDir = await createTemporaryWorkspace();

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

    group('order dependents', () {
      test('sorts execution order topologically', () async {
        final workspaceDir = await createTemporaryWorkspace();

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
        final config =
            await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
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
        final workspaceDir = await createTemporaryWorkspace();

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
        final config =
            await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.exec(
          ['exit', '1'],
          concurrency: 2,
          orderDependents: true,
        );

        expect(
          logger.output.normalizeNewLines(),
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

      test('does not fail fast if dependencies is not run', () async {
        final workspaceDir = await createTemporaryWorkspace();

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
        final config =
            await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
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
  });
}
