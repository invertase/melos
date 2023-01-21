import 'dart:convert';

import 'package:conventional_commit/conventional_commit.dart';
import 'package:melos/src/common/versioning.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group('ConventionalCommit', () {
    test('isVersionableCommit', () {
      expect(
        ConventionalCommit.tryParse('chore!: foo bar')!.isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('refactor(scope): foo bar')!
            .isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('revert(scope,dope)!: foo bar')!
            .isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('feat(*): foo bar')!.isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('ci(scope,dope): foo bar')!
            .isVersionableCommit,
        isFalse,
      );
      expect(
        ConventionalCommit.tryParse('Merged PR 1337: bar foo')!
            .isVersionableCommit,
        isFalse,
      );
      expect(
        ConventionalCommit.tryParse('Merged PR 1337: fix(1338): bar foo')!
            .isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('Merged PR: fix(*): bar foo')!
            .isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('Merged foo into bar')!.isVersionableCommit,
        isFalse,
      );
    });

    test('semverReleaseType', () {
      expect(
        ConventionalCommit.tryParse('chore!: foo bar')!.semverReleaseType,
        equals(SemverReleaseType.major),
      );
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.semverReleaseType,
        equals(SemverReleaseType.patch),
      );
      expect(
        ConventionalCommit.tryParse('refactor(scope): foo bar')!
            .semverReleaseType,
        equals(SemverReleaseType.patch),
      );
      expect(
        ConventionalCommit.tryParse('feat(scope,dope): foo bar')!
            .semverReleaseType,
        equals(SemverReleaseType.minor),
      );
    });
  });

  group('Semantic Versioning', () {
    for (final testCase in _versioningTestCases) {
      test(
        '#${_versioningTestCases.indexOf(testCase)}: ${testCase.title}',
        testCase.run,
      );
    }
  });
}

abstract class VersioningTestCaseBase {
  const VersioningTestCaseBase(
    this.currentVersion,
    this.requestedReleaseType, {
    this.requestedPreId,
    this.shouldMakeGraduateVersion = false,
    this.shouldMakePrereleaseVersion = false,
  });

  final String currentVersion;
  final String? requestedPreId;
  final SemverReleaseType requestedReleaseType;
  final bool shouldMakePrereleaseVersion;
  final bool shouldMakeGraduateVersion;

  Version resolveNextVersion() {
    return nextVersion(
      Version.parse(currentVersion),
      requestedReleaseType,
      graduate: shouldMakeGraduateVersion,
      preid: requestedPreId,
      prerelease: shouldMakePrereleaseVersion,
    );
  }

  String get title;

  void run();

  @override
  String toString() {
    return jsonEncode(properties());
  }

  Map<String, Object?> properties() {
    return {
      'currentVersion': currentVersion,
      'requestedReleaseType': requestedReleaseType.name,
      if (requestedPreId != null) 'requestedPreId': requestedPreId,
      'shouldMakeGraduateVersion': shouldMakeGraduateVersion,
      'shouldMakePrereleaseVersion': shouldMakePrereleaseVersion,
    };
  }
}

class VersioningTestCase extends VersioningTestCaseBase {
  const VersioningTestCase(
    super.currentVersion,
    this.expectedVersion,
    super.requestedReleaseType, {
    super.requestedPreId,
    super.shouldMakeGraduateVersion,
    super.shouldMakePrereleaseVersion,
  });

  final String? expectedVersion;

  @override
  String get title =>
      'the version $currentVersion should increment to $expectedVersion';

  @override
  void run() {
    expect(
      resolveNextVersion().toString(),
      equals(expectedVersion),
      reason: 'The version created did not match the version expected by '
          'this test case: $this.',
    );
  }

  @override
  Map<String, Object?> properties() {
    return {
      ...super.properties(),
      'expectedVersion': expectedVersion,
    };
  }
}

class NullSafetyTestCase extends VersioningTestCase {
  const NullSafetyTestCase(
    super.currentVersion,
    super.expectedVersion,
    super.requestedReleaseType,
  ) : super(
          requestedPreId: 'nullsafety',
          shouldMakePrereleaseVersion: true,
        );
}

class UnsupportedPreReleaseTestCase extends VersioningTestCaseBase {
  const UnsupportedPreReleaseTestCase(String currentVersion)
      : super(
          currentVersion,
          SemverReleaseType.patch,
          shouldMakePrereleaseVersion: true,
        );

  @override
  String get title => 'the version $currentVersion should be unsupported';

  @override
  void run() {
    expect(
      resolveNextVersion,
      throwsA(isA<UnsupportedError>()),
      reason: 'Creating a new version should have thrown an exception, '
          'but it did not: $this.',
    );
  }
}

const _versioningTestCases = [
  // Semantic versioning compatible.
  VersioningTestCase('1.0.0', '2.0.0', SemverReleaseType.major),
  VersioningTestCase('1.0.0', '1.1.0', SemverReleaseType.minor),
  VersioningTestCase('1.0.0', '1.0.1', SemverReleaseType.patch),
  VersioningTestCase('1.1.1', '2.0.0', SemverReleaseType.major),
  VersioningTestCase('1.1.1', '1.2.0', SemverReleaseType.minor),
  VersioningTestCase('1.1.1', '1.1.2', SemverReleaseType.patch),
  VersioningTestCase(
    '1.0.0',
    '2.0.0-dev.0',
    SemverReleaseType.major,
    shouldMakePrereleaseVersion: true,
  ),
  VersioningTestCase(
    '1.0.0',
    '1.1.0-dev.0',
    SemverReleaseType.minor,
    shouldMakePrereleaseVersion: true,
  ),
  VersioningTestCase(
    '1.0.0',
    '1.0.1-dev.0',
    SemverReleaseType.patch,
    shouldMakePrereleaseVersion: true,
  ),
  UnsupportedPreReleaseTestCase('1.0.0-a'),
  UnsupportedPreReleaseTestCase('1.0.0-a.a'),
  UnsupportedPreReleaseTestCase('1.0.0-0.0.0'),
  UnsupportedPreReleaseTestCase('1.0.0-0.0.0.0'),
  UnsupportedPreReleaseTestCase('1.0.0-a.0.nullsafety.0'),
  UnsupportedPreReleaseTestCase('1.0.0-0.a.nullsafety.0'),
  UnsupportedPreReleaseTestCase('1.0.0-0.0.nullsafety.a'),

  // Although semantic versioning doesn't promise any compatibility between
  // versions prior to 1.0.0, the Dart community convention is to treat those
  // versions semantically as well. The interpretation of each number is just
  // shifted down one slot
  VersioningTestCase('0.1.0', '0.2.0', SemverReleaseType.major),
  VersioningTestCase('0.1.0', '0.1.1', SemverReleaseType.minor),
  VersioningTestCase(
    '0.1.0',
    '0.1.0+1',
    SemverReleaseType.patch,
  ),
  VersioningTestCase(
    '0.1.1+1',
    '0.2.0',
    SemverReleaseType.major,
  ),
  VersioningTestCase(
    '0.1.1+1',
    '0.1.2',
    SemverReleaseType.minor,
  ),
  VersioningTestCase(
    '0.1.1+1',
    '0.1.1+2',
    SemverReleaseType.patch,
  ),
  VersioningTestCase(
    '0.1.0',
    '0.2.0-dev.0',
    SemverReleaseType.major,
    shouldMakePrereleaseVersion: true,
  ),
  VersioningTestCase(
    '0.1.0',
    '0.1.1-dev.0',
    SemverReleaseType.minor,
    shouldMakePrereleaseVersion: true,
  ),
  VersioningTestCase(
    '0.1.0',
    '0.1.0-dev.0+1',
    SemverReleaseType.patch,
    shouldMakePrereleaseVersion: true,
  ),

  // Ensure that we reset the preid int if preid name has changed,
  // e.g. was "...dev.3" and is now a "beta" preid so the next
  // prerelease version becomes "...beta.0" instead of "...beta.4".
  VersioningTestCase(
    '1.0.0-dev.3',
    '1.0.0-beta.0',
    SemverReleaseType.patch,
    requestedPreId: 'beta',
    shouldMakePrereleaseVersion: true,
  ),

  // Check that we preserve prerelease status, e.g. if already a prerelease
  // then it should stay as a prerelease and not graduate to a non-prerelease
  // version.
  VersioningTestCase(
    '1.0.0-dev.1',
    '1.0.0-dev.2',
    SemverReleaseType.patch,
  ),
  // It should however graduate if it was specifically requested.
  VersioningTestCase(
    '1.0.0-dev.1',
    '1.0.0',
    SemverReleaseType.patch,
    shouldMakeGraduateVersion: true,
  ),
  VersioningTestCase(
    '0.1.0-dev.0+1',
    '0.1.0+1',
    SemverReleaseType.patch,
    shouldMakeGraduateVersion: true,
  ),

  // Check that we preserve any current prerelease preid if no preid option
  // specified. So 1.0.0-beta.0 would become ...-beta.X rather than use the
  // default preid "dev".
  VersioningTestCase(
    '1.0.0-beta.3',
    '1.0.0-beta.4',
    SemverReleaseType.patch,
  ),

  // Nullsafety
  //  - Going from non-null to a first nullsafety release.
  //  - Convention here is that a major version is created regardless of the
  //    underlying change/release type.
  NullSafetyTestCase(
    '1.0.0',
    '2.0.0-1.0.nullsafety.0',
    SemverReleaseType.major,
  ),
  NullSafetyTestCase(
    '1.1.0',
    '2.0.0-1.0.nullsafety.0',
    SemverReleaseType.minor,
  ),
  NullSafetyTestCase(
    '1.0.1',
    '2.0.0-1.0.nullsafety.0',
    SemverReleaseType.patch,
  ),
  // Semantic versioning compatibility between versions prior to 1.0.0,
  NullSafetyTestCase(
    '0.1.0',
    '0.2.0-1.0.nullsafety.0',
    SemverReleaseType.major,
  ),
  NullSafetyTestCase(
    '0.1.1',
    '0.2.0-1.0.nullsafety.0',
    SemverReleaseType.minor,
  ),
  NullSafetyTestCase(
    '0.1.0+1',
    '0.2.0-1.0.nullsafety.0',
    SemverReleaseType.patch,
  ),

  // Nullsafety
  // - Here we're going from a already nullsafety version to another one.
  NullSafetyTestCase(
    '2.0.0-1.2.nullsafety.0',
    '2.0.0-2.0.nullsafety.0',
    SemverReleaseType.major,
  ),
  NullSafetyTestCase(
    '2.0.0-1.2.nullsafety.3',
    '2.0.0-1.3.nullsafety.0',
    SemverReleaseType.minor,
  ),
  NullSafetyTestCase(
    '2.0.0-1.2.nullsafety.3',
    '2.0.0-1.2.nullsafety.4',
    SemverReleaseType.patch,
  ),
  // Semantic versioning compatibility between versions prior to 1.0.0,
  NullSafetyTestCase(
    '0.2.0-1.2.nullsafety.3',
    '0.2.0-2.0.nullsafety.0',
    SemverReleaseType.major,
  ),
  NullSafetyTestCase(
    '0.2.0-1.2.nullsafety.3',
    '0.2.0-1.3.nullsafety.0',
    SemverReleaseType.minor,
  ),
  NullSafetyTestCase(
    '0.2.0-1.2.nullsafety.3',
    '0.2.0-1.2.nullsafety.4',
    SemverReleaseType.patch,
  ),

  // Any nullsafety versions using the previous versioning style should get
  //switched over.
  NullSafetyTestCase(
    '0.8.0-nullsafety.1',
    '0.8.0-1.0.nullsafety.0',
    SemverReleaseType.major,
  ),
  NullSafetyTestCase(
    '1.2.0-nullsafety.0',
    '1.2.0-1.0.nullsafety.0',
    SemverReleaseType.major,
  ),

  // Non-nullsafety prerelease to a nullsafety prerelease.
  NullSafetyTestCase(
    '1.0.0-dev.3',
    '2.0.0-1.0.nullsafety.0',
    SemverReleaseType.patch,
  ),
  NullSafetyTestCase(
    '0.1.0-dev.5',
    '0.2.0-1.0.nullsafety.0',
    SemverReleaseType.patch,
  ),
];
