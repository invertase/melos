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
import 'package:pub_semver/pub_semver.dart';

bool isValidVersion(String version) {
  try {
    Version.parse(version);
    return true;
  } catch (e) {
    return false;
  }
}

Version nextStableVersion(
  Version currentVersion,
  SemverReleaseType releaseType,
) {
  // For simplicity's sake, we avoid using + after the version reaches 1.0.0.
  if (currentVersion.major > 0) {
    switch (releaseType) {
      case SemverReleaseType.major:
        return currentVersion.nextBreaking;
      case SemverReleaseType.minor:
        return currentVersion.nextMinor;
      case SemverReleaseType.patch:
      default:
        return currentVersion.nextPatch;
    }
  }

  // Although semantic versioning doesn't promise any compatibility between versions prior to 1.0.0,
  // the Dart community convention is to treat those versions semantically as well. The interpretation
  // of each number is just shifted down one slot:
  //   - going from 0.1.2 to 0.2.0 indicates a breaking change
  //   - going to 0.1.3 indicates a new feature
  //   - going to 0.1.2+1 indicates a change that doesn't affect the public API
  switch (releaseType) {
    case SemverReleaseType.major:
      return currentVersion.nextMinor;
    case SemverReleaseType.minor:
      return currentVersion.nextPatch;
    case SemverReleaseType.patch:
    default:
      // Bump the build number, or set it if it does not exist.
      final currentBuild =
          currentVersion.build.length == 1 ? currentVersion.build[0] as int : 0;
      return Version(
        currentVersion.major,
        currentVersion.minor,
        currentVersion.patch,
        build: (currentBuild + 1).toString(),
      );
  }
}

Version nextPrereleaseVersion(
  Version currentVersion,
  SemverReleaseType releaseType, {
  String? preid,
}) {
  if (currentVersion.isPreRelease) {
    final currentPre = currentVersion.preRelease.length == 2
        ? currentVersion.preRelease[1] as int
        : -1;
    // Note we preserve the current prereleases preid if no preid option specified.
    // So 1.0.0-nullsafety.0 would become ...-nullsafety.X rather than use the default preid "dev".
    var nextPreidInt = currentPre + 1;
    final nextPreidName = preid ?? currentVersion.preRelease[0] as String;

    // Reset the preid int if preid name has changed,
    // e.g. was "...dev.3" and is now a "nullsafety" preid so the next
    // prerelease version becomes "...nullsafety.0" instead of "...nullsafety.4".
    if (nextPreidName != currentVersion.preRelease[0]) {
      nextPreidInt = 0;
    }

    return Version(
      currentVersion.major,
      currentVersion.minor,
      currentVersion.patch,
      pre: '$nextPreidName.$nextPreidInt',
    );
  }

  final nextVersion = nextStableVersion(currentVersion, releaseType);
  return Version(
    nextVersion.major,
    nextVersion.minor,
    nextVersion.patch,
    pre: '$preid.0',
    build: nextVersion.build.isNotEmpty ? nextVersion.build.join('.') : null,
  );
}

Version nextVersion(
  Version currentVersion,
  SemverReleaseType releaseType, {
  bool graduate = false,
  bool prerelease = false,
  String? preid,
}) {
  var requestedPreidOrDefault = preid ?? 'dev';
  final shouldGraduate = graduate;
  var shouldMakePreRelease = prerelease;
  if (currentVersion.preRelease.isNotEmpty) {
    // If the current version then we should make a prerelease, unless graduating
    // the version is explicitly requested.
    shouldMakePreRelease = !shouldGraduate;
    // Extract the existing preid from prerelease list if no preid provided.
    // We do this to preserve the current preid so it's not overridden with the
    // default 'dev' preid.
    if (preid == null) {
      //  - Versions in the format `0.8.0-nullsafety.1` have 2 pre release items, so we extract 'nullsafety' preid.
      //  - Versions in the format `0.2.0-1.2.nullsafety.4` have 2 pre release items, so we extract 'nullsafety' preid.
      requestedPreidOrDefault = currentVersion.preRelease.length == 2
          ? currentVersion.preRelease[0] as String
          : currentVersion.preRelease[2] as String;
    }
  }

  // Prerelease graduating to stable. Includes nullsafety graduation.
  if (currentVersion.isPreRelease && shouldGraduate) {
    return Version(
      currentVersion.major,
      currentVersion.minor,
      currentVersion.patch,
      build: currentVersion.build.isNotEmpty
          ? currentVersion.build.join('.')
          : null,
    );
  }

  // Non-prerelease to non-prerelease versioning.
  if (!currentVersion.isPreRelease && !shouldMakePreRelease) {
    return nextStableVersion(currentVersion, releaseType);
  }

  // Non-prerelease to prerelease versioning (excluding nullsafety).
  if (!currentVersion.isPreRelease &&
      shouldMakePreRelease &&
      requestedPreidOrDefault != 'nullsafety') {
    return nextPrereleaseVersion(
      currentVersion,
      releaseType,
      preid: requestedPreidOrDefault,
    );
  }

  // Prerelease to prerelease versioning (excluding nullsafety).
  if (currentVersion.isPreRelease &&
      shouldMakePreRelease &&
      requestedPreidOrDefault != 'nullsafety') {
    return nextPrereleaseVersion(
      currentVersion,
      releaseType,
      preid: requestedPreidOrDefault,
    );
  }

  // Nullsafety
  // Non-prerelease version to a first time nullsafety release.
  if (!currentVersion.isPreRelease &&
      shouldMakePreRelease &&
      requestedPreidOrDefault == 'nullsafety') {
    // Going from non-null to a first nullsafety release then the convention here
    // is that a major version is created regardless of the requested release type.
    final nextMajorStable =
        nextStableVersion(currentVersion, SemverReleaseType.major);

    return Version(
      nextMajorStable.major,
      nextMajorStable.minor,
      nextMajorStable.patch,
      pre: '1.0.nullsafety.0',
      build: nextMajorStable.build.isNotEmpty
          ? nextMajorStable.build.join('.')
          : null,
    );
  }

  // Non-nullsafety prerelease (or a nullsafety prerelease in the format
  // '0.8.0-nullsafety.1`) to a nullsafety prerelease.
  // Versions in the format `0.8.0-nullsafety.1` have 2 pre release items.
  if (currentVersion.isPreRelease &&
      currentVersion.preRelease.length == 2 &&
      shouldMakePreRelease &&
      requestedPreidOrDefault == 'nullsafety') {
    // Going from non-nullsafety prerelease to a first nullsafety release then
    // the convention here is that a major version is created regardless of the
    // requested release type.
    var baseVersion =
        nextStableVersion(currentVersion, SemverReleaseType.major);
    // Otherwise if it's already an old format nullsafety prerelease version
    // then use the current version and don't major version bump it.
    if (currentVersion.preRelease[0] == 'nullsafety') {
      baseVersion = currentVersion;
    } else if (currentVersion.major == 0) {
      // Bump the 'major' version again if the preids changed (e.g. dev to nullsafety)
      // and the current version is not yet full semver (>= 1.0.0), e.g.:
      // `0.1.0-dev.5` should become `0.2.0-1.0.nullsafety.0`
      // and not `0.1.0-1.0.nullsafety.0`.
      // >=1.0.0 is already handled by [nextStableVersion].
      baseVersion = nextStableVersion(baseVersion, SemverReleaseType.major);
    }

    return Version(
      baseVersion.major,
      baseVersion.minor,
      baseVersion.patch,
      pre: '1.0.nullsafety.0',
      build: baseVersion.build.isNotEmpty ? baseVersion.build.join('.') : null,
    );
  }

  // Nullsafety prerelease to another nullsafety prerelease.
  // Existing nullsafety prerelease version is expected to be in the format
  // `0.2.0-1.2.nullsafety.4` - versions in this format have 4 prerelease items.
  if (currentVersion.isPreRelease &&
      currentVersion.preRelease.length == 4 &&
      currentVersion.preRelease[2] == 'nullsafety' &&
      requestedPreidOrDefault == 'nullsafety') {
    // e.g. for 0.2.0-1.2.nullsafety.4 then currentVersion.preRelease is in the format:
    // [1, 2, nullsafety, 4] so this equates to [major, minor, preid, patch].
    var nextPreMajor = currentVersion.preRelease[0] as int;
    var nextPreMinor = currentVersion.preRelease[1] as int;
    var nextPrePatch = currentVersion.preRelease[3] as int;
    switch (releaseType) {
      case SemverReleaseType.major:
        nextPreMajor++;
        nextPreMinor = 0;
        nextPrePatch = 0;
        break;
      case SemverReleaseType.minor:
        nextPreMinor++;
        nextPrePatch = 0;
        break;
      case SemverReleaseType.patch:
      default:
        nextPrePatch++;
        break;
    }
    return Version(
      currentVersion.major,
      currentVersion.minor,
      currentVersion.patch,
      pre: '$nextPreMajor.$nextPreMinor.$requestedPreidOrDefault.$nextPrePatch',
      build: currentVersion.build.isNotEmpty
          ? currentVersion.build.join('.')
          : null,
    );
  }

  // Unhandled versioning behaviour.
  throw UnsupportedError(
    'Incrementing the version $currentVersion with the following options '
    '(graduate: $graduate, preid: $preid, prerelease: $prerelease, releaseType: $releaseType) '
    'is not supported by Melos, please raise an issue on GitHub if this is unexpected behaviour.',
  );
}

Version incrementBuildNumber(Version currentVersion) {
  final build = currentVersion.build;

  int? nextBuildNumber;
  if (build.isEmpty) {
    nextBuildNumber = 0;
  } else if (build.length == 1) {
    final Object? buildNumber = build.first;
    if (buildNumber is int) {
      nextBuildNumber = buildNumber + 1;
    }
  }

  if (nextBuildNumber != null) {
    return Version(
      currentVersion.major,
      currentVersion.minor,
      currentVersion.patch,
      build: nextBuildNumber.toString(),
    );
  }

  throw ArgumentError(
    'Cannot increment build number for version $currentVersion',
  );
}

class ManualVersionChange {
  factory ManualVersionChange(Version version) =>
      ManualVersionChange._((_) => version);

  ManualVersionChange._(this._impl);

  factory ManualVersionChange.incrementBySemverReleaseType(
    SemverReleaseType releaseType,
  ) =>
      ManualVersionChange._(
        (currentVersion) => nextVersion(currentVersion, releaseType),
      );

  factory ManualVersionChange.incrementBuildNumber() =>
      ManualVersionChange._(incrementBuildNumber);

  final Version Function(Version) _impl;

  Version call(Version currentVersion) => _impl(currentVersion);
}
