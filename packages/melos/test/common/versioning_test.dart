import 'package:conventional_commit/conventional_commit.dart';
import 'package:melos/src/common/versioning.dart';
import 'package:test/test.dart';

void main() {
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
      ConventionalCommit.tryParse('feat(*): foo bar')!.isVersionableCommit,
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
}
