import 'dart:io';

import 'package:glob/glob.dart';
import 'package:http/http.dart' as http;
import 'package:melos/melos.dart';
import 'package:melos/src/common/http.dart';
import 'package:melos/src/package.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'mock_env.dart';
import 'mock_fs.dart';
import 'mock_workspace_fs.dart';
import 'utils.dart';

const pubPackageJson = '''
  {
    "versions": [
      {
        "version": "1.0.0"
      }
    ]
  }
''';

void main() {
  group('replace version RegExp', () {
    const testedVersions = [
      '0.1.2+3',
      '1.2.3+4',
      '1.2.3-dev',
      '1.2.3-dev.4',
      '0.1.2',
      '1.2.3',
      '10.0.0',
      '0.10.0',
      '0.0.10',
    ];
    final testedVersionRanges =
        testedVersions.map((version) => '^$version').toList();

    group('dependencyVersion', () {
      testedVersions.forEach(testDependencyVersionReplaceRegex);
      testedVersionRanges.forEach(testDependencyVersionReplaceRegex);
    });

    group('hostedDependencyVersion', () {
      testedVersions.forEach(testHostedDependencyVersionReplaceRegex);
      testedVersionRanges.forEach(testHostedDependencyVersionReplaceRegex);
    });

    group('dependencyTag', () {
      testedVersions.forEach(testDependencyTagReplaceRegex);
    });
  });

  group('MelosPackage', () {
    final httpClientMock = HttpClientMock();
    late MelosWorkspace workspace;

    setUpAll(() => testClient = httpClientMock);

    setUp(() async {
      reset(httpClientMock);
      IOOverrides.global = MockFs();

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
        createMockWorkspaceFs(
          packages: [
            MockPackageFs(
              name: 'melos',
              version: Version(0, 0, 0),
            ),
          ],
        ),
      );
      workspace = await MelosWorkspace.fromConfig(
        config,
        logger: TestLogger().toMelosLogger(),
      );
    });

    tearDown(() => IOOverrides.global = null);

    tearDownAll(() => testClient = null);

    test('requests published packages from pub.dev by default', () async {
      final uri = Uri.parse('https://pub.dev/api/packages/melos');
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
          final uri = Uri.parse('http://localhost:8080/api/packages/melos');
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

    test(
      'do not request published versions for private package',
      () async {
        final workspaceBuilder = VirtualWorkspaceBuilder('name: test');
        workspaceBuilder.addPackage('''
            name: a
          ''');
        workspaceBuilder.addPackage('''
            name: b
            version: 0.0.0
            publish_to: none
          ''');
        final workspace = workspaceBuilder.build();

        expect(
          await workspace.allPackages['a']!.getPublishedVersions(),
          isEmpty,
        );
        expect(
          await workspace.allPackages['b']!.getPublishedVersions(),
          isEmpty,
        );

        verifyNever(httpClientMock.get(any));
      },
    );
  });

  group('Package', () {
    group('allTransitiveDependenciesInWorkspace', () {
      test('does not included transitive dev dependencies', () {
        final workspaceBuilder = VirtualWorkspaceBuilder('name: test');
        workspaceBuilder.addPackage('''
            name: a
          ''');
        workspaceBuilder.addPackage('''
            name: b
            dev_dependencies:
              a: any
          ''');
        workspaceBuilder.addPackage('''
            name: c
            dependencies:
              b: any
          ''');
        final workspace = workspaceBuilder.build();
        final cPackage = workspace.allPackages['c']!;
        expect(cPackage.allTransitiveDependenciesInWorkspace.keys, ['b']);
      });
    });
  });

  group('PackageFilters', () {
    test('default', () {
      final filters = PackageFilters();

      expect(filters.dependsOn, isEmpty);
      expect(filters.noDependsOn, isEmpty);
      expect(filters.dirExists, isEmpty);
      expect(filters.fileExists, isEmpty);
      expect(filters.ignore, isEmpty);
      expect(filters.scope, isEmpty);
      expect(filters.includeDependencies, false);
      expect(filters.includeDependents, false);
      expect(filters.includePrivatePackages, null);
      expect(filters.nullSafe, null);
      expect(filters.published, null);
      expect(filters.diff, null);
    });

    group('copyWithWithDiff', () {
      test('can assign null', () {
        final filters = PackageFilters(diff: '123');

        expect(filters.copyWithDiff(null).diff, null);
      });

      test('clone properties besides diff', () {
        final filters = PackageFilters(
          dependsOn: const ['a'],
          dirExists: const ['a'],
          fileExists: const ['a'],
          flutter: true,
          scope: [Glob('a')],
          ignore: [Glob('a')],
          includeDependencies: true,
          includeDependents: true,
          includePrivatePackages: false,
          noDependsOn: const ['a'],
          nullSafe: true,
          published: true,
          diff: '123',
        );

        final copy = filters.copyWithDiff('456');

        expect(copy.diff, '456');
        expect(copy.dependsOn, filters.dependsOn);
        expect(copy.dirExists, filters.dirExists);
        expect(copy.fileExists, filters.fileExists);
        expect(copy.scope, filters.scope);
        expect(copy.ignore, filters.ignore);
        expect(copy.includeDependencies, filters.includeDependencies);
        expect(copy.includeDependents, filters.includeDependents);
        expect(copy.includePrivatePackages, filters.includePrivatePackages);
        expect(copy.noDependsOn, filters.noDependsOn);
        expect(copy.nullSafe, filters.nullSafe);
        expect(copy.published, filters.published);
      });
    });
  });
}

void testDependencyVersionReplaceRegex(String version) {
  test(version, () {
    const dependencyName = 'foo';
    const newVersion = '9.9.9';

    final regExp = dependencyVersionReplaceRegex(dependencyName);

    final input = '''
dependencies:
  $dependencyName: $version
''';
    final output = input.replaceAllMapped(
      regExp,
      (match) => '${match.group(1)}$newVersion',
    );

    expect(output, '''
dependencies:
  $dependencyName: $newVersion
''');
  });
}

void testHostedDependencyVersionReplaceRegex(String version) {
  test(version, () {
    const dependencyName = 'foo';
    const newVersion = '9.9.9';

    final regExp = hostedDependencyVersionReplaceRegex(dependencyName);

    final input = '''
dependencies:
  $dependencyName:
    version: $version
''';
    final output = input.replaceAllMapped(
      regExp,
      (match) => '${match.group(1)}$newVersion',
    );

    expect(output, '''
dependencies:
  $dependencyName:
    version: $newVersion
''');
  });
}

void testDependencyTagReplaceRegex(String version) {
  test(version, () {
    const dependencyName = 'foo';
    const newVersion = '9.9.9';

    final regExp = dependencyTagReplaceRegex(dependencyName);

    final input = '''
dependencies:
  $dependencyName:
    git:
      ref: $dependencyName-v$version
''';
    final output = input.replaceAllMapped(
      regExp,
      (match) => '${match.group(1)}$dependencyName-v$newVersion',
    );

    expect(output, '''
dependencies:
  $dependencyName:
    git:
      ref: $dependencyName-v$newVersion
''');
  });
}
