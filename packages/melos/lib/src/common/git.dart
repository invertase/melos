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

import 'dart:convert';
import 'dart:io';

import '../logging.dart';
import '../package.dart';
import 'git_commit.dart';

enum TagReleaseType {
  all,
  prerelease,
  stable,
}

/// Generate a filter pattern for a package name, useful for listing tags for a
/// package.
String gitTagFilterPattern(
  String packageName,
  TagReleaseType tagReleaseType, {
  String preid = 'dev',
  String prefix = 'v',
}) {
  return tagReleaseType == TagReleaseType.prerelease
      ? '$packageName-$prefix*-$preid.*'
      : '$packageName-$prefix*';
}

/// Generate a git tag string for the specified package name and version.
String gitTagForPackageVersion(
  String packageName,
  String packageVersion, {
  String prefix = 'v',
}) {
  return '$packageName-$prefix$packageVersion';
}

/// Generate a git release title for the specified package name and version.
String gitReleaseTitleForPackageVersion(
  String packageName,
  String packageVersion, {
  String prefix = 'v',
}) {
  return '$packageName $prefix$packageVersion';
}

/// Execute a `git` CLI command with arguments.
Future<ProcessResult> gitExecuteCommand({
  required List<String> arguments,
  required String workingDirectory,
  required MelosLogger logger,
  bool throwOnExitCodeError = true,
}) async {
  const executable = 'git';

  logger.trace(
    '[GIT] Executing command `$executable ${arguments.join(' ')}` '
    'in directory `$workingDirectory`.',
  );

  final processResult = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  if (throwOnExitCodeError && processResult.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'Melos: Failed executing a git command: '
      '${processResult.stdout} ${processResult.stderr}',
    );
  }

  return processResult;
}

/// Return a list of git tags for a Melos package, in date created descending
/// order.
///
/// Optionally specify [tagReleaseType] to specify [TagReleaseType].
Future<List<String>> gitTagsForPackage(
  Package package, {
  TagReleaseType tagReleaseType = TagReleaseType.all,
  String preid = 'dev',
  required MelosLogger logger,
}) async {
  final filterPattern =
      gitTagFilterPattern(package.name, tagReleaseType, preid: preid);
  final processResult = await gitExecuteCommand(
    arguments: ['tag', '-l', '--sort=-creatordate', filterPattern],
    workingDirectory: package.path,
    logger: logger,
  );
  return (processResult.stdout as String)
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .where((tag) {
    if (tagReleaseType == TagReleaseType.stable) {
      // TODO(Salakar) This is probably not the best way to determine if a tag
      // is pre-release or not.
      // Should we parse it, extract the version and pass it through to
      // pub_semver?
      return !tag.contains('-$preid.');
    }
    return true;
  }).toList();
}

/// Check a tag exists.
Future<bool> gitTagExists(
  String tag, {
  required String workingDirectory,
  required MelosLogger logger,
}) async {
  final processResult = await gitExecuteCommand(
    arguments: ['tag', '-l', tag],
    workingDirectory: workingDirectory,
    logger: logger,
  );
  return (processResult.stdout as String).contains(tag);
}

/// Create a tag, if it does not already exist.
///
/// Returns true if tag was successfully created.
Future<bool> gitTagCreate(
  String tag,
  String message, {
  required String workingDirectory,
  String? commitId,
  required MelosLogger logger,
}) async {
  if (await gitTagExists(
    tag,
    workingDirectory: workingDirectory,
    logger: logger,
  )) {
    return false;
  }

  final arguments = commitId != null && commitId.isNotEmpty
      ? ['tag', '-a', tag, commitId, '-m', message]
      : ['tag', '-a', tag, '-m', message];

  await gitExecuteCommand(
    arguments: arguments,
    workingDirectory: workingDirectory,
    throwOnExitCodeError: false,
    logger: logger,
  );

  return gitTagExists(
    tag,
    workingDirectory: workingDirectory,
    logger: logger,
  );
}

/// Return the latest git tag for a Melos package.
///
/// The latest tag is determined in the following order:
///
/// - 1.  The current package version exists as a tag? OR
/// - 2.  The latest tag sorted by listing tags in created date descending
///       order.
///
///       Note: If the current version is a prerelease then only prerelease tags
///       are requested.
Future<String?> gitLatestTagForPackage(
  Package package, {
  String preid = 'dev',
  required MelosLogger logger,
}) async {
  // Package doesn't have a version, skip.
  if (package.version.toString() == '0.0.0') return null;

  final currentVersionTag =
      gitTagForPackageVersion(package.name, package.version.toString());
  if (await gitTagExists(
    currentVersionTag,
    workingDirectory: package.path,
    logger: logger,
  )) {
    logger.trace(
      '[GIT] Found a git tag for the latest ${package.name} version '
      '(${package.version}).',
    );
    return currentVersionTag;
  }

  // If the current version is a prerelease then only prerelease tags are
  // requested.
  final tagReleaseType = package.version.isPreRelease
      ? TagReleaseType.prerelease
      : TagReleaseType.all;
  final tags = await gitTagsForPackage(
    package,
    tagReleaseType: tagReleaseType,
    preid: preid,
    logger: logger,
  );
  if (tags.isEmpty) return null;

  return tags.first;
}

Future<void> gitFetchTags({
  required String workingDirectory,
  required MelosLogger logger,
}) async {
  await gitExecuteCommand(
    arguments: ['pull', '--tags'],
    workingDirectory: workingDirectory,
    logger: logger,
  );
}

/// Stage files matching the specified file pattern for committing.
Future<void> gitAdd(
  String filePattern, {
  required String workingDirectory,
  required MelosLogger logger,
}) async {
  final arguments = ['add', filePattern];
  await gitExecuteCommand(
    arguments: arguments,
    workingDirectory: workingDirectory,
    logger: logger,
  );
}

/// Commit any staged changes with a specific git message.
Future<void> gitCommit(
  String message, {
  required String workingDirectory,
  required MelosLogger logger,
}) async {
  final arguments = ['commit', '-m', message];
  await gitExecuteCommand(
    arguments: arguments,
    workingDirectory: workingDirectory,
    logger: logger,
  );
}

/// RegExp that matches `<commit1>..<commit2>` or `<commit1>...<commit2>`.
final _gitVersionRangeShortHandRegExp = RegExp(r'^.+\.{2,3}.+$');

/// Returns a list of [GitCommit]s for a Melos package.
///
/// Optionally specify [diff] to start after a specified commit or tag.
/// Defaults to the latest release tag.
/// Diff also supports specifying a range of commits, e.g. `HEAD~5..HEAD`.
Future<List<GitCommit>> gitCommitsForPackage(
  Package package, {
  String? diff,
  required MelosLogger logger,
}) async {
  var revisionRange = diff?.trim();
  if (revisionRange != null) {
    if (revisionRange.isEmpty) {
      revisionRange = null;
    } else if (!_gitVersionRangeShortHandRegExp.hasMatch(revisionRange)) {
      // If the revision range is not a valid revision range short hand then we
      // assume it's a commit or tag and default to the range from that
      // commit/tag to HEAD.
      revisionRange = '$revisionRange...HEAD';
    }
  }

  if (revisionRange == null) {
    final latestTag = await gitLatestTagForPackage(package, logger: logger);
    // If no latest tag is found then we default to the entire git history.
    revisionRange = latestTag != null ? '$latestTag...HEAD' : 'HEAD';
  }

  logger.trace(
    '[GIT] Getting commits for package ${package.name} for revision range '
    '"$revisionRange".',
  );

  final processResult = await gitExecuteCommand(
    arguments: [
      '--no-pager',
      'log',
      revisionRange,
      '--pretty=format:%H|||%aN <%aE>|||%ai|||%B||||',
      '--',
      '.',
    ],
    workingDirectory: package.path,
    logger: logger,
  );

  final rawCommits = (processResult.stdout as String)
      .split('||||\n')
      .where((element) => element.trim().isNotEmpty)
      .toList();

  return rawCommits.map((rawCommit) {
    final parts = rawCommit.split('|||');
    return GitCommit(
      id: parts[0].trim(),
      author: parts[1].trim(),
      date: DateTime.parse(parts[2].trim()),
      message: parts[3].trim(),
    );
  }).toList();
}

/// Returns the current branch name of the local git repository.
Future<String> gitGetCurrentBranchName({
  required String workingDirectory,
  required MelosLogger logger,
}) async {
  final arguments = ['rev-parse', '--abbrev-ref', 'HEAD'];
  final processResult = await gitExecuteCommand(
    arguments: arguments,
    workingDirectory: workingDirectory,
    logger: logger,
  );
  return (processResult.stdout as String).trim();
}

/// Fetches updates for the default remote in the repository.
Future<void> gitRemoteUpdate({
  required String workingDirectory,
  required MelosLogger logger,
}) async {
  final arguments = ['remote', 'update'];
  await gitExecuteCommand(
    arguments: arguments,
    workingDirectory: workingDirectory,
    logger: logger,
  );
}

/// Determine if the local git repository is behind on commits from its remote
/// branch.
Future<bool> gitIsBehindUpstream({
  required String workingDirectory,
  String remote = 'origin',
  String? branch,
  required MelosLogger logger,
}) async {
  await gitRemoteUpdate(workingDirectory: workingDirectory, logger: logger);

  final localBranch = branch ??
      await gitGetCurrentBranchName(
        workingDirectory: workingDirectory,
        logger: logger,
      );
  final remoteBranch = '$remote/$localBranch';
  final arguments = [
    'rev-list',
    '--left-right',
    '--count',
    '$remoteBranch...$localBranch',
  ];

  final processResult = await gitExecuteCommand(
    arguments: arguments,
    workingDirectory: workingDirectory,
    logger: logger,
  );
  final leftRightCounts =
      (processResult.stdout as String).split('\t').map<int>(int.parse).toList();
  final behindCount = leftRightCounts[0];
  final aheadCount = leftRightCounts[1];
  final isBehind = behindCount > 0;

  logger.trace(
    '[GIT] Local branch `$localBranch` is behind remote branch `$remoteBranch` '
    'by $behindCount commit(s) and ahead by $aheadCount.',
  );

  return isBehind;
}
