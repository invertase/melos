import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

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
///
/// When [packageName] is `null` the pattern matches plain version tags without
/// a package name, e.g. `v1.2.3`, as used by the workspace root package.
String gitTagFilterPattern(
  String? packageName,
  TagReleaseType tagReleaseType, {
  String preid = 'dev',
  String prefix = 'v',
}) {
  final tagPrefix = packageName == null
      ? '$prefix[0-9]'
      : '$packageName-$prefix';
  return tagReleaseType == TagReleaseType.prerelease
      ? '$tagPrefix*-$preid.*'
      : '$tagPrefix*';
}

/// Generate a git tag string for the specified package name and version.
String gitTagForPackageVersion(
  String packageName,
  String packageVersion, {
  String prefix = 'v',
}) {
  return '$packageName-$prefix$packageVersion';
}

/// Generate a plain git tag string for the specified version, without a
/// package name, e.g. `v1.2.3`.
String gitTagForVersion(
  String packageVersion, {
  String prefix = 'v',
}) {
  return '$prefix$packageVersion';
}

/// Whether [package] is tagged with plain version tags, e.g. `v1.2.3`, instead
/// of tags prefixed with the package name, e.g. `package_name-v1.2.3`.
///
/// This is the case for the workspace root package (included when
/// `useRootAsPackage` is enabled) and for every package when the workspace is
/// versioned in lockstep with a single [workspaceTag].
bool gitPackageUsesPlainVersionTag(
  Package package, {
  required bool workspaceTag,
}) {
  return workspaceTag || package.isWorkspaceRoot;
}

/// Generate the git tag string for the specified package and version.
///
/// Packages for which [gitPackageUsesPlainVersionTag] is true use plain
/// version tags, e.g. `v1.2.3`, while all other packages use tags prefixed
/// with their package name, e.g. `package_name-v1.2.3`.
String gitTagForPackage(
  Package package,
  String packageVersion, {
  String prefix = 'v',
  bool workspaceTag = false,
}) {
  return gitPackageUsesPlainVersionTag(package, workspaceTag: workspaceTag)
      ? gitTagForVersion(packageVersion, prefix: prefix)
      : gitTagForPackageVersion(package.name, packageVersion, prefix: prefix);
}

/// Parses the version from a [tag] of [package], which is either a plain
/// version tag, e.g. `v1.2.3`, or a tag prefixed with the package name, e.g.
/// `package_name-v1.2.3`.
///
/// Returns `null` if the tag does not contain a valid version.
Version? gitVersionFromTag(
  String tag,
  Package package, {
  String prefix = 'v',
}) {
  final packagePrefix = '${package.name}-$prefix';
  final String versionString;
  if (tag.startsWith(packagePrefix)) {
    versionString = tag.substring(packagePrefix.length);
  } else if (tag.startsWith(prefix)) {
    versionString = tag.substring(prefix.length);
  } else {
    return null;
  }

  try {
    return Version.parse(versionString);
  } on FormatException {
    return null;
  }
}

/// Returns the tag with the highest version among [tags].
///
/// When a plain version tag and a tag prefixed with the package name have the
/// same version, the plain version tag wins.
String? _gitTagWithHighestVersion(List<String> tags, Package package) {
  String? highestTag;
  Version? highestVersion;
  var highestIsPlain = false;
  for (final tag in tags) {
    final version = gitVersionFromTag(tag, package);
    if (version == null) {
      continue;
    }
    final isPlain = !tag.startsWith('${package.name}-');
    if (highestVersion == null ||
        version > highestVersion ||
        (version == highestVersion && isPlain && !highestIsPlain)) {
      highestTag = tag;
      highestVersion = version;
      highestIsPlain = isPlain;
    }
  }
  return highestTag;
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
  required MelosLogger logger,
  TagReleaseType tagReleaseType = TagReleaseType.all,
  String preid = 'dev',
  bool workspaceTag = false,
}) async {
  // Packages using plain version tags still match tags prefixed with the
  // package name, to support tags created before plain version tags were
  // introduced or enabled.
  final filterPatterns = [
    if (gitPackageUsesPlainVersionTag(package, workspaceTag: workspaceTag))
      gitTagFilterPattern(null, tagReleaseType, preid: preid),
    gitTagFilterPattern(package.name, tagReleaseType, preid: preid),
  ];
  final processResult = await gitExecuteCommand(
    arguments: ['tag', '-l', '--sort=-creatordate', ...filterPatterns],
    workingDirectory: package.path,
    logger: logger,
  );
  return (processResult.stdout as String)
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .where((tag) {
        if (tagReleaseType == TagReleaseType.stable) {
          // TODO(Salakar) This is probably not the best way to determine if a
          // tag is pre-release or not.
          // Should we parse it, extract the version and pass it through to
          // pub_semver?
          return !tag.contains('-$preid.');
        }
        return true;
      })
      .toList();
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
  required MelosLogger logger,
  String? commitId,
}) async {
  if (await gitTagExists(
    tag,
    workingDirectory: workingDirectory,
    logger: logger,
  )) {
    return false;
  }

  // Git strips lines starting with `#` from the message by default, which
  // would remove the markdown headings of the changelog.
  final arguments = [
    'tag',
    '-a',
    tag,
    if (commitId != null && commitId.isNotEmpty) commitId,
    '--cleanup=whitespace',
    '-m',
    message,
  ];

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
///
///       Note: Packages using plain version tags can also have tags prefixed
///       with the package name, in which case the tag with the highest version
///       is used, preferring the plain version tag when both have the same
///       version.
Future<String?> gitLatestTagForPackage(
  Package package, {
  required MelosLogger logger,
  String preid = 'dev',
  bool workspaceTag = false,
}) async {
  // Package doesn't have a version, skip.
  if (package.version.toString() == '0.0.0') {
    return null;
  }

  final currentVersion = package.version.toString();
  final currentVersionTags = [
    gitTagForPackage(package, currentVersion, workspaceTag: workspaceTag),
    if (gitPackageUsesPlainVersionTag(package, workspaceTag: workspaceTag))
      gitTagForPackageVersion(package.name, currentVersion),
  ];
  for (final currentVersionTag in currentVersionTags) {
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
    workspaceTag: workspaceTag,
    logger: logger,
  );
  if (tags.isEmpty) {
    return null;
  }

  if (gitPackageUsesPlainVersionTag(package, workspaceTag: workspaceTag)) {
    return _gitTagWithHighestVersion(tags, package);
  }

  return tags.first;
}

Future<void> gitFetchTags({
  required String workingDirectory,
  required MelosLogger logger,
}) async {
  await gitExecuteCommand(
    arguments: ['pull', '--tags', '-f'],
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
///
/// When [workspaceTag] is true, the latest release tag is a plain version tag
/// shared by the whole workspace, see [gitPackageUsesPlainVersionTag].
Future<List<GitCommit>> gitCommitsForPackage(
  Package package, {
  required MelosLogger logger,
  String? diff,
  bool workspaceTag = false,
}) async {
  final revisionRange = await _resolveRevisionRange(
    package,
    diff: diff,
    workspaceTag: workspaceTag,
    logger: logger,
  );

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

Future<bool> gitHasDiffInPackage(
  Package package, {
  required String? diff,
  required MelosLogger logger,
}) async {
  final revisionRange = await _resolveRevisionRange(
    package,
    diff: diff,
    logger: logger,
  );

  logger.trace(
    '[GIT] Getting $diff diff for package ${package.name}.',
  );

  final processResult = await gitExecuteCommand(
    arguments: [
      '--no-pager',
      'diff',
      '--name-status',
      revisionRange,
      '--',
      '.',
    ],
    workingDirectory: package.path,
    logger: logger,
  );

  return (processResult.stdout as String).isNotEmpty;
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
  required MelosLogger logger,
  String remote = 'origin',
  String? branch,
}) async {
  await gitRemoteUpdate(workingDirectory: workingDirectory, logger: logger);

  final localBranch =
      branch ??
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
  final leftRightCounts = (processResult.stdout as String)
      .split('\t')
      .map<int>(int.parse)
      .toList();
  final behindCount = leftRightCounts[0];
  final aheadCount = leftRightCounts[1];
  final isBehind = behindCount > 0;

  logger.trace(
    '[GIT] Local branch `$localBranch` is behind remote branch `$remoteBranch` '
    'by $behindCount commit(s) and ahead by $aheadCount.',
  );

  return isBehind;
}

Future<String> _resolveRevisionRange(
  Package package, {
  required String? diff,
  required MelosLogger logger,
  bool workspaceTag = false,
}) async {
  var revisionRange = diff?.trim();
  if (revisionRange != null) {
    if (revisionRange.isEmpty) {
      revisionRange = null;
    } else if (_gitVersionRangeShortHandRegExp.hasMatch(revisionRange)) {
      return revisionRange;
    } else {
      // If the revision range is not a valid revision range short hand then we
      // assume it's a commit or tag and default to the range from that
      // commit/tag to HEAD.
      return '$revisionRange...HEAD';
    }
  }

  if (revisionRange == null) {
    final latestTag = await gitLatestTagForPackage(
      package,
      workspaceTag: workspaceTag,
      logger: logger,
    );
    // If no latest tag is found then we default to the entire git history.
    return latestTag != null ? '$latestTag...HEAD' : 'HEAD';
  }

  return 'HEAD';
}
