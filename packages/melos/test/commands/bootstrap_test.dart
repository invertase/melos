import 'package:melos/melos.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('bootstrap', () {
    test('resolves workspace packages with path dependency', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory();

      final aDir = await createProject(
        workspaceDir,
        PubSpec(
          name: 'a',
          dependencies: {'b': HostedReference(VersionConstraint.any)},
        ),
      );
      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );

      await createProject(
        workspaceDir,
        pubSpecFromJsonFile(fileName: 'add_to_app_json.json'),
      );

      await createProject(
        workspaceDir,
        pubSpecFromJsonFile(fileName: 'plugin_json.json'),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await melos.bootstrap();

      expect(
        logger.output,
        equalsIgnoringAnsii(
          '''
melos bootstrap
   └> ${workspaceDir.path}

Running "flutter pub get" in workspace packages...
  ✓ a
    └> packages/a
  ✓ b
    └> packages/b
  ✓ c
    └> packages/c
  ✓ d
    └> packages/d

Linking workspace packages...
  > SUCCESS

Generating IntelliJ IDE files...
  > SUCCESS

 -> 4 plugins bootstrapped
''',
        ),
      );

      final aConfig = packageConfigForPackageAt(aDir);

      expect(
        aConfig.packages.firstWhere((p) => p.name == 'b').rootUri,
        '../../b',
      );
      expect(aConfig.generator, 'melos');
    });

    test('handles errors in pub get', () async {
      final workspaceDir = createTemporaryWorkspaceDirectory();

      await createProject(
        workspaceDir,
        PubSpec(
          name: 'a',
          dependencies: {
            'package_that_does_not_exists': HostedReference(
              VersionConstraint.parse('^1.2.3-no-way-this-exists'),
            ),
          },
        ),
      );

      final logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromDirectory(workspaceDir);
      final melos = Melos(
        logger: logger,
        config: config,
      );

      await expectLater(
        melos.bootstrap(),
        throwsA(
          isA<BootstrapException>()
              .having((e) => e.package.name, 'package.name', 'a'),
        ),
      );

      expect(
        logger.output,
        equalsIgnoringAnsii(
          '''
melos bootstrap
   └> ${workspaceDir.path}

Running "pub get" in workspace packages...
  - a
    └> packages/a
e-    └> Failed to install.

Resolving dependencies...
e-Because a depends on package_that_does_not_exists any which doesn't exist (could not find package package_that_does_not_exists at https://pub.dartlang.org), version solving failed.
''',
        ),
      );
    });

    test('can disable IDE generation using melos config', () {}, skip: true);

    test('can supports package filter', () {}, skip: true);
  });
}
