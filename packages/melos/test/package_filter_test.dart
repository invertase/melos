import 'package:glob/glob.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/http.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/pub_credential.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import 'matchers.dart';
import 'utils.dart';

void main() {
  group('PackageFilters', () {
    test('dirExists', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a', 'b'],
      );

      final aDir = await createProject(
        workspaceDir,
        Pubspec('a'),
      );
      ensureDir(p.join(aDir.path, 'test'));

      await createProject(
        workspaceDir,
        Pubspec('b'),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger().toMelosLogger(),
        packageFilters: const PackageFilters(
          dirExists: ['test'],
        ),
      );

      expect(
        workspace.allPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'b'),
        ],
      );
      expect(
        workspace.filteredPackages.values,
        [isA<Package>().having((p) => p.name, 'name', 'a')],
      );
    });

    test('fileExists', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a', 'b'],
      );

      final aDir = await createProject(
        workspaceDir,
        Pubspec('a'),
      );
      writeTextFile(p.join(aDir.path, 'log.txt'), '');

      await createProject(
        workspaceDir,
        Pubspec('b'),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger().toMelosLogger(),
        packageFilters: const PackageFilters(
          fileExists: ['log.txt'],
        ),
      );

      expect(
        workspace.allPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'b'),
        ],
      );
      expect(
        workspace.filteredPackages.values,
        [isA<Package>().having((p) => p.name, 'name', 'a')],
      );
    });

    test('ignore', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a', 'b'],
      );

      await createProject(
        workspaceDir,
        Pubspec('a'),
      );

      await createProject(
        workspaceDir,
        Pubspec('b'),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger().toMelosLogger(),
        packageFilters: PackageFilters(
          ignore: [Glob('a')],
        ),
      );

      expect(
        workspace.allPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'b'),
        ],
      );
      expect(
        workspace.filteredPackages.values,
        [isA<Package>().having((p) => p.name, 'name', 'b')],
      );
    });

    test('category', () async {
      MelosWorkspaceConfig configBuilder(String path) {
        return MelosWorkspaceConfig(
          name: 'Melos',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          categories: {
            'a': [
              Glob('packages/a'),
              Glob('packages/c'),
            ],
            'b': [
              Glob('packages/*a*'),
            ],
            'c': [
              Glob('packages/ab*'),
            ],
          },
          path: path,
        );
      }

      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: configBuilder,
        workspacePackages: ['a', 'ab', 'abc', 'b', 'c'],
      );

      await createProject(
        workspaceDir,
        Pubspec('a'),
      );
      await createProject(
        workspaceDir,
        Pubspec('ab'),
      );
      await createProject(
        workspaceDir,
        Pubspec('abc'),
      );
      await createProject(
        workspaceDir,
        Pubspec('b'),
      );
      await createProject(
        workspaceDir,
        Pubspec('c'),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      final workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger().toMelosLogger(),
        packageFilters: PackageFilters(
          categories: [Glob('b')],
        ),
      );

      expect(
        workspace.allPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'ab'),
          isA<Package>().having((p) => p.name, 'name', 'abc'),
          isA<Package>().having((p) => p.name, 'name', 'b'),
          isA<Package>().having((p) => p.name, 'name', 'c'),
        ],
      );
      expect(
        workspace.filteredPackages.values,
        [
          isA<Package>().having((p) => p.name, 'name', 'a'),
          isA<Package>().having((p) => p.name, 'name', 'ab'),
          isA<Package>().having((p) => p.name, 'name', 'abc'),
        ],
      );
    });

    group('flutter', () {
      MelosWorkspace buildWorkspace() {
        final workspaceBuilder = VirtualWorkspaceBuilder('name: test')
          ..addPackage('''
            name: a
            dependencies:
              flutter:
                sdk: flutter
          ''')
          ..addPackage('''
            name: b
            dependencies:
              a: any
          ''')
          ..addPackage('''
            name: c
          ''');
        return workspaceBuilder.build();
      }

      test('includes packages that transitively need Flutter', () async {
        final workspace = buildWorkspace();
        final filteredPackages = await workspace.allPackages.applyFilters(
          const PackageFilters(flutter: true),
        );

        expect(filteredPackages.keys, ['a', 'b']);
      });

      test('excludes packages that transitively need Flutter', () async {
        final workspace = buildWorkspace();
        final filteredPackages = await workspace.allPackages.applyFilters(
          const PackageFilters(flutter: false),
        );

        expect(filteredPackages.keys, ['c']);
      });

      test('does not filter when not specified', () async {
        final workspace = buildWorkspace();
        final filteredPackages = await workspace.allPackages.applyFilters(
          const PackageFilters(),
        );

        expect(filteredPackages.keys, ['a', 'b', 'c']);
      });
    });

    group('postFilters', () {
      MelosWorkspace buildWorkspace() {
        final workspaceBuilder = VirtualWorkspaceBuilder('name: test')
          ..addPackage('''
            name: app
            dependencies:
              models: any
              utils: any
          ''')
          ..addPackage('''
            name: models
            dependencies:
              utils: any
            dev_dependencies:
              build_runner: any
          ''')
          ..addPackage('''
            name: utils
          ''');
        return workspaceBuilder.build();
      }

      test('filters the included dependencies', () async {
        final workspace = buildWorkspace();
        final filteredPackages = await workspace.allPackages.applyFilters(
          PackageFilters(
            scope: [Glob('app')],
            includeDependencies: true,
            postFilters: const PackageFilters(dependsOn: ['build_runner']),
          ),
        );

        expect(filteredPackages.keys, ['models']);
      });

      test('filters the included dependents', () async {
        final workspace = buildWorkspace();
        final filteredPackages = await workspace.allPackages.applyFilters(
          PackageFilters(
            scope: [Glob('utils')],
            includeDependents: true,
            postFilters: PackageFilters(ignore: [Glob('app')]),
          ),
        );

        expect(filteredPackages.keys, unorderedEquals(['utils', 'models']));
      });

      test('are also applied to the packages that matched the other '
          'filters', () async {
        final workspace = buildWorkspace();
        final filteredPackages = await workspace.allPackages.applyFilters(
          PackageFilters(
            scope: [Glob('app')],
            includeDependencies: true,
            postFilters: const PackageFilters(noDependsOn: ['models']),
          ),
        );

        expect(filteredPackages.keys, unorderedEquals(['models', 'utils']));
      });

      test('are applied without including dependents or '
          'dependencies', () async {
        final workspace = buildWorkspace();
        final filteredPackages = await workspace.allPackages.applyFilters(
          const PackageFilters(
            postFilters: PackageFilters(dependsOn: ['build_runner']),
          ),
        );

        expect(filteredPackages.keys, ['models']);
      });

      test('throws when the post filters include dependents, dependencies '
          'or other post filters', () async {
        final workspace = buildWorkspace();

        for (final postFilters in const [
          PackageFilters(includeDependents: true),
          PackageFilters(includeDependencies: true),
          PackageFilters(postFilters: PackageFilters()),
        ]) {
          await expectLater(
            workspace.allPackages.applyFilters(
              PackageFilters(postFilters: postFilters),
            ),
            throwsMelosConfigException(),
          );
        }
      });

      test('looks up the published state of each package once', () async {
        final previousHttpClient = internalHttpClient;
        final previousCredentialStore = internalPubCredentialStore;
        addTearDown(() {
          internalHttpClient = previousHttpClient;
          internalPubCredentialStore = previousCredentialStore;
        });
        internalPubCredentialStore = PubCredentialStore([]);
        final requestedPackages = <String>[];
        internalHttpClient = HttpClientMock((request) {
          final name = request.url.pathSegments.last;
          requestedPackages.add(name);
          return HttpClientMock.parseResponse(
            '{"name": "$name", "versions": []}',
          );
        });

        final workspaceBuilder = VirtualWorkspaceBuilder('name: test')
          ..addPackage('''
            name: app
            version: 1.0.0
            dependencies:
              models: any
              utils: any
          ''')
          ..addPackage('''
            name: models
            version: 1.0.0
          ''')
          ..addPackage('''
            name: utils
            version: 1.0.0
          ''');
        final workspace = workspaceBuilder.build();
        final filteredPackages = await workspace.allPackages.applyFilters(
          PackageFilters(
            scope: [Glob('app')],
            published: false,
            includeDependencies: true,
            postFilters: const PackageFilters(published: false),
          ),
        );

        expect(
          filteredPackages.keys,
          unorderedEquals(['app', 'models', 'utils']),
        );
        expect(
          requestedPackages,
          unorderedEquals(['app', 'models', 'utils']),
        );
      });

      test('included packages skip the other filters when there are no '
          'post filters', () async {
        final workspace = buildWorkspace();
        final filteredPackages = await workspace.allPackages.applyFilters(
          PackageFilters(
            scope: [Glob('app')],
            includeDependencies: true,
          ),
        );

        expect(
          filteredPackages.keys,
          unorderedEquals(['app', 'models', 'utils']),
        );
      });
    });
  });
}
