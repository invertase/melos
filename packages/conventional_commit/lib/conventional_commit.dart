final _mergeCommitPrefixRegex = RegExp('^Merged? (.*?:)?');

final _conventionalCommitHeaderRegex = RegExp(
  r'(?<type>[a-zA-Z0-9_]+)(\((?<scope>[a-zA-Z0-9\-_,\s\*]+)\))?(?<breaking>!)?: ?(?<description>.+)',
);

final _breakingChangeRegex =
    RegExp(r'^BREAKING(\sCHANGE)?:\s(?<description>.*$)', multiLine: true);

final _footerRegex = RegExp(
  r'^(?<footer>(?:[a-z-A-Z0-9\-]+|BREAKING\sCHANGE)(?::\s|\s#).*$)',
  multiLine: true,
);

/// A representation of a parsed conventional commit message.
///
/// Parsing is based upon the Conventional Commits 1.0.0 specification available
/// at https://www.conventionalcommits.org/en/v1.0.0/
class ConventionalCommit {
  ConventionalCommit._({
    required this.header,
    required this.isBreakingChange,
    required this.isMergeCommit,
    required this.scopes,
    this.description,
    this.body,
    this.breakingChangeDescription,
    this.footers = const <String>[],
    this.type,
  });

  /// Create a new [ConventionalCommit] from a commit message [String].
  ///
  /// ```dart main
  /// var message = '''
  /// type(scope)!: commit message description
  ///
  /// Some optional body
  ///
  /// which can be across multiple lines.
  ///
  /// BREAKING CHANGE: A description of what is breaking.
  /// Co-authored-by: @Salakar
  /// ''';
  ///
  /// var commit = ConventionalCommit.fromCommitMessage(message);
  /// print(commit);
  /// ```
  static ConventionalCommit? tryParse(String commitMessage) {
    final header = commitMessage.split('\n')[0];
    final mergeCommitPrefixMatch = _mergeCommitPrefixRegex.firstMatch(header);
    final isMergeCommit = mergeCommitPrefixMatch != null;
    final headerMatch = _conventionalCommitHeaderRegex.firstMatch(
      isMergeCommit ? header.substring(mergeCommitPrefixMatch.end) : header,
    );

    if (headerMatch == null) {
      if (isMergeCommit) {
        return ConventionalCommit._(
          header: header,
          isMergeCommit: isMergeCommit,
          isBreakingChange: false,
          scopes: [],
        );
      }
      return null;
    }

    final type = headerMatch.namedGroup('type')!.toLowerCase();
    final scopes = (headerMatch.namedGroup('scope') ?? '')
        .split(',')
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toList();
    final description = headerMatch.namedGroup('description')!.trim();

    final isBreakingChange = headerMatch.namedGroup('breaking') != null ||
        commitMessage.contains('BREAKING: ') ||
        commitMessage.contains('BREAKING CHANGE: ');

    String? breakingChangeDescription;
    if (isBreakingChange) {
      // If included as a footer, a breaking change MUST consist of the
      // uppercase text BREAKING CHANGE, followed by a colon, space, and
      // description, e.g., BREAKING CHANGE: environment variables now take
      // precedence over config files.
      if (commitMessage.contains('BREAKING: ') ||
          commitMessage.contains('BREAKING CHANGE: ')) {
        final breakingChangeMatch =
            _breakingChangeRegex.firstMatch(commitMessage);
        if (breakingChangeMatch == null) {
          breakingChangeDescription = description;
        } else {
          breakingChangeDescription =
              (breakingChangeMatch.namedGroup('description') ?? description)
                  .trim();
        }
      } else {
        // BREAKING CHANGE: MAY be omitted from the footer section, and the
        // commit description SHALL be used to describe the breaking change.
        breakingChangeDescription = description;
      }
    }

    final commitWithoutHeader =
        commitMessage.split('\n').skip(1).toList().join('\n');

    var footers = _footerRegex
        .allMatches(commitWithoutHeader)
        .map((match) => match.namedGroup('footer') ?? '')
        .map((footer) => footer.trim())
        .where((footer) => footer.isNotEmpty)
        .toList();

    // We assume that anything left over in the commit message after removing
    // the header and footers is the body. This is a quick way to support
    // multi-paragraph multi-line bodies.
    String? body = commitWithoutHeader;
    for (final footer in footers) {
      body = body!.replaceAll(footer, '');
    }
    body = body!.trim();
    if (body.isEmpty) {
      // Should be null if no body specified, or empty in this case.
      body = null;
    }

    // Footers should exclude breaking change footers as they are extracted
    // separately. We remove them after body so it gets removed from body also.
    footers = footers
        .where(
          (footer) =>
              !footer.startsWith('BREAKING: ') &&
              !footer.startsWith('BREAKING CHANGE: '),
        )
        .toList();

    return ConventionalCommit._(
      body: body,
      breakingChangeDescription: breakingChangeDescription,
      description: description,
      footers: footers,
      header: header,
      isBreakingChange: isBreakingChange,
      isMergeCommit: isMergeCommit,
      scopes: scopes,
      type: type,
    );
  }

  /// A [List] of scopes in the commit, returns empty [List] if no scopes found.
  final List<String> scopes;

  /// The type specified in this commit, e.g. `feat`.
  final String? type;

  /// Whether this commit adds a new feature.
  bool get isFeature => type == 'feat';

  /// Whether this commit represents a bug fix.
  bool get isFix => type == 'fix';

  /// Whether this commit was a breaking change, e.g. `!` was specified after
  /// the scopes in the commit message.
  final bool isBreakingChange;

  /// The description of the breaking change, e.g. the text after BREAKING
  /// CHANGE: <description>.
  ///
  /// Will be null if [isBreakingChange] is false. Defaults to [description] if
  /// the `BREAKING CHANGE:` footer format was not used, e.g. only `!` after the
  /// commit type was specified.
  final String? breakingChangeDescription;

  /// Whether this commit was a merge commit, e.g. `Merge #24 into main`
  final bool isMergeCommit;

  /// Commit message description (text after the scopes).
  final String? description;

  /// The original commit message header (this is normally the first line of the
  /// commit message.)
  final String header;

  /// An optional body describing the change in more detail.
  ///
  /// Note this can contain multiple paragraphs separated by new lines.
  final String? body;

  /// Footers other than BREAKING CHANGE: <description> may be provided and
  /// follow a convention similar to git trailer format.
  ///
  /// A footer’s token MUST use "-" in place of whitespace characters, e.g.,
  /// Acked-by (this helps differentiate the footer section from a
  /// multi-paragraph body). An exception is made for BREAKING CHANGE, which MAY
  /// also be used as a token.
  final List<String> footers;

  @override
  String toString() {
    return '''
ConventionalCommit(
  type="$type",
  scopes=$scopes,
  description="$description",
  body="$body",
  isMergeCommit=$isMergeCommit,
  isBreakingChange=$isBreakingChange,
  breakingChangeDescription=$breakingChangeDescription,
  footers=$footers
)''';
  }
}
