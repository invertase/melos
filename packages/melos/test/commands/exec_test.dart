import 'package:melos/melos.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart';
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
      writeTextFile(join(aDir.path, 'log.txt'), '');

      final bDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );
      writeTextFile(join(bDir.path, 'log.txt'), '');

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

    // TODO test that environemnt variables are injected
  });
}
