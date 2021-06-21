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

      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
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
       └> RUNNING (in 1 packages)

${List.generate(terminalWidth, (_) => '-').join()}
a:
hello world
a: SUCCESS
${List.generate(terminalWidth, (_) => '-').join()}

\$ melos exec
   └> echo hello world
       └> SUCCESS
''',
        ),
      );
    });
  });
}
