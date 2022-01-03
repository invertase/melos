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
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';

import '../package.dart';
import 'pending_package_update.dart';

class Changelog {
  Changelog(this.package, this.version, this.logger);

  final Package package;
  final Version version;
  final Logger? logger;

  String get markdown {
    throw UnimplementedError();
  }

  String get path {
    return joinAll([package.path, 'CHANGELOG.md']);
  }

  @override
  String toString() {
    return markdown;
  }

  Future<String> read() async {
    final exists = File(path).existsSync();
    if (exists) {
      return File(path).readAsString();
    }
    return '';
  }

  Future<void> write() async {
    var contents = await read();
    if (contents.contains(markdown)) {
      logger?.trace(
        'Identical changelog content for ${package.name} v$version already exists, skipping.',
      );
      return;
    }
    contents = '$markdown$contents';

    await File(path).writeAsString(contents);
  }
}

class SingleEntryChangelog extends Changelog {
  SingleEntryChangelog(
    Package package,
    Version version,
    this.entry,
    Logger? logger,
  ) : super(package, version, logger);

  final String entry;

  @override
  String get markdown {
    final changelogHeader = '## $version';
    return '$changelogHeader\n\n - $entry\n\n';
  }
}

class MelosChangelog extends Changelog {
  MelosChangelog(this.update, Logger? logger)
      : super(update.package, update.nextVersion, logger);

  final MelosPendingPackageUpdate update;

  @override
  String get markdown {
    var body = '';
    var entries = <String>[];
    var header = '## ${update.nextVersion}';

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

    body = entries.join('\n - ');

    return '$header\n\n - $body\n\n';
  }
}
