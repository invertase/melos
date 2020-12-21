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

import 'dart:io';

import 'package:path/path.dart';

import 'git_commit.dart';
import 'logger.dart';
import 'package.dart';

enum TagReleaseType {
  all,
  prerelease,
  stable,
}

/// Generate a filter pattern for a package name, useful for listing tags for a package.
String gitTagFilterPattern(String packageName, TagReleaseType tagReleaseType,
    {String preid = 'dev', String prefix = 'v'}) {
  return tagReleaseType == TagReleaseType.prerelease
      ? '$packageName-$prefix*-$preid.*'
      : '$packageName-$prefix*';
}

/// Generate a git tag string for the specified package name and version.
String gitTagForPackageVersion(String packageName, String packageVersion,
    {String prefix = 'v'}) {
  return '$packageName-$prefix$packageVersion';
}

/// Return a list of git tags for a Melos package, in date created descending order.
/// Optionally specify [tagReleaseType] to specify [TagReleaseType].
Future<List<String>> gitTagsForPackage(MelosPackage package,
    {TagReleaseType tagReleaseType = TagReleaseType.all,
    String preid = 'dev'}) async {
  final String filterPattern =
      gitTagFilterPattern(package.name, tagReleaseType, preid: preid);
  final processResult = await Process.run(
      'git', ['tag', '-l', '--sort=-creatordate', filterPattern],
      workingDirectory: package.path);
  return (processResult.stdout as String)
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .where((tag) => tagReleaseType == TagReleaseType.stable
          ? !tag.contains('-$preid.')
          : true)
      .toList();
}

/// Check a tag exists.
Future<bool> gitTagExists(String tag, {String workingDirectory}) async {
  final processResult = await Process.run('git', ['tag', '-l', tag],
      workingDirectory: workingDirectory ?? Directory.current.path);
  return (processResult.stdout as String).contains(tag);
}

/// Create a tag, if it does not already exist. Returns true if tag was successfully created.
Future<bool> gitTagCreate(String tag, String message,
    {String workingDirectory, String commitId}) async {
  bool tagExists = await gitTagExists(tag, workingDirectory: workingDirectory);
  if (tagExists) {
    return false;
  }

  List<String> gitArgs = commitId != null && commitId.isNotEmpty
      ? ['tag', '-a', tag, commitId, '-m', message]
      : ['tag', '-a', tag, '-m', message];

  await Process.run('git', gitArgs,
      workingDirectory: workingDirectory ?? Directory.current.path);

  return gitTagExists(tag, workingDirectory: workingDirectory);
}

/// Return the latest git tag for a Melos package. Latest determined in the following order;
///     1) The current package version exists as a tag?
///  OR 2) The latest tag sorted by listing tags in created date descending order.
///        Note: If the current version is a prerelease then only prerelease tags are requested.
/// Optionally specify [tagReleaseType] to specify [TagReleaseType].
Future<String> gitLatestTagForPackage(MelosPackage package,
    {String preid = 'dev'}) async {
  // Package doesn't have a version, skip.
  if (package.version.toString() == '0.0.0') {
    return null;
  }

  String currentVersionTag =
      gitTagForPackageVersion(package.name, package.version.toString());
  bool currentTagExists = await gitTagExists(currentVersionTag);
  if (currentTagExists) {
    logger.trace(
        '[GIT]: Found a git tag for the latest ${package.name} version (${package.version.toString()}).');
    return currentVersionTag;
  }

  // If the current version is a prerelease then only prerelease tags are requested.
  TagReleaseType tagReleaseType = package.version.isPreRelease
      ? TagReleaseType.prerelease
      : TagReleaseType.all;
  List<String> tags = await gitTagsForPackage(package,
      tagReleaseType: tagReleaseType, preid: preid);
  if (tags.isEmpty) {
    return null;
  }

  return tags.first;
}

Future<void> gitAdd(String filePattern, {String workingDirectory}) async {
  List<String> gitArgs = ['add', filePattern];
  await Process.run('git', gitArgs,
      workingDirectory: workingDirectory ?? Directory.current.path);
}

Future<bool> gitExists({String workingDirectory}) {
  return Directory(
      joinAll([workingDirectory ?? Directory.current.path, '.git'])).exists();
}

Future<bool> gitStatusIsClean({String workingDirectory}) async {
  List<String> gitArgs = ['status', '--untracked-files=no', '--porcelain'];
  var result = await Process.run('git', gitArgs,
      workingDirectory: workingDirectory ?? Directory.current.path);
  return result.stdout.toString().trim().isEmpty;
}

Future<void> gitRestore(String filePattern, {String workingDirectory}) async {
  List<String> gitArgs = ['restore', filePattern];
  await Process.run('git', gitArgs,
      workingDirectory: workingDirectory ?? Directory.current.path);
}

Future<void> gitCommit(String message, {String workingDirectory}) async {
  List<String> gitArgs = ['commit', '-m', message];
  await Process.run('git', gitArgs,
      workingDirectory: workingDirectory ?? Directory.current.path);
}

/// Returns a list of [GitCommit]s for a Melos package.
/// Optionally specify [since] to start after a specified commit or tag. Defaults
/// to the latest release tag.
Future<List<GitCommit>> gitCommitsForPackage(MelosPackage package,
    {String since, String preid = 'dev'}) async {
  if (package.isPrivate) {
    return [];
  }
  String sinceOrLatestTag = since;
  if (sinceOrLatestTag != null && sinceOrLatestTag.isEmpty) {
    sinceOrLatestTag = null;
  }
  sinceOrLatestTag ??= await gitLatestTagForPackage(package);

  logger.trace(
      '[GIT]: Getting commits for package ${package.name} since "${sinceOrLatestTag ?? '@'}".');

  final processResult = await Process.run(
      'git',
      [
        '--no-pager',
        'log',
        sinceOrLatestTag != null ? '$sinceOrLatestTag...@' : '@',
        '--pretty=format:%H|||%aN <%aE>|||%ai|||%B||||',
        '--',
        '.',
      ],
      workingDirectory: package.path);

  List<String> rawCommits = (processResult.stdout as String)
      .split('||||\n')
      .where((element) => element.trim().isNotEmpty)
      .toList();

  return rawCommits.map((String rawCommit) {
    var parts = rawCommit.split('|||');
    return GitCommit(
      id: parts[0].trim(),
      author: parts[1].trim(),
      date: DateTime.parse(parts[2].trim()),
      message: parts[3].trim(),
    );
  }).toList();
}
