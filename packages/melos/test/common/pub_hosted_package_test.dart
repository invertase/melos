import 'package:melos/src/common/pub_hosted_package.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

PubHostedPackage _package(List<(String, String?)> versions) {
  return PubHostedPackage.fromJson({
    'name': 'melos',
    'latest': {'version': versions.last.$1},
    'versions': [
      for (final (version, sdk) in versions)
        {
          'version': version,
          if (sdk != null)
            'pubspec': {
              'environment': {'sdk': sdk},
            },
        },
    ],
  });
}

void main() {
  group('PubPackageVersion.fromJson', () {
    test('parses the SDK constraint from the pubspec environment', () {
      final version = PubPackageVersion.fromJson({
        'version': '6.3.3',
        'pubspec': {
          'environment': {'sdk': '^3.8.0'},
        },
      });

      expect(version.version, Version.parse('6.3.3'));
      expect(version.sdkConstraint, VersionConstraint.parse('^3.8.0'));
    });

    test('leaves the SDK constraint null when absent', () {
      final version = PubPackageVersion.fromJson({'version': '6.3.2'});
      expect(version.sdkConstraint, isNull);
    });

    test('leaves the SDK constraint null when malformed', () {
      final version = PubPackageVersion.fromJson({
        'version': '6.3.2',
        'pubspec': {
          'environment': {'sdk': 'not-a-constraint'},
        },
      });
      expect(version.sdkConstraint, isNull);
    });
  });

  group('PubHostedPackage.newestCompatibleUpdate', () {
    test('does not suggest a version that requires a newer Dart SDK', () {
      final package = _package([
        ('6.3.2', '>=3.2.0 <4.0.0'),
        ('6.3.3', '^3.8.0'),
      ]);

      final update = package.newestCompatibleUpdate(
        currentVersion: Version.parse('6.3.2'),
        dartSdkVersion: Version.parse('3.7.2'),
      );

      expect(update, isNull);
    });

    test('suggests the newest version compatible with the Dart SDK', () {
      final package = _package([
        ('6.3.2', '>=3.2.0 <4.0.0'),
        ('6.3.3', '^3.8.0'),
      ]);

      final update = package.newestCompatibleUpdate(
        currentVersion: Version.parse('6.3.2'),
        dartSdkVersion: Version.parse('3.8.1'),
      );

      expect(update?.version, Version.parse('6.3.3'));
    });

    test('picks the newest compatible version, skipping incompatible ones', () {
      final package = _package([
        ('6.3.2', '>=3.2.0 <4.0.0'),
        ('6.3.3', '>=3.4.0 <4.0.0'),
        ('6.3.4', '^3.8.0'),
      ]);

      final update = package.newestCompatibleUpdate(
        currentVersion: Version.parse('6.3.2'),
        dartSdkVersion: Version.parse('3.7.2'),
      );

      expect(update?.version, Version.parse('6.3.3'));
    });

    test('returns null when already on the newest compatible version', () {
      final package = _package([
        ('6.3.2', '>=3.2.0 <4.0.0'),
        ('6.3.3', '^3.8.0'),
      ]);

      final update = package.newestCompatibleUpdate(
        currentVersion: Version.parse('6.3.3'),
        dartSdkVersion: Version.parse('3.8.1'),
      );

      expect(update, isNull);
    });

    test('treats a missing SDK constraint as compatible', () {
      final package = _package([
        ('6.3.2', '>=3.2.0 <4.0.0'),
        ('6.3.3', null),
      ]);

      final update = package.newestCompatibleUpdate(
        currentVersion: Version.parse('6.3.2'),
        dartSdkVersion: Version.parse('3.7.2'),
      );

      expect(update?.version, Version.parse('6.3.3'));
    });

    test('never suggests pre-release versions', () {
      final package = _package([
        ('6.3.2', '>=3.2.0 <4.0.0'),
        ('7.0.0-dev.1', '>=3.2.0 <4.0.0'),
      ]);

      final update = package.newestCompatibleUpdate(
        currentVersion: Version.parse('6.3.2'),
        dartSdkVersion: Version.parse('3.7.2'),
      );

      expect(update, isNull);
    });

    test('does not nag pre-release users about stable releases', () {
      final package = _package([
        ('7.0.0-dev.1', '>=3.2.0 <4.0.0'),
        ('7.0.0', '>=3.2.0 <4.0.0'),
      ]);

      final update = package.newestCompatibleUpdate(
        currentVersion: Version.parse('7.0.0-dev.1'),
        dartSdkVersion: Version.parse('3.7.2'),
      );

      expect(update, isNull);
    });
  });
}
