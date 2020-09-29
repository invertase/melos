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
import 'package:ansi_styles/ansi_styles.dart';

import '../common/conventional_commit.dart';
import '../common/git.dart';
import '../common/logger.dart';
import '../common/package.dart';
import '../common/pending_package_update.dart';
import '../common/utils.dart';
import '../common/workspace.dart';

class VersionCommand extends Command {
  @override
  final String name = 'version';

  @override
  final String description =
      'Automatically version and generate changelogs for all packages. Supports all Melos filtering flags.';

  VersionCommand() {
    argParser.addFlag('prerelease',
        abbr: 'p',
        defaultsTo: false,
        negatable: false,
        help:
            'Version any packages with changes as a prerelease. Cannot be combined with graduate flag.');
    argParser.addFlag('graduate',
        abbr: 'g',
        defaultsTo: false,
        negatable: false,
        help:
            'Graduate current prerelease versioned packages to stable versions, e.g. "0.10.0-dev.1" becomes "0.10.0". Cannot be combined with prerelease flag.');
  }

  @override
  void run() async {
    logger.stdout(AnsiStyles.yellow.bold('melos version'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}\n');

    bool graduate = argResults['graduate'] as bool;
    bool prerelease = argResults['prerelease'] as bool;
    Set<MelosPackage> packagesToVersion = <MelosPackage>{};
    Map<String, List<ConventionalCommit>> packageCommits = {};
    Set<MelosPackage> dependentPackagesToVersion = <MelosPackage>{};
    Map<String, List<ConventionalCommit>> packagesWithVersionableCommits = {};
    List<MelosPendingPackageUpdate> pendingPackageUpdates = [];

    if (graduate && prerelease) {
      logger.stdout(
          '${AnsiStyles.yellow('WARNING:')} graduate & prerelease flags cannot be combined. Versioning will continue with graduate off.');
      graduate = false;
    }

    if (graduate) {
      currentWorkspace.packages.forEach((package) {
        if (package.version.isPreRelease) {
          pendingPackageUpdates.add(MelosPendingPackageUpdate(
            package,
            [],
            PackageUpdateReason.graduate,
            graduate: graduate,
            prerelease: prerelease,
          ));
          package.dependentsInWorkspace.forEach((package) {
            if (graduate && package.version.isPreRelease) return;
            dependentPackagesToVersion.add(package);
          });
        }
      });
    }

    await Pool(10).forEach<MelosPackage, void>(currentWorkspace.packages,
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

    packageCommits.entries.forEach((entry) {
      String packageName = entry.key;
      List<ConventionalCommit> packageCommits = entry.value;
      List<ConventionalCommit> versionableCommits =
          packageCommits.where((e) => e.isVersionableCommit).toList();
      if (versionableCommits.isNotEmpty) {
        packagesWithVersionableCommits[packageName] = versionableCommits;
      }
    });

    currentWorkspace.packages.forEach((package) {
      if (packagesWithVersionableCommits.containsKey(package.name)) {
        if (graduate && package.version.isPreRelease) return;
        packagesToVersion.add(package);
        dependentPackagesToVersion.addAll(package.dependentsInWorkspace);
      }
    });

    pendingPackageUpdates.addAll(packagesToVersion.map((package) =>
        MelosPendingPackageUpdate(
            package, packageCommits[package.name], PackageUpdateReason.commit,
            graduate: graduate, prerelease: prerelease)));

    dependentPackagesToVersion.forEach((package) {
      if (graduate && package.version.isFirstPreRelease) return;
      if (!packagesToVersion.contains(package)) {
        pendingPackageUpdates.add(MelosPendingPackageUpdate(
          package,
          [],
          PackageUpdateReason.dependency,
          graduate: graduate,
          prerelease: prerelease,
        ));
      }
    });

    if (pendingPackageUpdates.isEmpty) {
      logger.stdout(AnsiStyles.yellow(
          'No packages were found that required versioning.'));
      logger.stdout(AnsiStyles.gray(
          'Hint: try running "melos list" with the same filtering options to see a list of packages that were included.'));
      return;
    }

    logger.stdout(
        AnsiStyles.blueBright('The following packages will be updated:\n'));

    logger.stdout(listAsPaddedTable([
      [
        AnsiStyles.underline.bold('Package Name'),
        AnsiStyles.underline.bold('Current Version'),
        AnsiStyles.underline.bold('Updated Version'),
        AnsiStyles.underline.bold('Update Reason'),
      ],
      ...pendingPackageUpdates.map((pendingUpdate) {
        return [
          AnsiStyles.italic(pendingUpdate.package.name),
          AnsiStyles.dim(pendingUpdate.currentVersion.toString()),
          AnsiStyles.green(pendingUpdate.pendingVersion.toString()),
          AnsiStyles.italic((() {
            switch (pendingUpdate.reason) {
              case PackageUpdateReason.commit:
                var semverType = pendingUpdate.semverReleaseType
                    .toString()
                    .substring(pendingUpdate.semverReleaseType
                            .toString()
                            .indexOf('.') +
                        1);
                return 'updated with ${AnsiStyles.underline(semverType)} changes';
              case PackageUpdateReason.dependency:
                return 'dependency was updated';
              case PackageUpdateReason.graduate:
                return 'graduate to stable';
              default:
                return 'unknown';
            }
          })()),
        ];
      }),
    ], paddingSize: 3));

    bool shouldContinue = promptBool();
    if (!shouldContinue) {
      logger.stdout(AnsiStyles.yellow('Operation was canceled.'));
      return;
    }

    // TODO generate release files, git tags & commits.
    // TODO generate release files, git tags & commits.
    // TODO generate release files, git tags & commits.

    logger.stdout('');
    logger.stdout(
        '${AnsiStyles.yellow('\$')} ${AnsiStyles.bold('melos version')}');
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}');
  }
}
