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

class VersionCommand extends Command {
  @override
  final String name = 'version';

  @override
  final String description =
      'Automatically version and generate changelogs for all packages.';

  @override
  void run() async {
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos version")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(currentWorkspace.path)}${logger.ansi.noColor}\n');

    var pool = Pool(10);

    var packageCommits = {};
    await pool.forEach<MelosPackage, void>(currentWorkspace.packages,
        (package) {
      return gitCommitsForPackage(package,
              since: globalResults['since'] as String)
          .then((commits) {
        packageCommits[package.name] = commits
            .map((commit) =>
                ConventionalCommit.fromCommitMessage(commit.message))
            .where((element) => element != null)
            .toList();
      });
    }).drain();

    var packagesWithVersionableCommits = {};
    packageCommits.entries.forEach((entry) {
      String packageName = entry.key as String;
      List<ConventionalCommit> packageCommits =
          entry.value as List<ConventionalCommit>;
      List<ConventionalCommit> versionableCommits =
          packageCommits.where((e) => e.isVersionableCommit).toList();
      if (versionableCommits.isNotEmpty) {
        packagesWithVersionableCommits[packageName] = versionableCommits;
        // print('');
        // print('');
        // print(packageName);
        // print(versionableCommits.map((e) => e.asChangelogEntry).join('\n'));
      }
    });

    Set<MelosPackage> packagesToVersion = <MelosPackage>{};
    Set<MelosPackage> dependentPackagesToVersion = <MelosPackage>{};
    currentWorkspace.packages.forEach((package) {
      if (packagesWithVersionableCommits.containsKey(package.name)) {
        packagesToVersion.add(package);
        dependentPackagesToVersion.addAll(package.dependentsInWorkspace);
      }
    });

    print('');
    print('');
    print(packagesToVersion);
    print('');
    print('');
    print('');
    print(dependentPackagesToVersion);

    logger.stdout('');
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos version")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(currentWorkspace.path)}${logger.ansi.noColor}');
  }
}
