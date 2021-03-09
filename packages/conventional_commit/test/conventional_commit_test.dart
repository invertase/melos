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

void main() {
  group('$ConventionalCommit', () {
    test('invalid commit messages', () {
      expect(ConventionalCommit.parse('new feature!!!'), isNull);
      expect(() {
        ConventionalCommit.parse(null);
      }, throwsA(isA<AssertionError>()));
      expect(ConventionalCommit.parse(''), isNull);
      expect(ConventionalCommit.parse(': new feature'), isNull);
      expect(ConventionalCommit.parse(' (): new feature'), isNull);
      expect(ConventionalCommit.parse('feat()'), isNull);
      expect(ConventionalCommit.parse('custom: new feature'), isNull);
    });

    test('header', () {
      expect(ConventionalCommit.parse('docs: foo bar').header,
          equals('docs: foo bar'));
      expect(ConventionalCommit.parse('docs!: foo bar').header,
          equals('docs!: foo bar'));
      expect(ConventionalCommit.parse('docs(scope): foo bar').header,
          equals('docs(scope): foo bar'));
      expect(ConventionalCommit.parse('docs(scope,dope): foo bar').header,
          equals('docs(scope,dope): foo bar'));
      expect(ConventionalCommit.parse('docs(scope,dope)!: foo bar').header,
          equals('docs(scope,dope)!: foo bar'));
    });

    test('scopes', () {
      expect(ConventionalCommit.parse('docs: foo bar').scopes, equals([]));
      expect(ConventionalCommit.parse('docs!: foo bar').scopes, equals([]));
      expect(ConventionalCommit.parse('docs(scope): foo bar').scopes,
          equals(['scope']));
      expect(ConventionalCommit.parse('docs(scope,dope): foo bar').scopes,
          equals(['scope', 'dope']));
      expect(ConventionalCommit.parse('docs(scope,dope)!: foo bar').scopes,
          equals(['scope', 'dope']));
      // Should support spaces in comma delimited scope list.
      expect(ConventionalCommit.parse('docs(scope, dope)!: foo bar').scopes,
          equals(['scope', 'dope']));
    });

    test('type', () {
      expect(ConventionalCommit.parse('build: foo bar').type, equals('build'));
      expect(ConventionalCommit.parse('chore: foo bar').type, equals('chore'));
      expect(ConventionalCommit.parse('ci: foo bar').type, equals('ci'));
      expect(ConventionalCommit.parse('docs: foo bar').type, equals('docs'));
      expect(ConventionalCommit.parse('feat!: foo bar').type, equals('feat'));
      expect(ConventionalCommit.parse('bug!: foo bar').type, equals('bug'));
      expect(ConventionalCommit.parse('perf(scope): foo bar').type,
          equals('perf'));
      expect(ConventionalCommit.parse('refactor(scope): foo bar').type,
          equals('refactor'));
      expect(ConventionalCommit.parse('revert(scope,dope): foo bar').type,
          equals('revert'));
      expect(ConventionalCommit.parse('style(scope,dope): foo bar').type,
          equals('style'));
      expect(ConventionalCommit.parse('test(scope)!: foo bar').type,
          equals('test'));
    });

    test('isBreakingChange', () {
      expect(
          ConventionalCommit.parse('docs: foo bar').isBreakingChange, isFalse);
      expect(
          ConventionalCommit.parse('docs!: foo bar').isBreakingChange, isTrue);
      expect(ConventionalCommit.parse('docs(scope): foo bar').isBreakingChange,
          isFalse);
      expect(
          ConventionalCommit.parse('docs(scope,dope): foo bar')
              .isBreakingChange,
          isFalse);
      expect(
          ConventionalCommit.parse('docs(scope,dope)!: foo bar')
              .isBreakingChange,
          isTrue);
      expect(
          ConventionalCommit.parse(
                  'docs(scope): foo bar \n\nBREAKING: I broke something.')
              .isBreakingChange,
          isTrue);
      // Confirm exact matching of `BREAKING: ` (with space after colon).
      expect(
          ConventionalCommit.parse(
                  'docs(scope): foo bar \n\nBREAKING:I broke something.')
              .isBreakingChange,
          isFalse);
      expect(
          ConventionalCommit.parse(
                  'docs(scope): foo bar \n\nBREAKING CHANGE: I broke something.')
              .isBreakingChange,
          isTrue);
      // Confirm exact matching of `BREAKING CHANGE: ` (with space after colon).
      expect(
          ConventionalCommit.parse(
                  'docs(scope): foo bar \n\nBREAKING CHANGE:I broke something.')
              .isBreakingChange,
          isFalse);
    });

    test('breakingChangeDescription', () {
      // Should be null if isBreakingChange is false.
      expect(
          ConventionalCommit.parse('docs: foo bar').breakingChangeDescription,
          isNull);
      expect(
          ConventionalCommit.parse('docs(scope): foo bar')
              .breakingChangeDescription,
          isNull);
      expect(
          ConventionalCommit.parse('docs(scope,dope): foo bar')
              .breakingChangeDescription,
          isNull);

      // Should be identical to commit description if BREAKING footer with the
      // description is not used.
      //  - without scopes
      expect(
          ConventionalCommit.parse('docs!: foo bar').breakingChangeDescription,
          equals('foo bar'));
      // - with scopes
      expect(
          ConventionalCommit.parse('docs(scope,dope)!: foo bar')
              .breakingChangeDescription,
          equals('foo bar'));

      // Should be equal to the BREAKING footer message if specified.
      expect(
          ConventionalCommit.parse(
                  'docs(scope): foo bar \n\nBREAKING: I broke something.')
              .breakingChangeDescription,
          equals('I broke something.'));

      // Should be equal to the BREAKING CHANGE footer message if specified.
      expect(
          ConventionalCommit.parse(
                  'docs(scope): foo bar \n\nBREAKING CHANGE: I broke something again.')
              .breakingChangeDescription,
          equals('I broke something again.'));
    });

    test('isMergeCommit', () {
      expect(ConventionalCommit.parse('docs: Merge foo bar').isMergeCommit,
          isFalse);
      expect(
          ConventionalCommit.parse("Merge branch 'master' of invertase/melos")
              .isMergeCommit,
          isTrue);
      expect(ConventionalCommit.parse('docs!: foo bar').isMergeCommit, isFalse);
      expect(
          ConventionalCommit.parse('docs(scope): Merge foo bar').isMergeCommit,
          isFalse);
      expect(
          ConventionalCommit.parse('docs(scope,dope)!: Merge foo bar')
              .isMergeCommit,
          isFalse);
    });

    test('description', () {
      expect(ConventionalCommit.parse('docs: foo bar').description,
          equals('foo bar'));
      expect(ConventionalCommit.parse('docs!: foo bar').description,
          equals('foo bar'));
      expect(ConventionalCommit.parse('docs(scope): foo bar').description,
          equals('foo bar'));
      expect(ConventionalCommit.parse('docs(scope,dope)!: foo bar').description,
          equals('foo bar'));
    });

    test('isVersionableCommit', () {
      expect(ConventionalCommit.parse('chore!: foo bar').isVersionableCommit,
          isTrue);
      expect(ConventionalCommit.parse('docs: foo bar').isVersionableCommit,
          isTrue);
      expect(
          ConventionalCommit.parse('refactor(scope): foo bar')
              .isVersionableCommit,
          isTrue);
      expect(
          ConventionalCommit.parse('revert(scope,dope)!: foo bar')
              .isVersionableCommit,
          isTrue);
      expect(
          ConventionalCommit.parse('ci(scope,dope): foo bar')
              .isVersionableCommit,
          isFalse);
    });

    test('semverReleaseType', () {
      expect(ConventionalCommit.parse('chore!: foo bar').semverReleaseType,
          equals(SemverReleaseType.major));
      expect(ConventionalCommit.parse('docs: foo bar').semverReleaseType,
          equals(SemverReleaseType.patch));
      expect(
          ConventionalCommit.parse('refactor(scope): foo bar')
              .semverReleaseType,
          equals(SemverReleaseType.patch));
      expect(
          ConventionalCommit.parse('feat(scope,dope): foo bar')
              .semverReleaseType,
          equals(SemverReleaseType.minor));
    });

    test('body', () {
      // With a multi-line/paragraph body.
      expect(ConventionalCommit.parse(commitMessageWithBodyExample).body,
          equals(bodyExample.trim()));

      // Without a body it should be null.
      expect(ConventionalCommit.parse(commitMessageWithoutBodyExample).body,
          isNull);
    });

    test('footers', () {
      // With a multi-line/paragraph body.
      final commitWithBodyParsed =
          ConventionalCommit.parse(commitMessageWithBodyExample);
      // Body should not leak into footers.
      expect(commitWithBodyParsed.footers.length, equals(3));
      // Footers should exclude the breaking change footer.
      expect(
          commitWithBodyParsed.footers.firstWhere(
            (element) => element.contains('BREAKING'),
            orElse: () => null,
          ),
          isNull);
      expect(
          commitWithBodyParsed.footers,
          equals([
            'Reviewed-by: @fooBarUser',
            'Co-authored-by: @Salakar',
            'Refs #123 #1234',
          ]));

      // Footers should still parse without a body.
      final commitWithoutBodyParsed =
          ConventionalCommit.parse(commitMessageWithoutBodyExample);
      // Header should not leak into footers.
      expect(
          commitWithoutBodyParsed.footers.firstWhere(
            (element) => element.contains('refactor: did something'),
            orElse: () => null,
          ),
          isNull);
      expect(commitWithoutBodyParsed.footers.length, equals(3));
      expect(
          commitWithoutBodyParsed.footers,
          equals([
            'Reviewed-by: @fooBarUser',
            'Co-authored-by: @Salakar',
            'Refs #123 #1234',
          ]));
    });
  });
}
