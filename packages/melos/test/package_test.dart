import 'dart:io';

import 'package:melos/src/common/workspace.dart';
import 'package:nock/nock.dart';
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import 'mock_env.dart';
import 'mock_fs.dart';
import 'mock_workspace_fs.dart';

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

    MelosWorkspace workspace;
    setUp(() async {
      nock.cleanAll();
      IOOverrides.global = MockFs();

      workspace = await MelosWorkspace.fromDirectory(
        createMockWorkspaceFs(
          packages: [MockPackageFs(name: 'melos')],
        ),
      );
      await workspace.loadPackagesWithFilters();
    });

    tearDown(() {
      IOOverrides.global = null;
    });

    test('requests published packages from pub.dev by default', () async {
      final interceptor = nock('https://pub.dev').get('/packages/melos.json')
        ..reply(200, pubPackageJson);

      final package = workspace.packages.first;
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

          final package = workspace.packages.first;
          await package.getPublishedVersions();

          expect(interceptor.isDone, isTrue);
        },
        platform: FakePlatform.fromPlatform(const LocalPlatform())
          ..environment['PUB_HOSTED_URL'] = 'http://localhost:8080',
      ),
    );
  });
}
