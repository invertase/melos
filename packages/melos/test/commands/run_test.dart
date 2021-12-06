import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/utils.dart';
import 'package:melos/src/scripts.dart';
import 'package:path/path.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('script', () {
    test('supports passing package filter options to "melos exec" scripts',
        () async {
      final workspaceDir = createTemporaryWorkspaceDirectory(
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
              filter: PackageFilter(
                fileExists: ['log.txt'],
              ),
            )
          }),
        ),
      );

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
      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.run(scriptName: 'test_script', noSelect: true);

      expect(
        logger.output,
        equalsIgnoringAnsii(
          '''
t-melos run test_script
t-   └> melos exec -- "echo hello"
t-       └> RUNNING
t-
hello

t-melos run test_script
t-   └> melos exec -- "echo hello"
t-       └> SUCCESS
''',
        ),
      );
    });
  });
}
