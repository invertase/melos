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

import 'package:args/command_runner.dart' show Command;
import 'package:pool/pool.dart' show Pool;

import '../common/conventional_commit.dart';
import '../common/git.dart';
import '../common/logger.dart';
import '../common/package.dart';
import '../common/workspace.dart';

// TODO this command is incomplete and currently being used for local testing purposes
class VersionCommand extends Command {
  @override
  final String name = 'version';

  @override
  final List<String> aliases = ['v'];

  @override
  final String description =
      'Automatically version and generate changelogs for all packages that have had commits since this command was last ran.';

  @override
  void run() async {
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos version")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(currentWorkspace.path)}${logger.ansi.noColor}\n');

    var pool = Pool(10);

    // TODO just testing
    await pool.forEach<MelosPackage, void>(currentWorkspace.packages,
        (package) {
      return commitsInPackage(
              since: '63dd7fe83b0d628f9b965c1aca24a8a8d0684803',
              package: package)
          .then((commits) {
        if (commits.isEmpty) {
          return;
        }
        print('       ');
        print(package.name);
        commits.forEach((commit) {
          var conventionalCommit =
              ConventionalCommit.fromCommitMessage(commit.message);
          if (conventionalCommit != null) {
            print(conventionalCommit.asChangelogEntry);
          }
        });
        print('       ');
      });
    }).drain();

    logger.stdout('');
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos version")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(currentWorkspace.path)}${logger.ansi.noColor}');
  }
}
