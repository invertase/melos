import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/command_configs/command_configs.dart';
import 'package:melos/src/common/glob.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  late TestLogger logger;

  setUp(() async {
    logger = TestLogger();
  });

  group('version', () {
    // Regression test for: https://github.com/invertase/melos/issues/531
    test('--no-dependent-versions does not modify workspace changelog',
        () async {
      MelosWorkspaceConfig workspaceConfig(String path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_workspace',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            commands: const CommandConfigs(
              version: VersionCommandConfigs(
                fetchTags: false,
              ),
            ),
          );
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: workspaceConfig,
      );
      await createProject(
        workspaceDir,
        PubSpec(name: 'a', version: Version(0, 0, 1)),
      );
      await createProject(
        workspaceDir,
        PubSpec(
          name: 'b',
          version: Version(0, 0, 1),
          dependencies: {
            'a': HostedReference(VersionConstraint.any),
          },
        ),
      );
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final melos = Melos(config: config, logger: logger);

      await melos.bootstrap();
      await melos.version(
        updateDependentsConstraints: false,
        updateDependentsVersions: false,
        versionPrivatePackages: true,
        gitCommit: false,
        gitTag: false,
        force: true,
        manualVersions: {
          'a': ManualVersionChange(Version(0, 1, 0)),
        },
      );

      final workspaceChangelogContent = File(
        p.join(workspaceDir.path, 'CHANGELOG.md'),
      ).readAsStringSync();

      final loggerOutput = logger.output;
      expect(
        loggerOutput,
        contains(
          AnsiStyles.strip('''
The following 1 packages will be updated:
'''),
        ),
      );

      expect(
        workspaceChangelogContent,
        isNot(
          contains(
            AnsiStyles.strip('''
> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `b` - `v0.0.1+1`
'''),
          ),
        ),
      );
      expect(
        workspaceChangelogContent,
        contains(
          AnsiStyles.strip('''
#### `a` - `v0.1.0`

 - Bump "a" to `0.1.0`.
'''),
        ),
      );
    });
  });
}
