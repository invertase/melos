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

import 'git_commit.dart';
import 'package.dart';

enum TagReleaseType {
  all,
  dev,
  stable,
}

/// Return a list of git tags for a Melos package, in date created descending order.
/// Optionally specify [tagReleaseType] to specify [TagReleaseType].
Future<List<String>> gitTagsForPackage(MelosPackage package,
    {TagReleaseType tagReleaseType = TagReleaseType.all}) async {
  final String filterPattern = tagReleaseType == TagReleaseType.dev
      ? '${package.name}-v*-dev.*'
      : '${package.name}-v*';
  final processResult = await Process.run(
      'git', ['tag', '-l', '--sort=-creatordate', filterPattern],
      workingDirectory: package.path);
  return (processResult.stdout as String)
      .split('\n')
      .map((e) => e.trim())
      .where((tag) =>
  tagReleaseType == TagReleaseType.stable
      ? !tag.contains('-dev.')
      : true)
      .toList();
}

/// Return the latest (by date created) git tag for a Melos package.
/// Optionally specify [tagReleaseType] to specify [TagReleaseType].
Future<String> gitLatestTagForPackage(MelosPackage package,
    {TagReleaseType tagReleaseType = TagReleaseType.all}) async {
  List<String> tags =
  await gitTagsForPackage(package, tagReleaseType: tagReleaseType);
  if (tags.isEmpty) {
    return null;
  }
  return tags.first;
}

/// Returns a list of [GitCommit]s for a Melos package.
/// Optionally specify [since] to start after a specified commit or tag. Defaults
/// to the latest stable release tag.
Future<List<GitCommit>> gitCommitsForPackage(MelosPackage package,
    {String since}) async {
  String sinceOrLatestTag = since;
  sinceOrLatestTag ??= await gitLatestTagForPackage(package,
      tagReleaseType: TagReleaseType.stable);
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
      .where((element) =>
  element
      .trim()
      .isNotEmpty)
      .toList();

  return rawCommits.map((String rawCommit) {
    var parts = rawCommit.split('|||');
    return GitCommit(
      sha: parts[0].trim(),
      author: parts[1].trim(),
      date: DateTime.parse(parts[2].trim()),
      message: parts[3].trim(),
    );
  }).toList();
}
