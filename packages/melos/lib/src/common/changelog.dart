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
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';

import '../package.dart';
import 'git_commit.dart';
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
    final entry = StringBuffer();

    // Changelog entry header.
    entry.write('## ');
    entry.writeln(update.nextVersion);
    entry.writeln();

    if (update.reason == PackageUpdateReason.dependency) {
      // Dependency change entry.
      entry.writeln('- Update a dependency to the latest release.');
      entry.writeln();
    }

    if (update.reason == PackageUpdateReason.graduate) {
      // Package graduation entry.
      entry.writeln(
        '- Graduate package to a stable release. See pre-releases prior to '
        'this version for changelog entries.',
      );
      entry.writeln();
    }

    if (update.reason == PackageUpdateReason.commit ||
        update.reason == PackageUpdateReason.manual) {
      // Breaking change note.
      if (update.hasBreakingChanges) {
        entry.writeln('> Note: This release has breaking changes.');
        entry.writeln();
      }

      // User provided changelog entry message.
      if (update.userChangelogMessage != null) {
        entry.writeln(update.userChangelogMessage);
        entry.writeln();
      }

      // Entires for commits included in new version.
      final commits = _filteredAndSortedCommits();
      if (commits.isNotEmpty) {
        for (final commit in commits) {
          final parsedMessage = commit.parsedMessage;

          entry.write('- ');

          if (parsedMessage.isBreakingChange) {
            entry.writeBold('BREAKING');
            entry.write(' ');
          }

          if (parsedMessage.isMergeCommit) {
            entry.writePunctuated(parsedMessage.header);
          } else {
            entry.writeBold(parsedMessage.type!.toUpperCase());
            entry.write(': ');
            entry.writePunctuated(parsedMessage.description!);
          }

          if (update.workspace.config.commands.version.linkToCommits ?? false) {
            final shortCommitId = commit.id.substring(0, 8);
            final commitUrl =
                update.workspace.config.repository!.commitUrl(commit.id);
            entry.write(' ([$shortCommitId]($commitUrl))');
          }

          entry.writeln();
        }
        entry.writeln();
      }
    }

    return entry.toString();
  }

  List<RichGitCommit> _filteredAndSortedCommits() {
    final commits = update.commits
        .where(
          (commit) =>
              !commit.parsedMessage.isMergeCommit &&
              commit.parsedMessage.isVersionableCommit,
        )
        .toList();

    // Sort so that Breaking Changes appear at the top.
    commits.sort((a, b) {
      final r = a.parsedMessage.isBreakingChange
          .toString()
          .compareTo(b.parsedMessage.isBreakingChange.toString());
      if (r != 0) return r;
      return b.parsedMessage.type!.compareTo(a.parsedMessage.type!);
    });

    return commits;
  }
}

extension on StringBuffer {
  void writeBold(String string) {
    write('**');
    write(string);
    write('**');
  }

  void writePunctuated(String string) {
    write(string);

    final shouldPunctuate = !string.contains(RegExp(r'[\.\?\!]$'));
    if (shouldPunctuate) {
      write('.');
    }
  }
}
