/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'package:conventional_commit/conventional_commit.dart';
import 'package:melos/src/common/versioning.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

class TestCase {
  const TestCase(
    this.currentVersion,
    this.expectedVersion,
    this.requestedReleaseType, {
    this.requestedPreId,
    this.shouldMakeGraduateVersion = false,
    this.shouldMakePrereleaseVersion = false,
  });

  final String currentVersion;
  final String expectedVersion;
  final String? requestedPreId;
  final SemverReleaseType requestedReleaseType;
  final bool shouldMakePrereleaseVersion;
  final bool shouldMakeGraduateVersion;

  @override
  String toString() {
    return 'TestCase[$currentVersion => $expectedVersion ($requestedReleaseType)]\n  { '
        'shouldMakePrereleaseVersion:$shouldMakePrereleaseVersion, '
        'shouldMakeGraduateVersion:$shouldMakeGraduateVersion, '
        'requestedPreId:$requestedPreId '
        '};';
  }
}

class NullSafetyTestCase extends TestCase {
  const NullSafetyTestCase(
    String currentVersion,
    String expectedVersion,
    SemverReleaseType requestedReleaseType,
  ) : super(
          currentVersion,
          expectedVersion,
          requestedReleaseType,
          requestedPreId: 'nullsafety',
          shouldMakePrereleaseVersion: true,
        );
}

const _versioningTestCases = [
  // Semantic versioning compatible.
  TestCase('1.0.0', '2.0.0', SemverReleaseType.major),
  TestCase('1.0.0', '1.1.0', SemverReleaseType.minor),
  TestCase('1.0.0', '1.0.1', SemverReleaseType.patch),
  TestCase('1.1.1', '2.0.0', SemverReleaseType.major),
  TestCase('1.1.1', '1.2.0', SemverReleaseType.minor),
  TestCase('1.1.1', '1.1.2', SemverReleaseType.patch),
  TestCase(
    '1.0.0',
    '2.0.0-dev.0',
    SemverReleaseType.major,
    shouldMakePrereleaseVersion: true,
  ),
  TestCase(
    '1.0.0',
    '1.1.0-dev.0',
    SemverReleaseType.minor,
    shouldMakePrereleaseVersion: true,
  ),
  TestCase(
    '1.0.0',
    '1.0.1-dev.0',
    SemverReleaseType.patch,
    shouldMakePrereleaseVersion: true,
  ),

  // Although semantic versioning doesn't promise any compatibility between versions prior to 1.0.0,
  // the Dart community convention is to treat those versions semantically as well. The interpretation
  // of each number is just shifted down one slot
  TestCase('0.1.0', '0.2.0', SemverReleaseType.major),
  TestCase('0.1.0', '0.1.1', SemverReleaseType.minor),
  TestCase('0.1.0', '0.1.0+1', SemverReleaseType.patch),
  TestCase('0.1.1+1', '0.2.0', SemverReleaseType.major),
  TestCase('0.1.1+1', '0.1.2', SemverReleaseType.minor),
  TestCase('0.1.1+1', '0.1.1+2', SemverReleaseType.patch),
  TestCase(
    '0.1.0',
    '0.2.0-dev.0',
    SemverReleaseType.major,
    shouldMakePrereleaseVersion: true,
  ),
  TestCase(
    '0.1.0',
    '0.1.1-dev.0',
    SemverReleaseType.minor,
    shouldMakePrereleaseVersion: true,
  ),
  TestCase(
    '0.1.0',
    '0.1.0-dev.0+1',
    SemverReleaseType.patch,
    shouldMakePrereleaseVersion: true,
  ),

  // Ensure that we reset the preid int if preid name has changed,
  // e.g. was "...dev.3" and is now a "beta" preid so the next
  // prerelease version becomes "...beta.0" instead of "...beta.4".
  TestCase(
    '1.0.0-dev.3',
    '1.0.0-beta.0',
    SemverReleaseType.patch,
    requestedPreId: 'beta',
    shouldMakePrereleaseVersion: true,
  ),

  // Check that we preserve prerelease status, e.g. if already a prerelease
  // then it should stay as a prerelease and not graduate to a non-prerelease version.
  TestCase('1.0.0-dev.1', '1.0.0-dev.2', SemverReleaseType.patch),
  // It should however graduate if it was specifically requested.
  TestCase(
    '1.0.0-dev.1',
    '1.0.0',
    SemverReleaseType.patch,
    shouldMakeGraduateVersion: true,
  ),
  TestCase(
    '0.1.0-dev.0+1',
    '0.1.0+1',
    SemverReleaseType.patch,
    shouldMakeGraduateVersion: true,
  ),

  // Check that we preserve any current prerelease preid if no preid option specified.
  // So 1.0.0-beta.0 would become ...-beta.X rather than use the default preid "dev".
  TestCase('1.0.0-beta.3', '1.0.0-beta.4', SemverReleaseType.patch),

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

  // Any nullsafety versions using the previous versioning style should get switched over.
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

void main() {
  group('Semantic Versioning', () {
    for (final testCase in _versioningTestCases) {
      test(
          '#${_versioningTestCases.indexOf(testCase)}: the version ${testCase.currentVersion} should increment to ${testCase.expectedVersion}',
          () {
        final newVersion = nextVersion(
          Version.parse(testCase.currentVersion),
          testCase.requestedReleaseType,
          graduate: testCase.shouldMakeGraduateVersion,
          preid: testCase.requestedPreId,
          prerelease: testCase.shouldMakePrereleaseVersion,
        );

        expect(
          newVersion.toString(),
          equals(testCase.expectedVersion),
          reason:
              'The version created did not match the version expected by this test case: $testCase.',
        );
      });
    }
  });
}
