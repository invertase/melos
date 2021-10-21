import 'package:melos/src/command_runner/script.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/scripts.dart';
import 'package:melos/src/workspace_configs.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group('Script', () {
    test('fromConfig creates aliases for all scripts', () async {
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
            'test_script3': Script(name: 'test_script3', run: ''),
          }),
        ),
      );

      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final command = ScriptCommand.fromConfig(config);
      expect(command, isNotNull);
      expect(
        [command!.name, ...command.aliases],
        containsAll(<String>['test_script1', 'test_script2', 'test_script3']),
      );
    });

    test('fromConfig excludes given commands', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: Scripts({
            'run': Script(name: 'run', run: ''),
            'test_script1': Script(name: 'test_script1', run: ''),
            'test_script2': Script(name: 'test_script2', run: ''),
            'test_script3': Script(name: 'test_script3', run: ''),
          }),
        ),
      );

      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final command = ScriptCommand.fromConfig(config, exclude: ['run']);
      expect(command, isNotNull);
      expect([command!.name, ...command.aliases], isNot(contains('run')));
    });

    test('fromConfig does not create an empty command', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: Scripts({
            'clean': Script(name: 'clean', run: ''),
          }),
        ),
      );

      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final command = ScriptCommand.fromConfig(config, exclude: ['clean']);
      expect(command, isNull);
    });
  });
}
