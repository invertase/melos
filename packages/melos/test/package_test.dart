import 'dart:io';

import 'package:glob/glob.dart';
import 'package:melos/src/package.dart';
import 'package:melos/src/workspace.dart';
import 'package:nock/nock.dart';
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import 'mock_env.dart';
import 'mock_fs.dart';
import 'mock_workspace_fs.dart';
import 'utils.dart';

const pubPackageJson = '''
  {
    "versions": [
      "1.0.0"
    ]
  }
''';

void main() {
  group('MelosPackage', () {
    setUpAll(nock.init);

    late MelosWorkspace workspace;
    setUp(() async {
      nock.cleanAll();
      IOOverrides.global = MockFs();

      workspace = await MelosWorkspace.fromDirectory(
        createMockWorkspaceFs(
          packages: [MockPackageFs(name: 'melos')],
        ),
        logger: TestLogger(),
      );
    });

    tearDown(() {
      IOOverrides.global = null;
    });

    test('requests published packages from pub.dev by default', () async {
      final interceptor = nock('https://pub.dev').get('/packages/melos.json')
        ..reply(200, pubPackageJson);

      final package = workspace.allPackages.values.first;
      await package.getPublishedVersions();

      expect(interceptor.isDone, isTrue);
    });

    test(
      'requests published packages from PUB_HOSTED_URL if present',
      withMockPlatform(
        () async {
          final interceptor = nock('http://localhost:8080')
              .get('/packages/melos.json')
                ..reply(200, pubPackageJson);

          final package = workspace.allPackages.values.first;
          await package.getPublishedVersions();

          expect(interceptor.isDone, isTrue);
        },
        platform: FakePlatform.fromPlatform(const LocalPlatform())
          ..environment['PUB_HOSTED_URL'] = 'http://localhost:8080',
      ),
    );
  });

  group('PackageFilter', () {
    test('default', () {
      final filter = PackageFilter();

      expect(filter.dependsOn, isEmpty);
      expect(filter.noDependsOn, isEmpty);
      expect(filter.dirExists, isEmpty);
      expect(filter.fileExists, isEmpty);
      expect(filter.ignore, isEmpty);
      expect(filter.scope, isEmpty);
      expect(filter.includeDependencies, false);
      expect(filter.includeDependents, false);
      expect(filter.includePrivatePackages, null);
      expect(filter.nullSafe, null);
      expect(filter.published, null);
      expect(filter.updatedSince, null);
    });

    group('copyWithUpdatedSince', () {
      test('can assign null', () {
        final filter = PackageFilter(updatedSince: '123');

        expect(
          filter.copyWithUpdatedSince(null).updatedSince,
          null,
        );
      });

      test('clone properties besides updatedSince', () {
        final filter = PackageFilter(
          dependsOn: ['a'],
          dirExists: ['a'],
          fileExists: ['a'],
          flutter: true,
          scope: [Glob('a')],
          ignore: [Glob('a')],
          includeDependencies: true,
          includeDependents: true,
          includePrivatePackages: false,
          noDependsOn: ['a'],
          nullSafe: true,
          published: true,
          updatedSince: '123',
        );

        final copy = filter.copyWithUpdatedSince('456');

        expect(copy.updatedSince, '456');
        expect(copy.dependsOn, filter.dependsOn);
        expect(copy.dirExists, filter.dirExists);
        expect(copy.fileExists, filter.fileExists);
        expect(copy.scope, filter.scope);
        expect(copy.ignore, filter.ignore);
        expect(copy.includeDependencies, filter.includeDependencies);
        expect(copy.includeDependents, filter.includeDependents);
        expect(copy.includePrivatePackages, filter.includePrivatePackages);
        expect(copy.noDependsOn, filter.noDependsOn);
        expect(copy.nullSafe, filter.nullSafe);
        expect(copy.published, filter.published);
      });
    });
  });
}
