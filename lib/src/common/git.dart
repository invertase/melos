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

import 'dart:io';

import 'git_commit.dart';
import 'package.dart';

Future<List<GitCommit>> commitsInPackage(
    {String since, MelosPackage package}) async {
  final processResult = await Process.run(
      'git',
      [
        '--no-pager',
        'log',
        since != null ? '$since...@' : '@',
        '--pretty=format:%H|||%aN <%aE>|||%ai|||%B||||',
        '--',
        '.',
      ],
      workingDirectory: package.path);

  List<String> rawCommits = (processResult.stdout as String)
      .split('||||\n')
      .where((element) => element.trim().isNotEmpty)
      .toList();

  return rawCommits.map((String rawCommit) {
    var parts = rawCommit.split('|||');
    return GitCommit(
      sha: parts[0].trim(),
      author: parts[1].trim(),
      date: DateTime.parse(parts[2].trim()),
      message: parts[3].trim(),
    );
  }).toList();
}
