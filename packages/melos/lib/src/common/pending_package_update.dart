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

import 'dart:math' as math;

import 'package:conventional_commit/conventional_commit.dart';
import 'package:pub_semver/pub_semver.dart';

import 'changelog.dart';
import 'package.dart';

/// Enum representing why the version has been changed when running 'version' command.
enum PackageUpdateReason {
  /// Changed due to a commit modifying code in this package.
  commit,

  /// Changed due to another package that this package depends on being updated.
  dependency,

  /// Package is being graduated to a stable version from a prerelease.
  graduate,
}

class MelosPendingPackageUpdate {
  /// Commits that triggered this pending update. Can be empty if
  /// [PackageUpdateReason] is [PackageUpdateReason.dependency].
  final List<ConventionalCommit> commits;

  /// The package that this update will apply to when committed.
  final MelosPackage package;

  /// A reason why this package needs updating.
  final PackageUpdateReason reason;

  /// Whether the next package version will be made a prerelease version.
  final bool prerelease;

  /// If true and the package is currently a prerelease version, the next package version
  /// will graduate to a stable, non-prerelease version.
  final bool graduate;

  /// The prerelease id that will be used for prereleases, e.g. "0.1.0-[preid].1".
  final String preid;

  MelosPendingPackageUpdate(
    this.package,
    this.commits,
    this.reason, {
    this.prerelease = false,
    this.graduate = false,
    this.preid,
  });

  Changelog get changelog {
    // TODO change log styles can be changed here if supported in future.
    return MelosChangelog(this);
  }

  /// Current version specified in the packages pubspec.yaml.
  Version get currentVersion {
    return package.version;
  }

  /// Returns the next stable version based on the commits in this
  Version get nextStableRelease {
    // For simplicity's sake, we avoid using + after the version reaches 1.0.0.
    if (currentVersion.major > 0) {
      switch (semverReleaseType) {
        case SemverReleaseType.major:
          return currentVersion.nextBreaking;
        case SemverReleaseType.minor:
          return currentVersion.nextMinor;
        case SemverReleaseType.patch:
        default:
          return currentVersion.nextPatch;
      }
    } else {
      // Although semantic versioning doesn't promise any compatibility between versions prior to 1.0.0,
      // the Dart community convention is to treat those versions semantically as well. The interpretation
      // of each number is just shifted down one slot:
      //   - going from 0.1.2 to 0.2.0 indicates a breaking change
      //   - going to 0.1.3 indicates a new feature
      //   - going to 0.1.2+1 indicates a change that doesn't affect the public API
      switch (semverReleaseType) {
        case SemverReleaseType.major:
          return currentVersion.nextMinor;
        case SemverReleaseType.minor:
          return currentVersion.nextPatch;
        case SemverReleaseType.patch:
        default:
          // Bump the build number, or set it if it does not exist.
          int currentBuild = currentVersion.build.length == 1
              ? currentVersion.build[0] as int
              : 0;
          return Version(
            currentVersion.major,
            currentVersion.minor,
            currentVersion.patch,
            build: (currentBuild + 1).toString(),
          );
      }
    }
  }

  Version get nextPreRelease {
    if (currentVersion.isPreRelease) {
      int currentPre = currentVersion.preRelease.length == 2
          ? currentVersion.preRelease[1] as int
          : -1;
      // Note we preserve the current prereleases preid if no preid option specified.
      // So 1.0.0-nullsafety.0 would become ...-nullsafety.X rather than use the default preid "dev".
      int nextPreidInt = currentPre + 1;
      String nextPreidName = preid ?? currentVersion.preRelease[0] as String;

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

    var nextVersion = nextStableRelease;
    return Version(
      nextVersion.major,
      nextVersion.minor,
      nextVersion.patch,
      pre: '${preid ?? 'dev'}.0',
    );
  }

  /// Next pub version that will occur as part of this package update.
  Version get nextVersion {
    if (reason == PackageUpdateReason.graduate) {
      return Version(
        currentVersion.major,
        currentVersion.minor,
        currentVersion.patch,
      );
    }

    if (currentVersion.isPreRelease && graduate) {
      return nextStableRelease;
    } else if (currentVersion.isPreRelease) {
      return nextPreRelease;
    } else if (prerelease) {
      return nextPreRelease;
    }

    return nextStableRelease;
  }

  /// Taking into account all the commits in this update, what is the highest [SemverReleaseType].
  SemverReleaseType get semverReleaseType {
    if (reason == PackageUpdateReason.dependency) {
      // Version bumps for dependencies should be patches.
      // If the dependencies had breaking changes then this package would have had commits to update it separately.
      return SemverReleaseType.patch;
    }

    if (reason == PackageUpdateReason.graduate) {
      if (currentVersion.patch != 0 && currentVersion.minor == 0) {
        return SemverReleaseType.patch;
      }
      if (currentVersion.patch == 0 && currentVersion.minor != 0) {
        return SemverReleaseType.minor;
      }
      return SemverReleaseType.major;
    }

    return SemverReleaseType.values[commits
        .map((e) => e.semverReleaseType.index)
        .toList()
        .reduce(math.max)];
  }

  @override
  bool operator ==(Object other) {
    return other is MelosPendingPackageUpdate &&
        other.package.name == package.name;
  }

  @override
  String toString() {
    return 'MelosPendingPackageUpdate(packageName: ${package.name}, semverType: $semverReleaseType, currentVersion: $currentVersion, nextVersion: $nextVersion)';
  }

  @override
  int get hashCode => package.name.hashCode;
}
