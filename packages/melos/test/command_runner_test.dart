import 'package:melos/melos.dart';
import 'package:melos/src/command_runner.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/scripts.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('CommandRunner', () {
    test('adds hidden script commands', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: Scripts({
            'test_script1': Script(name: 'test_script1', run: ''),
            'test_script2': Script(name: 'test_script2', run: ''),
          }),
        ),
      );

      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final runner = MelosCommandRunner(config);

      expect(
        runner.commands.keys,
        containsAll(<String>['test_script1', 'test_script2']),
      );

      final command = runner.commands['test_script1'];
      expect(command, isNotNull);
      expect(command!.hidden, isTrue);
    });

    test('excludes conflicting script commands', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: Scripts({
            'run': Script(name: 'run', run: ''),
          }),
        ),
      );

      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final runner = MelosCommandRunner(config);

      final command = runner.commands['run'];
      expect(command, isNotNull);
      expect(command!.hidden, isFalse);
    });
  });
}
