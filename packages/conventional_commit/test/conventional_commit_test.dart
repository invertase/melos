import 'package:collection/collection.dart';
import 'package:conventional_commit/conventional_commit.dart';
import 'package:test/test.dart';

const bodyExample = '''
A body describing this commit in more detail.

The body in this example is multi-line.
''';

const commitMessageWithBodyExample = '''
refactor: did something

$bodyExample

BREAKING CHANGE: This commit breaks everything.

Reviewed-by: @fooBarUser
Co-authored-by: @Salakar

Refs #123 #1234
''';

const commitMessageWithoutBodyExample = '''
refactor: did something

BREAKING CHANGE: This commit breaks everything.

Reviewed-by: @fooBarUser
Co-authored-by: @Salakar

Refs #123 #1234
''';

const commitMessageStarScope = '''
feat(*): a new something (#1234)

This also fixes an issue something else.
''';

const commitMessageHyphenScope = '''
feat(remote-config)!: add support for onConfigUpdated (#10647)

This PR is a breaking change for Remote Config since we're removing the ChangeNotifier mixin that came with FirebaseRemoteConfig. You should handle the state of the RemoteConfig using your own state provider.
''';

void main() {
  group('$ConventionalCommit', () {
    test('invalid commit messages', () {
      expect(ConventionalCommit.tryParse('new feature!!!'), isNull);
      expect(ConventionalCommit.tryParse(''), isNull);
      expect(ConventionalCommit.tryParse(': new feature'), isNull);
      expect(ConventionalCommit.tryParse(' (): new feature'), isNull);
      expect(ConventionalCommit.tryParse('feat()'), isNull);
    });

    test('accepts commit messages with or without a space before description',
        () {
      expect(ConventionalCommit.tryParse('feat:new thing'), isNotNull);
      expect(ConventionalCommit.tryParse('feat(foo):new thing'), isNotNull);
      expect(ConventionalCommit.tryParse('feat: new thing'), isNotNull);
      expect(ConventionalCommit.tryParse('feat(foo): new thing'), isNotNull);
    });

    test('accepts commit messages with prefix before conventional commit type',
        () {
      expect(
        ConventionalCommit.tryParse('Merged PR 404: feat(scope): new feature'),
        isNotNull,
      );
      expect(
        ConventionalCommit.tryParse('Merge pull request #404: feat(foo):bar'),
        isNotNull,
      );
      expect(
        ConventionalCommit.tryParse('Merged branch develop to main: fix: test'),
        isNotNull,
      );
    });

    test(
      'correctly parses commit with prefix before conventional commit type',
      () {
        const commitMessage = 'Merged PR 404: feat(scope): new feature';
        final conventionalCommit = ConventionalCommit.tryParse(commitMessage)!;
        expect(conventionalCommit.type, 'feat');
        expect(conventionalCommit.scopes, ['scope']);
        expect(conventionalCommit.description, 'new feature');
        expect(conventionalCommit.isMergeCommit, true);
      },
    );

    test('parses merge commits which are not conventional commits', () {
      const commitMessage = 'Merged foo into bar';
      final conventionalCommit = ConventionalCommit.tryParse(commitMessage)!;
      expect(conventionalCommit.type, isNull);
      expect(conventionalCommit.scopes, isEmpty);
      expect(conventionalCommit.description, isNull);
      expect(conventionalCommit.body, isNull);
      expect(conventionalCommit.header, commitMessage);
      expect(conventionalCommit.isMergeCommit, true);
    });

    test('correctly handles messages with a `*` scope', () {
      final commit = ConventionalCommit.tryParse(commitMessageStarScope);
      expect(commit, isNotNull);
      expect(commit!.description, equals('a new something (#1234)'));
      expect(commit.body, equals('This also fixes an issue something else.'));
      expect(commit.type, equals('feat'));
      expect(commit.scopes, equals(['*']));
    });

    test('correctly handles messages with a scope that contains "-"', () {
      final commit = ConventionalCommit.tryParse(commitMessageHyphenScope);
      expect(commit, isNotNull);
      expect(
        commit!.description,
        equals('add support for onConfigUpdated (#10647)'),
      );
      expect(
        commit.body,
        equals(
          "This PR is a breaking change for Remote Config since we're removing "
          'the ChangeNotifier mixin that came with FirebaseRemoteConfig. You '
          'should handle the state of the RemoteConfig using your own state '
          'provider.',
        ),
      );
      expect(commit.type, equals('feat'));
      expect(commit.isBreakingChange, equals(true));
      expect(commit.scopes, equals(['remote-config']));
    });

    test('header', () {
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.header,
        equals('docs: foo bar'),
      );
      expect(
        ConventionalCommit.tryParse('docs!: foo bar')!.header,
        equals('docs!: foo bar'),
      );
      expect(
        ConventionalCommit.tryParse('docs(scope): foo bar')!.header,
        equals('docs(scope): foo bar'),
      );
      expect(
        ConventionalCommit.tryParse('docs(scope,dope): foo bar')!.header,
        equals('docs(scope,dope): foo bar'),
      );
      expect(
        ConventionalCommit.tryParse('docs(scope,dope)!: foo bar')!.header,
        equals('docs(scope,dope)!: foo bar'),
      );
    });

    test('scopes', () {
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.scopes,
        equals(<String>[]),
      );
      expect(
        ConventionalCommit.tryParse('docs!: foo bar')!.scopes,
        equals(<String>[]),
      );
      expect(
        ConventionalCommit.tryParse('docs(scope): foo bar')!.scopes,
        equals(['scope']),
      );
      expect(
        ConventionalCommit.tryParse('docs(scope,dope): foo bar')!.scopes,
        equals(['scope', 'dope']),
      );
      expect(
        ConventionalCommit.tryParse('docs(scope,dope)!: foo bar')!.scopes,
        equals(['scope', 'dope']),
      );
      // Should support spaces in comma delimited scope list.
      expect(
        ConventionalCommit.tryParse('docs(scope, dope)!: foo bar')!.scopes,
        equals(['scope', 'dope']),
      );
    });

    test('type', () {
      expect(
        ConventionalCommit.tryParse('build: foo bar')!.type,
        equals('build'),
      );
      expect(
        ConventionalCommit.tryParse('chore: foo bar')!.type,
        equals('chore'),
      );
      expect(
        ConventionalCommit.tryParse('ci: foo bar')!.type,
        equals('ci'),
      );
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.type,
        equals('docs'),
      );
      expect(
        ConventionalCommit.tryParse('feat!: foo bar')!.type,
        equals('feat'),
      );
      expect(
        ConventionalCommit.tryParse('bug!: foo bar')!.type,
        equals('bug'),
      );
      expect(
        ConventionalCommit.tryParse('perf(scope): foo bar')!.type,
        equals('perf'),
      );
      expect(
        ConventionalCommit.tryParse('refactor(scope): foo bar')!.type,
        equals('refactor'),
      );
      expect(
        ConventionalCommit.tryParse('revert(scope,dope): foo bar')!.type,
        equals('revert'),
      );
      expect(
        ConventionalCommit.tryParse('style(scope,dope): foo bar')!.type,
        equals('style'),
      );
      expect(
        ConventionalCommit.tryParse('test(scope)!: foo bar')!.type,
        equals('test'),
      );
      expect(
        ConventionalCommit.tryParse('FIX: foo bar')!.type,
        equals('fix'),
      );
    });

    test('isBreakingChange', () {
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.isBreakingChange,
        isFalse,
      );
      expect(
        ConventionalCommit.tryParse('docs!: foo bar')!.isBreakingChange,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('docs(scope): foo bar')!.isBreakingChange,
        isFalse,
      );
      expect(
        ConventionalCommit.tryParse('docs(scope,dope): foo bar')!
            .isBreakingChange,
        isFalse,
      );
      expect(
        ConventionalCommit.tryParse('docs(scope,dope)!: foo bar')!
            .isBreakingChange,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse(
          'docs(scope): foo bar \n\nBREAKING: I broke something.',
        )!
            .isBreakingChange,
        isTrue,
      );
      // Confirm exact matching of `BREAKING: ` (with space after colon).
      expect(
        ConventionalCommit.tryParse(
          'docs(scope): foo bar \n\nBREAKING:I broke something.',
        )!
            .isBreakingChange,
        isFalse,
      );
      expect(
        ConventionalCommit.tryParse(
          'docs(scope): foo bar \n\nBREAKING CHANGE: I broke something.',
        )!
            .isBreakingChange,
        isTrue,
      );
      // Confirm exact matching of `BREAKING CHANGE: ` (with space after colon).
      expect(
        ConventionalCommit.tryParse(
          'docs(scope): foo bar \n\nBREAKING CHANGE:I broke something.',
        )!
            .isBreakingChange,
        isFalse,
      );
    });

    test('breakingChangeDescription', () {
      // Should be null if isBreakingChange is false.
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.breakingChangeDescription,
        isNull,
      );
      expect(
        ConventionalCommit.tryParse('docs(scope): foo bar')!
            .breakingChangeDescription,
        isNull,
      );
      expect(
        ConventionalCommit.tryParse('docs(scope,dope): foo bar')!
            .breakingChangeDescription,
        isNull,
      );

      // Should be identical to commit description if BREAKING footer with the
      // description is not used.
      //  - without scopes
      expect(
        ConventionalCommit.tryParse('docs!: foo bar')!
            .breakingChangeDescription,
        equals('foo bar'),
      );
      // - with scopes
      expect(
        ConventionalCommit.tryParse('docs(scope,dope)!: foo bar')!
            .breakingChangeDescription,
        equals('foo bar'),
      );

      // Should be equal to the BREAKING footer message if specified.
      expect(
        ConventionalCommit.tryParse(
          'docs(scope): foo bar \n\nBREAKING: I broke something.',
        )!
            .breakingChangeDescription,
        equals('I broke something.'),
      );

      // Should be equal to the BREAKING CHANGE footer message if specified.
      expect(
        ConventionalCommit.tryParse(
          'docs(scope): foo bar \n\nBREAKING CHANGE: I broke something again.',
        )!
            .breakingChangeDescription,
        equals('I broke something again.'),
      );
    });

    test('isMergeCommit', () {
      expect(
        ConventionalCommit.tryParse('docs: Merge foo bar')!.isMergeCommit,
        isFalse,
      );
      expect(
        ConventionalCommit.tryParse("Merge branch 'main' of invertase/melos")!
            .isMergeCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('Merged PR #0: fix: foo')!.isMergeCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('docs!: foo bar')!.isMergeCommit,
        isFalse,
      );
      expect(
        ConventionalCommit.tryParse('docs(scope): Merge foo bar')!
            .isMergeCommit,
        isFalse,
      );
      expect(
        ConventionalCommit.tryParse('docs(scope,dope)!: Merge foo bar')!
            .isMergeCommit,
        isFalse,
      );
    });

    test('description', () {
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.description,
        equals('foo bar'),
      );
      expect(
        ConventionalCommit.tryParse('docs!: foo bar')!.description,
        equals('foo bar'),
      );
      expect(
        ConventionalCommit.tryParse('docs(scope): foo bar')!.description,
        equals('foo bar'),
      );
      expect(
        ConventionalCommit.tryParse('docs(scope,dope)!: foo bar')!.description,
        equals('foo bar'),
      );
    });

    test('body', () {
      // With a multi-line/paragraph body.
      expect(
        ConventionalCommit.tryParse(commitMessageWithBodyExample)!.body,
        equals(bodyExample.trim()),
      );

      // Without a body it should be null.
      expect(
        ConventionalCommit.tryParse(commitMessageWithoutBodyExample)!.body,
        isNull,
      );
    });

    test('footers', () {
      // With a multi-line/paragraph body.
      final commitWithBodyParsed =
          ConventionalCommit.tryParse(commitMessageWithBodyExample)!;
      // Body should not leak into footers.
      expect(
        commitWithBodyParsed.footers.length,
        equals(3),
      );
      // Footers should exclude the breaking change footer.
      expect(
        commitWithBodyParsed.footers.firstWhereOrNull(
          (element) => element.contains('BREAKING'),
        ),
        isNull,
      );
      expect(
        commitWithBodyParsed.footers,
        equals([
          'Reviewed-by: @fooBarUser',
          'Co-authored-by: @Salakar',
          'Refs #123 #1234',
        ]),
      );

      // Footers should still parse without a body.
      final commitWithoutBodyParsed =
          ConventionalCommit.tryParse(commitMessageWithoutBodyExample)!;
      // Header should not leak into footers.
      expect(
        commitWithoutBodyParsed.footers.firstWhereOrNull(
          (element) => element.contains('refactor: did something'),
        ),
        isNull,
      );
      expect(
        commitWithoutBodyParsed.footers.length,
        equals(3),
      );
      expect(
        commitWithoutBodyParsed.footers,
        equals([
          'Reviewed-by: @fooBarUser',
          'Co-authored-by: @Salakar',
          'Refs #123 #1234',
        ]),
      );
    });
  });
}
