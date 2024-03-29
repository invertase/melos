import 'package:conventional_commit/conventional_commit.dart';

class GitCommit {
  GitCommit({
    required this.message,
    required this.author,
    required this.id,
    required this.date,
  });

  final String message;

  final String author;

  final String id;

  final DateTime date;

  @override
  String toString() {
    return '''
GitCommit[
  author="$author",
  id="$id",
  date=${date.toIso8601String()},
  message="${message.replaceAll('\n', '').padRight(60).substring(0, 60).trim()}...",
]''';
  }
}

class RichGitCommit extends GitCommit {
  RichGitCommit({
    required super.author,
    required super.id,
    required super.date,
    required super.message,
    required this.parsedMessage,
  });

  static RichGitCommit? tryParse(GitCommit commit) {
    final parsedMessage = ConventionalCommit.tryParse(commit.message);
    if (parsedMessage == null) {
      return null;
    }

    return RichGitCommit(
      author: commit.author,
      id: commit.id,
      date: commit.date,
      message: commit.message,
      parsedMessage: parsedMessage,
    );
  }

  final ConventionalCommit parsedMessage;

  @override
  String toString() {
    return '''
RichGitCommit[
  author="$author",
  id="$id",
  date=${date.toIso8601String()},
  parsedMessage=$parsedMessage
]''';
  }
}
