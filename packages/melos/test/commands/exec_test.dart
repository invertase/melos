import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/scaffolding.dart';
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
      File(join(aDir.path, 'log.txt')).createSync();

      final bDir = await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );
      File(join(bDir.path, 'log.txt')).createSync();

      await createProject(
        workspaceDir,
        const PubSpec(name: 'c'),
      );

      final logger = TestLogger();
      final melos = Melos(
        logger: logger,
        workingDirectory: workspaceDir,
      );

      await melos.exec(
        ['echo', 'hello', 'world'],
        concurrency: 1,
        filter: PackageFilter(
          fileExists: ['log.txt'],
        ),
      );

      expect(
        logger.output,
        equalsIgnoringAnsii(
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
