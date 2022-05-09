import 'package:glob/glob.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('clean', () {
    test(
      'removes dependency overrides from pubspec_overrides.yaml',
      () async {
        final workspaceDir = createTemporaryWorkspaceDirectory(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_workspace',
            packages: [Glob('packages/**')],
            commands: const CommandConfigs(
              bootstrap: BootstrapCommandConfigs(
                usePubspecOverrides: true,
              ),
            ),
          ),
        );

        await createProject(workspaceDir, const PubSpec(name: 'a'));
        final packageBDir = await createProject(
          workspaceDir,
          PubSpec(
            name: 'b',
            dependencies: {'a': HostedReference(VersionConstraint.any)},
          ),
        );
        final pubspecOverrides =
            p.join(packageBDir.path, 'pubspec_overrides.yaml');

        final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
        final logger = TestLogger();
        final melos = Melos(config: config, logger: logger);
        await melos.bootstrap();

        expect(
          pubspecOverrides,
          yamlFile({
            'dependency_overrides': {
              'a': {'path': '../a'}
            }
          }),
        );

        await melos.clean();

        expect(
          pubspecOverrides,
          isNot(fileExists),
        );
      },
      skip: !isPubspecOverridesSupported(),
    );
  });
}
