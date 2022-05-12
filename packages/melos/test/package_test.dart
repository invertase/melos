import 'dart:io';

import 'package:glob/glob.dart';
import 'package:http/http.dart' as http;
import 'package:melos/src/common/http.dart';
import 'package:melos/src/package.dart';
import 'package:melos/src/workspace.dart';
import 'package:melos/src/workspace_configs.dart';
import 'package:mockito/mockito.dart';
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
    final httpClientMock = HttpClientMock();
    late MelosWorkspace workspace;

    setUpAll(() => testClient = httpClientMock);

    setUp(() async {
      reset(httpClientMock);
      IOOverrides.global = MockFs();

      final config = await MelosWorkspaceConfig.fromDirectory(
        createMockWorkspaceFs(
          packages: [MockPackageFs(name: 'melos')],
        ),
      );
      workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger(),
      );
    });

    tearDown(() => IOOverrides.global = null);

    tearDownAll(() => testClient = null);

    test('requests published packages from pub.dev by default', () async {
      final uri = Uri.parse('https://pub.dev/packages/melos.json');
      when(httpClientMock.get(uri))
          .thenAnswer((_) async => http.Response(pubPackageJson, 200));

      final package = workspace.allPackages.values.first;
      await package.getPublishedVersions();

      verify(httpClientMock.get(uri)).called(1);
    });

    test(
      'requests published packages from PUB_HOSTED_URL if present',
      withMockPlatform(
        () async {
          final uri = Uri.parse('http://localhost:8080/packages/melos.json');
          when(httpClientMock.get(uri))
              .thenAnswer((_) async => http.Response(pubPackageJson, 200));

          final package = workspace.allPackages.values.first;
          await package.getPublishedVersions();

          verify(httpClientMock.get(uri)).called(1);
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
