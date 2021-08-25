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

import 'package:cli_util/cli_logging.dart';
import 'package:conventional_commit/conventional_commit.dart';
import 'package:melos/melos.dart';
import 'package:path/path.dart';

import 'pending_package_update.dart';

class WorkspaceChangelog {
  WorkspaceChangelog(this.workspace, this.title, this.pendingPackageUpdates, this.logger);

  final MelosWorkspace workspace;
  final String title;
  final Logger logger;
  final List<MelosPendingPackageUpdate> pendingPackageUpdates;


  String get markdown {
    var body = 'CHANGELOG\n\n ## ${title}';
    var entries = <String>[];

    pendingPackageUpdates.forEach((MelosPendingPackageUpdate update) {
    var header = '### ${update.package.name}';

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

      final commits = List<ConventionalCommit>.from(
        update.commits
            .where((ConventionalCommit commit) => !commit.isMergeCommit)
            .toList(),
      );

      // Sort so that Breaking Changes appear at the top.
      commits.sort((a, b) {
        final r = a.isBreakingChange
            .toString()
            .compareTo(b.isBreakingChange.toString());
        if (r != 0) return r;
        return b.type!.compareTo(a.type!);
      });

      entries = commits.map((commit) {
        String entry;
        if (commit.isMergeCommit) {
          entry = commit.header;
        } else {
          entry = '**${commit.type!.toUpperCase()}**: ${commit.description}';
        }

        final shouldPunctuate = !entry.contains(RegExp(r'[\.\?\!]$'));
        if (shouldPunctuate) {
          entry = '$entry.';
        }

        if (commit.isBreakingChange) {
          entry = '**BREAKING** $entry';
        }

        return entry;
      }).toList();
    }

    String updateSection = entries.join('\n - ');

    body = '$body\n\n' + '$header\n\n - $updateSection';
    });

    return '$body\n\n';
  }

  String get path {
    return joinAll([workspace.path, 'CHANGELOG.md']);
  }

  @override
  String toString() {
    return markdown;
  }

  Future<String> read() async {
    final file = File(path);
    final exists = file.existsSync();
    if (exists) {
      List<String> lines = await file.readAsLines();
      lines.removeAt(0);

      return lines.join('\n');
    }
    return '';
  }

  Future<void> write() async {
    var contents = await read();
    if (contents.contains(markdown)) {
      logger.trace(
        'Identical changelog content for ${workspace.name} already exists, skipping.',
      );
      return;
    }
    contents = '$markdown$contents';

    await File(path).writeAsString(contents);
  }
}