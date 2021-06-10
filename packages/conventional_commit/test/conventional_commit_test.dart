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

import 'package:conventional_commit/conventional_commit.dart';
import 'package:test/test.dart';
import 'package:collection/collection.dart';

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

void main() {
  group('$ConventionalCommit', () {
    test('invalid commit messages', () {
      expect(ConventionalCommit.tryParse('new feature!!!'), isNull);
      expect(ConventionalCommit.tryParse(''), isNull);
      expect(ConventionalCommit.tryParse(': new feature'), isNull);
      expect(ConventionalCommit.tryParse(' (): new feature'), isNull);
      expect(ConventionalCommit.tryParse('feat()'), isNull);
      expect(ConventionalCommit.tryParse('custom: new feature'), isNull);
    });

    test('correctly handles messages with a `*` scope', () {
      final commit = ConventionalCommit.tryParse(commitMessageStarScope);
      expect(commit, isNotNull);
      expect(commit!.description, equals('a new something (#1234)'));
      expect(commit.body, equals('This also fixes an issue something else.'));
      expect(commit.type, equals('feat'));
      expect(commit.scopes, equals(['*']));
      expect(commit.isVersionableCommit, isTrue);
      expect(commit.semverReleaseType, SemverReleaseType.minor);
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
                'docs(scope): foo bar \n\nBREAKING:I broke something.')!
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
          ConventionalCommit.tryParse('docs: foo bar')!
              .breakingChangeDescription,
          isNull);
      expect(
          ConventionalCommit.tryParse('docs(scope): foo bar')!
              .breakingChangeDescription,
          isNull);
      expect(
          ConventionalCommit.tryParse('docs(scope,dope): foo bar')!
              .breakingChangeDescription,
          isNull);

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
                'docs(scope): foo bar \n\nBREAKING: I broke something.')!
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
        ConventionalCommit.tryParse("Merge branch 'master' of invertase/melos")!
            .isMergeCommit,
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

    test('isVersionableCommit', () {
      expect(
        ConventionalCommit.tryParse('chore!: foo bar')!.isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('refactor(scope): foo bar')!
            .isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('revert(scope,dope)!: foo bar')!
            .isVersionableCommit,
        isTrue,
      );
      expect(
        ConventionalCommit.tryParse('ci(scope,dope): foo bar')!
            .isVersionableCommit,
        isFalse,
      );
    });

    test('semverReleaseType', () {
      expect(
        ConventionalCommit.tryParse('chore!: foo bar')!.semverReleaseType,
        equals(SemverReleaseType.major),
      );
      expect(
        ConventionalCommit.tryParse('docs: foo bar')!.semverReleaseType,
        equals(SemverReleaseType.patch),
      );
      expect(
        ConventionalCommit.tryParse('refactor(scope): foo bar')!
            .semverReleaseType,
        equals(SemverReleaseType.patch),
      );
      expect(
        ConventionalCommit.tryParse('feat(scope,dope): foo bar')!
            .semverReleaseType,
        equals(SemverReleaseType.minor),
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
