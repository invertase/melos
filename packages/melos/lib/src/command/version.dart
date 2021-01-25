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

import 'package:ansi_styles/ansi_styles.dart';
import 'package:args/command_runner.dart' show Command;
import 'package:conventional_commit/conventional_commit.dart';
import 'package:pool/pool.dart' show Pool;

import '../command_runner.dart';
import '../common/git.dart';
import '../common/logger.dart';
import '../common/package.dart';
import '../common/pending_package_update.dart';
import '../common/utils.dart';
import '../common/workspace.dart';

class VersionCommand extends Command {
  VersionCommand() {
    argParser.addFlag('prerelease',
        abbr: 'p',
        negatable: false,
        help:
            'Version any packages with changes as a prerelease. Cannot be combined with graduate flag.');
    argParser.addFlag('graduate',
        abbr: 'g',
        negatable: false,
        help:
            'Graduate current prerelease versioned packages to stable versions, e.g. "0.10.0-dev.1" would become "0.10.0". Cannot be combined with prerelease flag.');
    argParser.addFlag('changelog',
        abbr: 'c', defaultsTo: true, help: 'Update CHANGELOG.md files.');
    argParser.addFlag('git-tag-version',
        abbr: 't',
        defaultsTo: true,
        help:
            'By default, melos version will commit changes to pubspec.yaml files and tag the release. Pass --no-git-tag-version to disable the behavior.');
    argParser.addFlag('yes',
        negatable: false,
        help: 'Skip the Y/n prompt at the beginning of the command.');
    argParser.addOption('preid',
        defaultsTo: 'dev',
        help:
            'When run with this option, melos version will increment prerelease versions using the specified prerelease identifier, e.g. using a "nullsafety" preid along with the --prerelease flag would result in a version in the format "1.0.0-nullsafety.0".');
  }

  @override
  final String name = 'version';

  @override
  final String description =
      'Automatically version and generate changelogs for all packages. Supports all Melos filtering flags.';

  @override
  Future<void> run() async {
    logger.stdout(AnsiStyles.yellow.bold('melos version'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}\n');

    final changelog = argResults['changelog'] as bool;
    var graduate = argResults['graduate'] as bool;
    final tag = argResults['git-tag-version'] as bool;
    final prerelease = argResults['prerelease'] as bool;
    final skipPrompt = argResults['yes'] as bool;
    final preid = argResults['preid'] as String;

    final packagesToVersion = <MelosPackage>{};
    final packageCommits = <String, List<ConventionalCommit>>{};
    final dependentPackagesToVersion = <MelosPackage>{};
    final packagesWithVersionableCommits = {};
    var pendingPackageUpdates = <MelosPendingPackageUpdate>[];

    if (graduate && prerelease) {
      logger.stdout(
          '${AnsiStyles.yellow('WARNING:')} graduate & prerelease flags cannot be combined. Versioning will continue with graduate off.');
      graduate = false;
    }

    if (graduate) {
      for (final package in currentWorkspace.packages) {
        if (!package.version.isPreRelease) continue;

        pendingPackageUpdates.add(MelosPendingPackageUpdate(
          package,
          [],
          PackageUpdateReason.graduate,
          graduate: graduate,
          prerelease: prerelease,
          preid: preid,
        ));

        final packageUnscoped = currentWorkspace.packagesNoScope
            .firstWhere((element) => element.name == package.name);

        for (final package in packageUnscoped.dependentsInWorkspace) {
          if (graduate && package.version.isPreRelease) continue;
          dependentPackagesToVersion.add(package);
        }
      }
    }

    await Pool(10).forEach<MelosPackage, void>(currentWorkspace.packages,
        (package) {
      if (package.isPrivate) {
        return Future.value();
      }
      return gitCommitsForPackage(package,
              since: globalResults['since'] as String)
          .then((commits) {
        packageCommits[package.name] = commits
            .map((commit) => ConventionalCommit.parse(commit.message))
            .where((element) => element != null)
            .toList();
      });
    }).drain();

    for (final entry in packageCommits.entries) {
      final packageName = entry.key;
      final packageCommits = entry.value;
      final versionableCommits =
          packageCommits.where((e) => e.isVersionableCommit).toList();
      if (versionableCommits.isNotEmpty) {
        packagesWithVersionableCommits[packageName] = versionableCommits;
      }
    }

    for (final package in currentWorkspace.packages) {
      if (packagesWithVersionableCommits.containsKey(package.name)) {
        if (graduate && package.version.isPreRelease) continue;
        packagesToVersion.add(package);
        final packageUnscoped = currentWorkspace.packagesNoScope
            .firstWhere((element) => element.name == package.name);
        dependentPackagesToVersion
            .addAll(packageUnscoped.dependentsInWorkspace);
      }
    }

    pendingPackageUpdates
        .addAll(packagesToVersion.map((package) => MelosPendingPackageUpdate(
              package,
              packageCommits[package.name],
              PackageUpdateReason.commit,
              graduate: graduate,
              prerelease: prerelease,
              preid: preid,
            )));

    for (final package in dependentPackagesToVersion) {
      if (graduate && package.version.isFirstPreRelease) continue;
      if (!packagesToVersion.contains(package)) {
        pendingPackageUpdates.add(MelosPendingPackageUpdate(
          package,
          [],
          PackageUpdateReason.dependency,
          graduate: graduate,
          prerelease: prerelease,
          // TODO Should dependent packages also get the same preid, can we expose this as an option?
          // TODO In the case of "nullsafety" it doesn't make sense for dependent packages to also become nullsafety preid versions.
          // preid: preid,
        ));
      }
    }

    // Filter out private packages.
    pendingPackageUpdates = pendingPackageUpdates
        .where((update) => !update.package.isPrivate)
        .toList();

    if (pendingPackageUpdates.isEmpty) {
      logger.stdout(AnsiStyles.yellow(
          'No packages were found that required versioning.'));
      logger.stdout(AnsiStyles.gray(
          'Hint: try running "melos list" with the same filtering options to see a list of packages that were included.'));
      return;
    }

    logger.stdout(
        AnsiStyles.magentaBright('The following packages will be updated:\n'));

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
          AnsiStyles.green(pendingUpdate.nextVersion.toString()),
          AnsiStyles.italic((() {
            switch (pendingUpdate.reason) {
              case PackageUpdateReason.commit:
                final semverType = pendingUpdate.semverReleaseType
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

    final shouldContinue = skipPrompt || promptBool();
    if (!shouldContinue) {
      logger.stdout(AnsiStyles.red('Operation was canceled.'));
      exitCode = 1;
      return;
    }

    // Note: not pooling & parrellelzing rights to avoid possible file contention.
    await Future.forEach(pendingPackageUpdates,
        (MelosPendingPackageUpdate pendingPackageUpdate) async {
      // Update package pubspec version.
      await pendingPackageUpdate.package
          .setPubspecVersion(pendingPackageUpdate.nextVersion.toString());

      // Update dependents.
      // TODO: This isn't updating the dev_dependencies yet but it probably should.
      await Future.forEach(
          pendingPackageUpdate.package.dependentsInWorkspace,
          (MelosPackage package) => package.setDependencyVersion(
              pendingPackageUpdate.package.name,
              // Dependency range using caret syntax to ensure the range allows
              // all versions guaranteed to be backwards compatible with the specified version.
              // For example, ^1.2.3 is equivalent to '>=1.2.3 <2.0.0', and ^0.1.2 is equivalent to '>=0.1.2 <0.2.0'.
              '^${pendingPackageUpdate.nextVersion.toString()}'));

      // Update changelogs if requested.
      if (changelog) {
        await pendingPackageUpdate.changelog.write();
      }
    });

    // TODO allow support for individual package lifecycle version scripts
    if (currentWorkspace.config.scripts.exists('version')) {
      logger.stdout('Running "version" lifecycle script...\n');
      await MelosCommandRunner.instance.run(['run', 'version']);
    }

    if (tag) {
      // 1) Stage changes:
      await Future.forEach(pendingPackageUpdates,
          (MelosPendingPackageUpdate pendingPackageUpdate) async {
        await gitAdd('pubspec.yaml',
            workingDirectory: pendingPackageUpdate.package.path);
        await gitAdd('CHANGELOG.md',
            workingDirectory: pendingPackageUpdate.package.path);
        await Future.forEach(pendingPackageUpdate.package.dependentsInWorkspace,
            (MelosPackage dependentPackage) async {
          await gitAdd('pubspec.yaml', workingDirectory: dependentPackage.path);
        });

        // TODO this is a temporary workaround for committing generated dart files.
        // TODO remove once options exposed for this in a later release.
        if (pendingPackageUpdate.package.name == 'melos') {
          await gitAdd('**/*.g.dart',
              workingDirectory: pendingPackageUpdate.package.path);
        }
      });

      // 2) Commit changes:
      final publishedPackagesMessage = pendingPackageUpdates
          .map((e) => ' - ${e.package.name}@${e.nextVersion.toString()}')
          .join('\n');
      // TODO commit message customization support would go here.
      // TODO this is currently blocking git submodules support (if we decide to support it later) for packages as commit is only ran at the root.
      await gitCommit(
          'chore(release): publish packages\n\n$publishedPackagesMessage',
          workingDirectory: currentWorkspace.path);

      // // 3) Tag changes:
      await Future.forEach(pendingPackageUpdates,
          (MelosPendingPackageUpdate pendingPackageUpdate) async {
        // TODO '--tag-version-prefix' support (if we decide to support it later) would pass prefix named arg to gitTagForPackageVersion:
        final tag = gitTagForPackageVersion(pendingPackageUpdate.package.name,
            pendingPackageUpdate.nextVersion.toString());
        await gitTagCreate(tag, pendingPackageUpdate.changelog.markdown,
            workingDirectory: pendingPackageUpdate.package.path);
      });
    }

    // TODO allow support for individual package lifecycle postversion scripts
    if (currentWorkspace.config.scripts.exists('postversion')) {
      logger.stdout('Running "postversion" lifecycle script...\n');
      await MelosCommandRunner.instance.run(['run', 'postversion']);
    }

    // TODO automatic push support
    logger.stdout(AnsiStyles.greenBright.bold(
        'Versioning successful. Ensure you push your git changes and tags (if applicable) via ${AnsiStyles.bgBlack.gray('git push --follow-tags')}'));
  }
}
