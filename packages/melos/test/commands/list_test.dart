import 'package:melos/src/commands/runner.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/package.dart';
import 'package:melos/src/workspace_configs.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../mock_fs.dart';
import '../mock_workspace_fs.dart';
import '../utils.dart';

void main() {
  late TestLogger logger;

  setUp(() => logger = TestLogger());

  group('melos list', () {
    group('with no format option', () {
      test(
        'logs public packages by default',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a', version: Version.none),
              MockPackageFs(name: 'b', version: Version.none),
            ],
          );

          final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
          final melos = Melos(logger: logger, config: config);

          await melos.list();

          expect(
            logger.output,
            ignoringAnsii(
              '''
a
b
''',
            ),
          );
        }),
      );

      test(
        'logs private packages by default',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a', version: Version.none),
              // b has no version, so it is considered private
              MockPackageFs(name: 'b'),
              // c has a version but publish_to:none so is private
              MockPackageFs(
                name: 'c',
                version: Version.none,
                publishToNone: true,
              ),
            ],
          );

          final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
          final melos = Melos(logger: logger, config: config);

          await melos.list();

          expect(
            logger.output,
            ignoringAnsii(
              '''
a
b
c
''',
            ),
          );
        }),
      );

      test(
        'applies package filters',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a'),
              MockPackageFs(name: 'b'),
              MockPackageFs(name: 'c'),
            ],
          );

          final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
          final melos = Melos(logger: logger, config: config);

          await melos.list(
            filter: PackageFilter(
              includePrivatePackages: true,
              ignore: [
                createGlob('b', currentDirectoryPath: workspaceDir.path),
              ],
            ),
          );

          expect(
            logger.output,
            ignoringAnsii(
              '''
a
c
''',
            ),
          );
        }),
      );

      test(
        'supports long flag for extra information',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a', version: Version(1, 2, 3)),
              MockPackageFs(name: 'b', dependencies: ['a']),
              MockPackageFs(name: 'long_name'),
            ],
          );

          final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
          final melos = Melos(logger: logger, config: config);

          await melos.list(
            long: true,
          );

          expect(
            logger.output,
            ignoringAnsii(
              '''
a         1.2.3 packages/a
b         0.0.0 packages/b         PRIVATE
long_name 0.0.0 packages/long_name PRIVATE
''',
            ),
          );
        }),
      );

      test(
        'relativePaths flag prints relative paths only if true',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a'),
              MockPackageFs(name: 'b'),
              MockPackageFs(name: 'c'),
            ],
          );

          final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
          final melos = Melos(logger: logger, config: config);
          await melos.list(
            kind: ListOutputKind.parsable,
            relativePaths: true,
          );

          expect(
            logger.output,
            ignoringAnsii(
              '''
packages/a
packages/b
packages/c
''',
            ),
          );
        }),
      );

      test(
        'full package path is printed by default if relativePaths is false or not set',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a'),
              MockPackageFs(name: 'b'),
              MockPackageFs(name: 'c'),
            ],
          );

          final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
          final melos = Melos(logger: logger, config: config);
          await melos.list(
            kind: ListOutputKind.parsable,
          );

          expect(
            logger.output,
            ignoringAnsii(
              '''
/melos_workspace/packages/a
/melos_workspace/packages/b
/melos_workspace/packages/c
''',
            ),
          );
        }),
        // TODO test output is not compatible with windows
        skip: currentPlatform.isWindows,
      );
    });
  });
}
