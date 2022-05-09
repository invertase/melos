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
import 'git_repository.dart';
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

class MelosChangelog extends Changelog {
  MelosChangelog(this.update, Logger? logger)
      : super(update.package, update.nextVersion, logger);

  final MelosPendingPackageUpdate update;

  @override
  String get markdown {
    return (StringBuffer()..writePackageChangelog(update)).toString();
  }
}

extension MarkdownStringBufferExtension on StringBuffer {
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

  void writeLink(String name, {String? uri}) {
    write('[');
    write(name);
    write(']');
    if (uri != null) {
      write('(');
      write(uri);
      write(')');
    }
  }
}

extension ChangelogStringBufferExtension on StringBuffer {
  void writePackageChangelog(MelosPendingPackageUpdate update) {
    // Changelog entry header.
    write('## ');
    writeln(update.nextVersion);
    writeln();

    if (update.reason == PackageUpdateReason.dependency) {
      // Dependency change entry.
      writeln(' - Update a dependency to the latest release.');
      writeln();
    }

    if (update.reason == PackageUpdateReason.graduate) {
      // Package graduation entry.
      writeln(
        ' - Graduate package to a stable release. See pre-releases prior to '
        'this version for changelog entries.',
      );
      writeln();
    }

    if (update.reason == PackageUpdateReason.commit ||
        update.reason == PackageUpdateReason.manual) {
      // Breaking change note.
      if (update.hasBreakingChanges) {
        writeln('> Note: This release has breaking changes.');
        writeln();
      }

      writePackageUpdateChanges(update);
    }
  }

  void writePackageUpdateChanges(MelosPendingPackageUpdate update) {
    final config = update.workspace.config;
    final repository = config.repository;
    final linkToCommits = config.commands.version.linkToCommits ?? false;

    String processCommitHeader(String header) =>
        repository != null ? header.withIssueLinks(repository) : header;

    // User provided changelog entry message.
    if (update.userChangelogMessage != null) {
      writeln(' - ${update.userChangelogMessage}');
      writeln();
    }

    // Entries for commits included in new version.
    final commits = _filteredAndSortedCommits(update);
    if (commits.isNotEmpty) {
      for (final commit in commits) {
        final parsedMessage = commit.parsedMessage;

        write(' - ');

        if (parsedMessage.isBreakingChange) {
          writeBold('BREAKING');
          write(' ');
        }

        if (parsedMessage.isMergeCommit) {
          writePunctuated(processCommitHeader(parsedMessage.header));
        } else {
          writeBold(parsedMessage.type!.toUpperCase());
          write(': ');
          writePunctuated(processCommitHeader(parsedMessage.description!));
        }

        if (linkToCommits) {
          final shortCommitId = commit.id.substring(0, 8);
          final commitUrl = repository!.commitUrl(commit.id);
          write(' (');
          writeLink(shortCommitId, uri: commitUrl.toString());
          write(')');
        }

        writeln();
      }
      writeln();
    }
  }
}

List<RichGitCommit> _filteredAndSortedCommits(
  MelosPendingPackageUpdate update,
) {
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

// https://regex101.com/r/Q1IV9n/1
final _issueLinkRegexp = RegExp(r'#(\d+)');

extension on String {
  String withIssueLinks(HostedGitRepository repository) {
    return replaceAllMapped(_issueLinkRegexp, (match) {
      final issueUrl = repository.issueUrl(match.group(1)!);
      return '[${match.group(0)}]($issueUrl)';
    });
  }
}
