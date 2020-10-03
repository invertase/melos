# Conventional Commit

Parse a [conventional Git commit message](https://www.conventionalcommits.org/en/v1.0.0/).

```dart
String message = 'feat(awesome_package): new feature added';
ConventionalCommit commit = ConventionalCommit.fromCommitMessage(message);

print(commit.header); // feat(awesome_package): new feature added
print(commit.scopes); // ['awesome_package']
print(commit.type); // feat
print(commit.isBreakingChange); // false
print(commit.isMergeCommit); // false
print(commit.subject); // new feature added
print(commit.isVersionableCommit); // true
print(commit.semverReleaseType); // SemverReleaseType.minor
```

Valid commit types can be one of the following:

- `build`
- `chore`
- `ci`
- `docs`
- `feat`
- `fix`
- `bug`
- `perf`
- `refactor`
- `revert`
- `style`
- `test`
