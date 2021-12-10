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
    required String author,
    required String id,
    required DateTime date,
    required String message,
    required this.parsedMessage,
  }) : super(author: author, id: id, date: date, message: message);

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
