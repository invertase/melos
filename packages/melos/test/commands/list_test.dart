import 'package:melos/src/commands/runner.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import '../mock_fs.dart';
import '../mock_workspace_fs.dart';
import '../utils.dart';

void main() {
  late TestLogger logger;

  setUp(() => logger = TestLogger());

  group('melos list', () {
    group('with no format option', () {
      test(
        'logs all packages in the workspace by default',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a'),
              MockPackageFs(name: 'b'),
            ],
          );

          final melos = Melos(logger: logger, workingDirectory: workspaceDir);

          await melos.list();

          expect(logger.errs, isEmpty);
          expect(logger.traces, isEmpty);
          expect(
            logger.logs,
            unorderedEquals(<Object>['a', 'b']),
          );
        }),
      );
    });
  });
}
