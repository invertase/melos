import 'package:melos/melos.dart';
import 'package:melos/src/command_configs/command_configs.dart';
import 'package:melos/src/command_configs/publish.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/utils.dart';
import 'package:melos/src/lifecycle_hooks/publish.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../utils.dart';

void main() {
  group('publish', () {
    group('sort packages', () {
      test('wo/ cyclic dependencies', () {
        //     b
        //   /   \
        // a       d
        //   \   /
        //     c
        //
        // e  -->  *f (external package)
        final packages = [
          _dummyPackage('a', deps: ['b', 'c']),
          _dummyPackage('b', deps: ['d']),
          _dummyPackage('c', deps: ['d']),
          _dummyPackage('d', deps: []),
          _dummyPackage('e', deps: ['f']),
        ]..shuffle();
        final packageNames = packages.map((el) => el.name).toList();
        sortPackagesForPublishing(packages);

        final published = <String>{};
        for (final package in packages) {
          final dependencies = package.dependencies;
          for (final dependency in dependencies) {
            final isExternal = !packageNames.contains(dependency);
            final isPublished = published.contains(dependency);
            expect(isExternal || isPublished, isTrue);
          }
          published.add(package.name);
        }
      });

      test('w/ cyclic dependencies', () {
        final packages = [
          _dummyPackage('a', deps: ['b']),
          _dummyPackage('b', deps: ['a']),
        ];
        expect(
          () => sortPackagesForPublishing(packages),
          returnsNormally,
        );
      });
    });

    group('lifecycle hooks', () {
      for (final dryRun in [false, true]) {
        test('are called in the correct order', () async {
          final logger = TestLogger();
          final workspaceDir = await createTemporaryWorkspace(
            configBuilder: (path) => MelosWorkspaceConfig(
              path: path,
              name: 'test_workspace',
              packages: [
                createGlob('packages/**', currentDirectoryPath: path),
              ],
              commands: const CommandConfigs(
                publish: PublishCommandConfigs(
                  hooks: PublishLifecycleHooks(
                    pre: Script(name: 'pre', run: 'echo pre'),
                    post: Script(name: 'post', run: 'echo post'),
                  ),
                ),
              ),
            ),
          );

          for (final package in ['a', 'b']) {
            await createProject(
              workspaceDir,
              PubSpec(name: package),
              path: 'packages',
            );
          }

          final config =
              await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
          final melos = Melos(
            logger: logger,
            config: config,
          );

          await melos.publish(dryRun: dryRun);
          final order = [
            'melos publish [pre]',
            'pre',
            if (dryRun) 'melos publish --dry-run',
            if (!dryRun) 'melos publish',
            'melos publish [post]',
            'post',
          ];
          final output = logger.output.normalizeNewLines().split('\n');
          var previousIndex = -1;

          for (final line in order) {
            final index = output.indexOf(line);
            expect(index, isNonNegative, reason: 'Line not found: $line');
            expect(
              index,
              greaterThan(previousIndex),
              reason: 'Line $line is out of order',
            );
            previousIndex = index;
          }
        });
      }
    });
  });
}

Package _dummyPackage(String name, {List<String> deps = const []}) {
  return Package(
    devDependencies: [],
    dependencies: deps,
    dependencyOverrides: [],
    packageMap: {},
    name: name,
    path: '/',
    pathRelativeToWorkspace: '',
    version: Version(1, 0, 0),
    publishTo: null,
    pubSpec: const PubSpec(),
  );
}
