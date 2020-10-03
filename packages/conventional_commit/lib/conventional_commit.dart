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

var _conventionalCommitRegex = RegExp(
    r'^(?<type>build|chore|ci|docs|feat|fix|bug|perf|refactor|revert|style|test)(?<scope>\([a-zA-Z0-9_,]+\)?((?=:\s)|(?=!:\s)))?(?<breaking>!)?(?<subject>:\s.*)?|^(?<merge>Merge \w+)');

/// Indicates the semver release type this commit message creates.
enum SemverReleaseType {
  /// A patch release indicates non-breaking changes (e.g. bug fixes).
  patch,

  /// Indicates new API changes have been made (e.g. new features).
  minor,

  /// A major release is when the breaking changes have been introduced.
  major,
}

// TODO(Salakar): parse commit body & footer for more detailed changelogs.

/// A representation of a parsed conventional commit message.
class ConventionalCommit {
  /// A [List] of scopes in the commit, returns empty [List] if no scopes found.
  final List<String> scopes;

  /// The type specified in this commit, e.g. `feat`.
  final String type;

  /// Whether this commit was a breaking change, e.g. `!` was specified after the scopes in the commit message.
  final bool isBreakingChange;

  /// Whether this commit was a merge commit, e.g. `Merge #24 into master`
  final bool isMergeCommit;

  /// Commit message subject (text after the scopes).
  final String subject;

  /// The original commit message header.
  final String header;

  ConventionalCommit._(
      {this.header,
      this.scopes,
      this.type,
      this.isBreakingChange,
      this.subject,
      this.isMergeCommit});

  /// Create a new [ConventionalCommit] from a commit message [String].
  ///
  /// ```dart
  /// var message = 'type(scope)!: commit message subject';
  /// var commit = ConventionalCommit.fromCommitMessage(message);
  /// print(commit);
  /// ```
  factory ConventionalCommit.fromCommitMessage(String commitMessage) {
    assert(commitMessage != null);
    var header = commitMessage.split('\n')[0];
    var match = _conventionalCommitRegex.firstMatch(header);
    if (match == null) return null;

    bool isMergeCommit = match.namedGroup('merge') != null;
    if (isMergeCommit) {
      return ConventionalCommit._(
          header: header,
          isMergeCommit: isMergeCommit,
          isBreakingChange: false,
          scopes: []);
    }

    String type = match.namedGroup('type');
    String subject = (match.namedGroup('subject') ?? '').trim();
    subject = subject.replaceAll(RegExp(r'^:\s'), '').trim();
    if (subject.isEmpty) {
      return null;
    }

    bool isBreakingChange = match.namedGroup('breaking') != null ||
        commitMessage.contains('BREAKING:');
    List<String> scopes = (match.namedGroup('scope') ?? '')
        .replaceAll(RegExp(r'^\('), '')
        .replaceAll(RegExp(r'\)$'), '')
        .split(',')
        .map((e) => e.trim())
        .where((element) => element.isNotEmpty)
        .toList();

    return ConventionalCommit._(
        header: header,
        scopes: scopes,
        type: type,
        subject: subject,
        isBreakingChange: isBreakingChange,
        isMergeCommit: isMergeCommit);
  }

  // TODO(Salakar): allow workspace customization
  bool get isVersionableCommit {
    if (isMergeCommit) return false;
    return isBreakingChange ||
        [
          'docs', // TODO: what if markdown docs and not code docs
          'feat',
          'fix',
          'bug',
          'perf',
          'refactor',
          'revert',
        ].contains(type);
  }

  // TODO(Salakar): allow workspace customization
  SemverReleaseType get semverReleaseType {
    if (isBreakingChange) {
      return SemverReleaseType.major;
    }

    if (type == 'feat') {
      return SemverReleaseType.minor;
    }

    return SemverReleaseType.patch;
  }

  @override
  String toString() {
    return '''ConventionalCommit[
  type="$type",
  subject="$subject",
  scopes=$scopes,
  isMergeCommit=$isMergeCommit,
  isBreakingChange=$isBreakingChange
]''';
  }
}
