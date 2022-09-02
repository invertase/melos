// ignore_for_file: avoid_print
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
  final parsedCommit = ConventionalCommit.tryParse(commitMessageExample)!;

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

  print(parsedCommit.footers);
  // : ['Co-authored-by: @Salakar', 'Refs #123 #456']

  print(parsedCommit.isMergeCommit);
  // : false
}
