import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../logging.dart';
import '../package.dart';
import 'git_commit.dart';
import 'git_repository.dart';
import 'io.dart';
import 'pending_package_update.dart';
import 'versioning.dart';

class Changelog {
  Changelog(this.package, this.version, this.logger);

  final Package package;
  final Version version;
  final MelosLogger logger;

  String get markdown {
    throw UnimplementedError();
  }

  String get path {
    return p.join(package.path, 'CHANGELOG.md');
  }

  @override
  String toString() {
    return markdown;
  }

  Future<String> read() async {
    if (fileExists(path)) {
      return readTextFile(path);
    }
    return '';
  }

  Future<void> write() async {
    var contents = await read();
    if (contents.contains(markdown)) {
      logger.trace(
        'Identical changelog content for ${package.name} v$version already '
        'exists, skipping.',
      );
      return;
    }
    contents = '$markdown$contents';

    await writeTextFileAsync(path, contents);
  }
}

class MelosChangelog extends Changelog {
  MelosChangelog(this.update, MelosLogger logger)
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
    final config = update.workspace.config;
    final includeDate = config.commands.version.includeDateInChangelogEntry;

    // Changelog entry header.
    write('## ');
    if (includeDate) {
      final now = DateTime.now();

      write(update.nextVersion);
      write(' - ');
      writeln(now.toFormattedString());
    } else {
      writeln(update.nextVersion);
    }
    writeln();

    if (update.reason == PackageUpdateReason.dependency) {
      // Dependency change entry.
      writeln(' - Update a dependency to the latest release.');
      writeln();
    }

    if (update.reason == PackageUpdateReason.lockstep) {
      // Lockstep version bump entry for a package without changes of its own.
      writeln(
        ' - Bump version to keep all packages in the workspace in lockstep.',
      );
      writeln();
    }

    if (update.reason == PackageUpdateReason.graduate &&
        !update.hasChangelogCommits) {
      // Package graduation entry without any new commits since the last
      // pre-release.
      writeln(
        ' - Graduate package to a stable release. See pre-releases prior to '
        'this version for changelog entries.',
      );
      writeln();
    }

    if (update.reason == PackageUpdateReason.commit ||
        update.reason == PackageUpdateReason.manual ||
        (update.reason == PackageUpdateReason.graduate &&
            update.hasChangelogCommits)) {
      // Breaking change note.
      if (update.hasBreakingChanges) {
        writeln('> Note: This release has breaking changes.');
        writeln();
      }

      writePackageUpdateChanges(update);
    }
  }

  void writePackageUpdateChanges(
    MelosPendingPackageUpdate update, {
    String groupHeadingPrefix = '###',
  }) {
    final config = update.workspace.config;
    final repository = config.repository;
    final groupCommits =
        update.groupCommits ??
        config.commands.version.groupChangelogEntriesByType;

    String processCommitHeader(String header) =>
        repository != null ? header.withIssueLinks(repository) : header;

    // User provided changelog entry message.
    if (update.userChangelogMessage != null) {
      writeln(' - ${update.userChangelogMessage}');
      writeln();
    }

    // Entries for commits included in new version.
    final commits = _filteredAndSortedCommits(update);
    if (commits.isEmpty) {
      return;
    }

    if (groupCommits) {
      final commitsByType = <String, List<RichGitCommit>>{};
      for (final commit in commits) {
        (commitsByType[commit.parsedMessage.type!] ??= []).add(commit);
      }

      for (final type in _sortedCommitTypes(commitsByType.keys)) {
        writeln('$groupHeadingPrefix ${_commitTypeHeader(type)}');
        writeln();
        for (final commit in commitsByType[type]!) {
          writeCommitEntry(
            update,
            commit,
            processCommitHeader: processCommitHeader,
            includeType: false,
          );
        }
        writeln();
      }
    } else {
      for (final commit in commits) {
        writeCommitEntry(
          update,
          commit,
          processCommitHeader: processCommitHeader,
          includeType: true,
        );
      }
      writeln();
    }
  }

  void writeCommitEntry(
    MelosPendingPackageUpdate update,
    RichGitCommit commit, {
    required String Function(String) processCommitHeader,
    required bool includeType,
  }) {
    final config = update.workspace.config;
    final repository = config.repository;
    final version = config.commands.version;
    final parsedMessage = commit.parsedMessage;

    write(' - ');

    if (parsedMessage.isBreakingChange) {
      writeBold('BREAKING');
      write(' ');
    }

    if (includeType) {
      writeBold(parsedMessage.type!.toUpperCase());
      if (version.includeScopes && parsedMessage.scopes.isNotEmpty) {
        write('(');
        write(parsedMessage.scopes.join(','));
        write(')');
      }
      write(': ');
    } else if (version.includeScopes && parsedMessage.scopes.isNotEmpty) {
      // When grouping by type the type is the heading, so only the scope is
      // written as a prefix.
      writeBold(parsedMessage.scopes.join(','));
      write(': ');
    }

    writePunctuated(processCommitHeader(parsedMessage.description!));

    if (version.linkToCommits || version.includeCommitId) {
      final shortCommitId = commit.id.substring(0, 8);
      final commitUrl = repository!.commitUrl(commit.id);
      write(' (');
      if (version.linkToCommits) {
        writeLink(shortCommitId, uri: commitUrl.toString());
      } else {
        write(shortCommitId);
      }
      write(')');
    }

    writeln();

    if (!version.includeCommitBody) {
      return;
    }
    if (parsedMessage.body == null) {
      return;
    }

    final shouldWriteBody =
        !version.commitBodyOnlyBreaking || parsedMessage.isBreakingChange;

    if (shouldWriteBody) {
      writeln();
      for (final line in parsedMessage.body!.split('\n')) {
        write(' ' * 4);
        writeln(line);
      }
      writeln();
    }
  }
}

/// Conventional commit types mapped to their changelog group headers, in the
/// order they should appear when grouping changelog entries by type.
const _commitTypeHeaders = {
  'feat': 'Features',
  'fix': 'Bug Fixes',
  'perf': 'Performance Improvements',
  'refactor': 'Code Refactoring',
  'revert': 'Reverts',
  'docs': 'Documentation',
  'style': 'Styles',
  'test': 'Tests',
  'build': 'Build System',
  'ci': 'Continuous Integration',
  'chore': 'Chores',
};

String _commitTypeHeader(String type) {
  final known = _commitTypeHeaders[type.toLowerCase()];
  if (known != null) {
    return known;
  }
  if (type.isEmpty) {
    return type;
  }
  return '${type[0].toUpperCase()}${type.substring(1)}';
}

List<String> _sortedCommitTypes(Iterable<String> types) {
  final order = _commitTypeHeaders.keys.toList();
  return types.toList()..sort((a, b) {
    final indexA = order.indexOf(a.toLowerCase());
    final indexB = order.indexOf(b.toLowerCase());
    if (indexA != -1 && indexB != -1) {
      return indexA.compareTo(indexB);
    }
    if (indexA != -1) {
      return -1;
    }
    if (indexB != -1) {
      return 1;
    }
    return a.compareTo(b);
  });
}

List<RichGitCommit> _filteredAndSortedCommits(
  MelosPendingPackageUpdate update,
) {
  final commits = update.commits
      .where((commit) => commit.parsedMessage.includeInChangelog)
      .toList();

  // Sort so that Breaking Changes appear at the top.
  commits.sort((a, b) {
    final r = a.parsedMessage.isBreakingChange.toString().compareTo(
      b.parsedMessage.isBreakingChange.toString(),
    );
    if (r != 0) {
      return r;
    }
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

extension DateTimeExtension on DateTime {
  /// Returns a formatted string in the format `yyyy-MM-dd`.
  @internal
  String toFormattedString() {
    return toIso8601String().substring(0, 10);
  }
}
