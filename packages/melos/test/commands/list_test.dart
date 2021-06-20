import 'package:melos/src/commands/runner.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/package.dart';
import 'package:pub_semver/pub_semver.dart';
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
        'logs public packages by default',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a', version: Version.none),
              MockPackageFs(name: 'b', version: Version.none),
            ],
          );

          final melos = Melos(logger: logger, workingDirectory: workspaceDir);

          await melos.list();

          expect(logger.errs, isEmpty);
          expect(logger.traces, isEmpty);
          expect(
            logger.logs.join(),
            '''
a
b
''',
          );
        }),
      );

      test(
        'does not log private packages by default',
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

          final melos = Melos(logger: logger, workingDirectory: workspaceDir);

          await melos.list();

          expect(logger.errs, isEmpty);
          expect(logger.traces, isEmpty);
          expect(
            logger.logs.join(),
            '''
a
''',
          );
        }),
      );

      test(
        'log private packages if showPrivatePackages is true',
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

          final melos = Melos(logger: logger, workingDirectory: workspaceDir);

          await melos.list(showPrivatePackages: true);

          expect(logger.errs, isEmpty);
          expect(logger.traces, isEmpty);
          expect(
            logger.logs.join(),
            '''
a
b
c
''',
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

          final melos = Melos(logger: logger, workingDirectory: workspaceDir);

          await melos.list(
            showPrivatePackages: true,
            filter: PackageFilter(
              ignore: [
                createGlob('b', currentDirectoryPath: workspaceDir.path),
              ],
            ),
          );

          expect(logger.errs, isEmpty);
          expect(logger.traces, isEmpty);
          expect(
            logger.logs.join(),
            '''
a
c
''',
          );
        }),
      );

      test(
        'supports long flag for extra informations',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a', version: Version(1, 2, 3)),
              MockPackageFs(name: 'b', dependencies: ['a']),
              MockPackageFs(name: 'long_name'),
            ],
          );

          final melos = Melos(logger: logger, workingDirectory: workspaceDir);

          await melos.list(
            showPrivatePackages: true,
            long: true,
          );

          expect(logger.errs, isEmpty);
          expect(logger.traces, isEmpty);
          expect(
            logger.logs.join(),
            '''
a         1.2.3 packages/a
b         0.0.0 packages/b         PRIVATE
long_name 0.0.0 packages/long_name PRIVATE
''',
          );
        }),
      );

      test(
        'long flag hides private packages by default',
        withMockFs(() async {
          final workspaceDir = createMockWorkspaceFs(
            packages: [
              MockPackageFs(name: 'a', version: Version(1, 2, 3)),
              MockPackageFs(name: 'b'),
              MockPackageFs(name: 'c', version: Version.none),
            ],
          );

          final melos = Melos(logger: logger, workingDirectory: workspaceDir);

          await melos.list(long: true);

          expect(logger.errs, isEmpty);
          expect(logger.traces, isEmpty);
          expect(
            logger.logs.join(),
            '''
a 1.2.3 packages/a
c 0.0.0 packages/c
''',
          );
        }),
      );
    });
  });
}
