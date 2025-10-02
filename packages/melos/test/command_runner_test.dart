import 'package:melos/melos.dart';
import 'package:melos/src/command_runner.dart';
import 'package:melos/src/common/glob.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('CommandRunner', () {
    test('adds hidden script commands', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'test_script1': Script(name: 'test_script1', run: ''),
            'test_script2': Script(name: 'test_script2', run: ''),
          }),
        ),
        workspacePackages: [],
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final runner = MelosCommandRunner(config);

      expect(
        runner.commands.keys,
        containsAll(<String>['test_script1', 'test_script2']),
      );

      final command = runner.commands['test_script1'];
      expect(command, isNotNull);
      expect(command!.hidden, isTrue);
    });

    test('custom scripts override built-in commands', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'format': Script(name: 'format', run: 'echo "custom format"'),
          }),
        ),
        workspacePackages: [],
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final runner = MelosCommandRunner(config);

      final command = runner.commands['format'];
      expect(command, isNotNull);
      // The command should be hidden (custom script behavior)
      expect(command!.hidden, isTrue);
    });
  });
}
