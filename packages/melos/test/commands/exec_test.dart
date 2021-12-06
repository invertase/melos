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
      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
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
t-\$ melos exec
t-   └> echo hello world
t-       └> RUNNING (in 2 packages)
t-
t-${'-' * terminalWidth}
t-a:
hello world
t-a: SUCCESS
t-${'-' * terminalWidth}
t-b:
hello world
t-b: SUCCESS
t-${'-' * terminalWidth}
t-
t-\$ melos exec
t-   └> echo hello world
t-       └> SUCCESS
''',
        ),
      );
    });

    // TODO test that environemnt variables are injected
  });
}
