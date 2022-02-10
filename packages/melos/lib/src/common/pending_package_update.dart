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

import 'package:cli_util/cli_logging.dart';
import 'package:conventional_commit/conventional_commit.dart';
import 'package:pub_semver/pub_semver.dart';

import '../package.dart';
import '../workspace.dart';
import 'changelog.dart';
import 'git_commit.dart';
import 'versioning.dart' as versioning;

/// Enum representing why the version has been changed when running 'version' command.
enum PackageUpdateReason {
  /// The user provided a new version.
  manual,

  /// Changed due to a commit modifying code in this package.
  commit,

  /// Changed due to another package that this package depends on being updated.
  dependency,

  /// Package is being graduated to a stable version from a prerelease.
  graduate,
}

class MelosPendingPackageUpdate {
  MelosPendingPackageUpdate(
    this.workspace,
    this.package,
    this.commits,
    this.reason, {
    this.prerelease = false,
    this.graduate = false,
    this.preid,
    required this.logger,
  })  : manualVersion = null,
        userChangelogMessage = null;

  MelosPendingPackageUpdate.manual(
    this.workspace,
    this.package,
    this.commits,
    this.manualVersion, {
    this.userChangelogMessage,
    required this.logger,
  })  : reason = PackageUpdateReason.manual,
        prerelease = false,
        graduate = false,
        preid = null;

  /// Commits that triggered this pending update. Can be empty if
  /// [PackageUpdateReason] is [PackageUpdateReason.dependency].
  final List<RichGitCommit> commits;

  /// The workspace that contains the [package] that this update will apply to
  /// when committed.
  final MelosWorkspace workspace;

  /// The package that this update will apply to when committed.
  final Package package;

  /// A reason why this package needs updating.
  final PackageUpdateReason reason;

  /// Whether the next package version will be made a prerelease version.
  final bool prerelease;

  /// If true and the package is currently a prerelease version, the next package version
  /// will graduate to a stable, non-prerelease version.
  final bool graduate;

  /// The prerelease id that will be used for prereleases, e.g. "0.1.0-[preid].1".
  final String? preid;

  /// The next version of the package, if it has been manually specified by the
  /// user.
  final Version? manualVersion;

  /// Changelog message that the user provided directly.
  ///
  /// This is only used for manually versioned packages.
  final String? userChangelogMessage;

  final Logger? logger;

  Changelog get changelog {
    // TODO change log styles can be changed here if supported in future.
    return MelosChangelog(this, logger);
  }

  /// Current version specified in the packages pubspec.yaml.
  Version get currentVersion {
    return package.version;
  }

  /// Next pub version that will occur as part of this package update.
  Version get nextVersion {
    return manualVersion ??
        versioning.nextVersion(
          currentVersion,
          semverReleaseType!,
          graduate: graduate,
          preid: preid,
          prerelease: prerelease,
        );
  }

  /// Taking into account all the commits in this update, what is the highest [SemverReleaseType].
  ///
  /// Is `null` for manually versioned packages.
  SemverReleaseType? get semverReleaseType {
    if (reason == PackageUpdateReason.manual) {
      return null;
    }

    if (reason == PackageUpdateReason.dependency) {
      // Version bumps for dependencies should be patches.
      // If the dependencies had breaking changes then this package should have had commits to update it separately.
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
        .map((e) => e.parsedMessage.semverReleaseType.index)
        .toList()
        .reduce(math.max)];
  }

  /// Whether this update contains breaking changes.
  bool get hasBreakingChanges {
    if (reason == PackageUpdateReason.manual) {
      return commits.any((commit) => commit.parsedMessage.isBreakingChange);
    }

    return semverReleaseType == SemverReleaseType.major;
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
