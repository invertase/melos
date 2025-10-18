import 'package:melos/melos.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('bootstrap --no-pub', () {
    test('skips pub get when --no-pub flag is provided', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a'],
      );

      await createProject(
        workspaceDir,
        Pubspec('a'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(logger: logger, config: config);

      await melos.bootstrap(
        global: const GlobalOptions(noPub: true),
      );

      expect(
        logger.output,
        ignoringAnsii(
          '''
melos bootstrap
  └> ${workspaceDir.path}

Skipping pub get due to --no-pub flag.
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 1 packages bootstrapped
''',
        ),
      );
    });

    test('runs pub get normally when --no-pub flag is not provided', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a'],
      );

      await createProject(
        workspaceDir,
        Pubspec('a'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: logger.toMelosLogger(),
      );
      final melos = Melos(logger: logger, config: config);

      await melos.bootstrap(
        global: const GlobalOptions(noPub: false),
      );

      expect(
        logger.output,
        ignoringAnsii(
          contains('Running "dart pub get" in workspace...'),
        ),
      );
    });
  });
}