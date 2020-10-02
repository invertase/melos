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

void main() {
  group('$ConventionalCommit', () {
    test('invalid commit messages', () {
      expect(ConventionalCommit.fromCommitMessage('new feature!!!'), isNull);
      expect(() {
        ConventionalCommit.fromCommitMessage(null);
      }, throwsA(isA<AssertionError>()));
      expect(ConventionalCommit.fromCommitMessage(''), isNull);
      expect(ConventionalCommit.fromCommitMessage(': new feature'), isNull);
      expect(ConventionalCommit.fromCommitMessage(' (): new feature'), isNull);
      expect(ConventionalCommit.fromCommitMessage('feat()'), isNull);
      expect(
          ConventionalCommit.fromCommitMessage('custom: new feature'), isNull);
    });

    test('header', () {
      expect(ConventionalCommit.fromCommitMessage('docs: foo bar').header,
          equals('docs: foo bar'));
      expect(ConventionalCommit.fromCommitMessage('docs!: foo bar').header,
          equals('docs!: foo bar'));
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope): foo bar').header,
          equals('docs(scope): foo bar'));
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope,dope): foo bar')
              .header,
          equals('docs(scope,dope): foo bar'));
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope,dope)!: foo bar')
              .header,
          equals('docs(scope,dope)!: foo bar'));
    });

    test('scopes', () {
      expect(ConventionalCommit.fromCommitMessage('docs: foo bar').scopes,
          equals([]));
      expect(ConventionalCommit.fromCommitMessage('docs!: foo bar').scopes,
          equals([]));
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope): foo bar').scopes,
          equals(['scope']));
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope,dope): foo bar')
              .scopes,
          equals(['scope', 'dope']));
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope,dope)!: foo bar')
              .scopes,
          equals(['scope', 'dope']));
    });

    test('type', () {
      expect(ConventionalCommit.fromCommitMessage('build: foo bar').type,
          equals('build'));
      expect(ConventionalCommit.fromCommitMessage('chore: foo bar').type,
          equals('chore'));
      expect(ConventionalCommit.fromCommitMessage('ci: foo bar').type,
          equals('ci'));
      expect(ConventionalCommit.fromCommitMessage('docs: foo bar').type,
          equals('docs'));
      expect(ConventionalCommit.fromCommitMessage('feat!: foo bar').type,
          equals('feat'));
      expect(ConventionalCommit.fromCommitMessage('bug!: foo bar').type,
          equals('bug'));
      expect(ConventionalCommit.fromCommitMessage('perf(scope): foo bar').type,
          equals('perf'));
      expect(
          ConventionalCommit.fromCommitMessage('refactor(scope): foo bar').type,
          equals('refactor'));
      expect(
          ConventionalCommit.fromCommitMessage('revert(scope,dope): foo bar')
              .type,
          equals('revert'));
      expect(
          ConventionalCommit.fromCommitMessage('style(scope,dope): foo bar')
              .type,
          equals('style'));
      expect(ConventionalCommit.fromCommitMessage('test(scope)!: foo bar').type,
          equals('test'));
    });

    test('isBreakingChange', () {
      expect(
          ConventionalCommit.fromCommitMessage('docs: foo bar')
              .isBreakingChange,
          isFalse);
      expect(
          ConventionalCommit.fromCommitMessage('docs!: foo bar')
              .isBreakingChange,
          isTrue);
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope): foo bar')
              .isBreakingChange,
          isFalse);
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope,dope): foo bar')
              .isBreakingChange,
          isFalse);
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope,dope)!: foo bar')
              .isBreakingChange,
          isTrue);
    });

    test('isMergeCommit', () {
      // TODO(ehesp): add truth tests
      expect(
          ConventionalCommit.fromCommitMessage('docs: Merge foo bar')
              .isMergeCommit,
          isFalse);
      expect(
          ConventionalCommit.fromCommitMessage('docs!: foo bar').isMergeCommit,
          isFalse);
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope): Merge foo bar')
              .isMergeCommit,
          isFalse);
      expect(
          ConventionalCommit.fromCommitMessage(
                  'docs(scope,dope)!: Merge foo bar')
              .isMergeCommit,
          isFalse);
    });

    test('subject', () {
      expect(ConventionalCommit.fromCommitMessage('docs: foo bar').subject,
          equals('foo bar'));
      expect(ConventionalCommit.fromCommitMessage('docs!: foo bar').subject,
          equals('foo bar'));
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope): foo bar').subject,
          equals('foo bar'));
      expect(
          ConventionalCommit.fromCommitMessage('docs(scope,dope)!: foo bar')
              .subject,
          equals('foo bar'));
    });

    test('isVersionableCommit', () {
      expect(
          ConventionalCommit.fromCommitMessage('chore!: foo bar')
              .isVersionableCommit,
          isTrue);
      expect(
          ConventionalCommit.fromCommitMessage('docs: foo bar')
              .isVersionableCommit,
          isTrue);
      expect(
          ConventionalCommit.fromCommitMessage('refactor(scope): foo bar')
              .isVersionableCommit,
          isTrue);
      expect(
          ConventionalCommit.fromCommitMessage('revert(scope,dope)!: foo bar')
              .isVersionableCommit,
          isTrue);
      expect(
          ConventionalCommit.fromCommitMessage('ci(scope,dope): foo bar')
              .isVersionableCommit,
          isFalse);
    });

    test('semverReleaseType', () {
      expect(
          ConventionalCommit.fromCommitMessage('chore!: foo bar')
              .semverReleaseType,
          equals(SemverReleaseType.major));
      expect(
          ConventionalCommit.fromCommitMessage('docs: foo bar')
              .semverReleaseType,
          equals(SemverReleaseType.patch));
      expect(
          ConventionalCommit.fromCommitMessage('refactor(scope): foo bar')
              .semverReleaseType,
          equals(SemverReleaseType.patch));
      expect(
          ConventionalCommit.fromCommitMessage('feat(scope,dope): foo bar')
              .semverReleaseType,
          equals(SemverReleaseType.minor));
    });
  });
}
