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
import 'package:conventional_commit/conventional_commit.dart';

import 'logger.dart';
import 'pending_package_update.dart';

class Changelog {
  final MelosPendingPackageUpdate update;
  Changelog(this.update);

  String get markdown {
    throw UnimplementedError();
  }

  String get path {
    return joinAll([update.package.path, 'CHANGELOG.md']);
  }

  @override
  String toString() {
    return markdown;
  }

  Future<String> read() async {
    bool exists = await File(path).exists();
    if (exists) {
      return File(path).readAsString();
    }
    return '';
  }

  Future<void> write() async {
    String contents = await read();
    if (contents.contains(markdown)) {
      logger.trace(
          'Identical changelog content for ${update.package.name} v${update.nextVersion.toString()} already exists, skipping.');
      return;
    }
    contents = '$markdown$contents';
    return File(path).writeAsString(contents);
  }
}

class MelosChangelog extends Changelog {
  MelosChangelog(MelosPendingPackageUpdate update) : super(update);

  @override
  String get markdown {
    String body = '';
    String header = '## ${update.nextVersion}';
    List<String> entries = [];

    if (update.reason == PackageUpdateReason.dependency) {
      entries = ['Update a dependency to the latest release.'];
    }

    if (update.reason == PackageUpdateReason.graduate) {
      entries = [
        'Graduate package to a stable release. See pre-releases prior to this version for changelog entries.'
      ];
    }

    if (update.reason == PackageUpdateReason.commit) {
      if (update.semverReleaseType == SemverReleaseType.major) {
        header += '\n\n> Note: This release has breaking changes.';
      }

      List<ConventionalCommit> commits = List.from(update.commits
          .where((ConventionalCommit commit) => !commit.isMergeCommit)
          .toList());

      // Sort so that Breaking Changes appear at the top.
      commits.sort((a, b) {
        var r = a.isBreakingChange
            .toString()
            .compareTo(b.isBreakingChange.toString());
        if (r != 0) return r;
        return b.type.compareTo(a.type);
      });

      entries = commits.map((commit) {
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

    body = entries.join('\n - ');

    return '$header\n\n - $body\n\n';
  }
}
