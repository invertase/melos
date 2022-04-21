import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/common/utils.dart';
import 'package:melos/src/scripts.dart';
import 'package:path/path.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('script', () {
    test(
      'supports passing package filter options to "melos exec" scripts',
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
          ignoringAnsii(
            '''
melos run test_script
   └> melos exec -- "echo hello"
       └> RUNNING

\$ melos exec
   └> echo hello
       └> RUNNING (in 1 packages)

${'-' * terminalWidth}
a:
hello
a: SUCCESS
${'-' * terminalWidth}

\$ melos exec
   └> echo hello
       └> SUCCESS

melos run test_script
   └> melos exec -- "echo hello"
       └> SUCCESS
''',
          ),
        );
      },
      // TODO test is not compatible with Windows (windows prints
      // `hello\r\n` for carriage returns, whereas here they
      // appear as `hello\n`)
      skip: currentPlatform.isWindows,
    );

    test(
      'supports passing additional arguments to run scripts',
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
                run: r'echo $0 $1 $2',
              )
            }),
          ),
        );

        final logger = TestLogger();
        final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
        final melos = Melos(
          logger: logger,
          config: config,
        );

        await melos.run(
          scriptName: 'test_script',
          noSelect: true,
          extraArgs: [
            'foo',
            'bar',
            'baz',
          ],
        );

        expect(
          logger.output,
          ignoringAnsii(
            r'''
melos run test_script
   └> echo $0 $1 $2
       └> RUNNING

/bin/sh foo bar baz

melos run test_script
   └> echo $0 $1 $2
       └> SUCCESS
''',
          ),
        );
      },
      // TODO test is not compatible with Windows
      skip: currentPlatform.isWindows,
    );
  });
}
