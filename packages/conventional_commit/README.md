<p align="center">
  <a href="https://invertase.io">
    <img src="https://static.invertase.io/assets/invertase-logo-small.png"><br/><br/>
  </a>
  <span>A library for parsing conventional git commit messages.</span>
</p>

---

Parse a git commit message into a [Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/) format.

## Example

```dart
import 'package:conventional_commit/conventional_commit.dart';

const commitMessageExample = '''
feat(cool): An exciting new feature.

A body describing this commit in more detail.

The body in this example is multi-line.

BREAKING CHANGE: This is a breaking change because of X Y Z.

Co-authored-by: @Salakar
Refs #123 #456
''';

void main() {
  final parsedCommit = ConventionalCommit.parse(commitMessageExample);

  print(parsedCommit.description);
  // : An exciting new feature.

  print(parsedCommit.body);
  // : A body describing this commit in more detail.
  // :
  // : The body in this example is multi-line.

  print(parsedCommit.type);
  // : feat

  print(parsedCommit.scopes);
  // : ['cool']

  print(parsedCommit.isBreakingChange);
  // : true

  print(parsedCommit.breakingChangeDescription);
  // : This is a breaking change because of X Y Z.

  print(parsedCommit.semverReleaseType);
  // : SemverReleaseType.major

  print(parsedCommit.footers);
  // : ['Co-authored-by: @Salakar', 'Refs #123 #456']

  print(parsedCommit.isMergeCommit);
  // : false

  print(parsedCommit.isVersionableCommit);
  // : true
}
```

## License

- See [LICENSE](/LICENSE)

---

<p>
  <img align="left" width="75px" src="https://static.invertase.io/assets/invertase-logo-small.png">
  <p align="left">
    Built and maintained with 💛 by <a href="https://invertase.io">Invertase</a>.
  </p>
  <p align="left">
    <a href="https://invertase.link/discord"><img src="https://img.shields.io/discord/295953187817521152.svg?style=flat-square&colorA=7289da&label=Chat%20on%20Discord" alt="Chat on Discord"></a>
    <a href="https://twitter.com/invertaseio"><img src="https://img.shields.io/twitter/follow/invertaseio.svg?style=flat-square&colorA=1da1f2&colorB=&label=Follow%20on%20Twitter" alt="Follow on Twitter"></a>
  </p>
</p>

---
