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
import 'package:pub_semver/pub_semver.dart';

import 'conventional_commit.dart';
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

  final MelosPackage package;

  final PackageUpdateReason reason;

  final bool prerelease;

  final bool graduate;

  final String preId;

  MelosPendingPackageUpdate(this.package,
      this.commits,
      this.reason, {
        this.prerelease = false,
        this.graduate = false,
        this.preId = 'dev',
      });

  /// Current pub version.
  Version get currentVersion {
    return package.version;
  }

  Version get nextRelease {
    // For simplicity's sake, avoid using + after the version reaches 1.0.0.
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
          int currentBuild = currentVersion.build.length == 1
              ? currentVersion.build[0] as int
              : 0;
          return Version(
              currentVersion.major, currentVersion.minor, currentVersion.patch,
              build: (currentBuild + 1).toString());
      }
    }
  }

  Version get nextPreRelease {
    if (currentVersion.isPreRelease) {
      int currentPre = currentVersion.preRelease.length == 2
          ? currentVersion.preRelease[1] as int
          : 0;
      return Version(
          currentVersion.major, currentVersion.minor, currentVersion.patch,
          pre: '$preId.${currentPre + 1}');
    }

    var nextVersion = nextRelease;
    return Version(nextVersion.major, nextVersion.minor, nextVersion.patch,
        pre: '$preId.1');
  }

  /// Next pub version that will occur as part of this package update.
  Version get pendingVersion {
    if (reason == PackageUpdateReason.graduate) {
      return Version(
          currentVersion.major, currentVersion.minor, currentVersion.patch);
    }

    if (currentVersion.isPreRelease && graduate) {
      return nextRelease;
    } else if (currentVersion.isPreRelease) {
      return nextPreRelease;
    } else if (prerelease) {
      return nextPreRelease;
    }

    return nextRelease;
  }

  /// Taking into account all the commits in this update, what is the highest [SemverReleaseType].
  SemverReleaseType get semverReleaseType {
    if (reason == PackageUpdateReason.dependency) {
      // Version bumps for dependencies should be patches.
      // If the dependencies had breaking changes then this package would have had commits to update it seperately.
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

  String get changelogContents {
    return '$changelogHeader\n\n - ${changelogEntries.join('\n - ')}\n';
  }

  String get changelogHeader {
    return '## $pendingVersion';
  }

  List<String> get changelogEntries {
    if (reason == PackageUpdateReason.dependency) {
      return ['Update a dependency to the latest release.'];
    }

    if (reason == PackageUpdateReason.graduate) {
      return [
        'Graduate package to a stable release. See pre-releases prior to this version for changelog entries.'
      ];
    }

    List<ConventionalCommit> entries = List.from(commits);

    entries.sort((a, b) {
      var r = a.isBreakingChange
          .toString()
          .compareTo(b.isBreakingChange.toString());
      if (r != 0) return r;
      return b.type.compareTo(a.type);
    });

    return entries.map((commit) {
      String entry;
      if (commit.isMergeCommit) {
        entry = commit.header;
      } else {
        entry = '**${commit.type.toUpperCase()}**: ${commit.subject}';
      }

      bool shouldPunctuate = !entry.contains(RegExp(r'[\.\?\!]$'));
      if (shouldPunctuate) {
        entry = '$entry.';
      }

      if (commit.isBreakingChange) {
        entry = '**BREAKING** $entry';
      }

      return entry;
    }).toList();
  }

  @override
  bool operator ==(Object other) {
    return other is MelosPendingPackageUpdate &&
        other.package.name == package.name;
  }

  @override
  String toString() {
    return 'MelosPendingPackageUpdate(packageName: ${package
        .name}, semverType: $semverReleaseType, currentVersion: $currentVersion, pendingVersion: $pendingVersion)';
  }

  @override
  int get hashCode => package.name.hashCode;
}
