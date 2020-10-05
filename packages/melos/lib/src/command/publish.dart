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

import 'package:args/command_runner.dart' show Command;
import 'package:pool/pool.dart' show Pool;
import 'package:ansi_styles/ansi_styles.dart';

import '../common/git.dart';
import '../common/logger.dart';
import '../common/package.dart';
import '../common/utils.dart';
import '../common/workspace.dart';
import 'exec.dart';

class PublishCommand extends Command {
  @override
  final String name = 'publish';

  @override
  final String description =
      'Publish any unpublished packages or package versions in your repository to pub.dev. Dry run is on by default.';

  PublishCommand() {
    argParser.addFlag('dry-run',
        abbr: 'n',
        defaultsTo: true,
        negatable: true,
        help: 'Validate but do not publish the package.');
    argParser.addFlag('git-tag-version',
        abbr: 't',
        defaultsTo: false,
        negatable: false,
        help:
            'Add any missing git tags for release. Note tags are only created if --no-dry-run is also set.');
  }

  @override
  void run() async {
    bool dryRun = argResults['dry-run'] as bool;
    bool gitTagVersion = argResults['git-tag-version'] as bool;
    logger.stdout(
        AnsiStyles.yellow.bold('melos publish${dryRun ? " --dry-run" : ''}'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}\n');
    var readRegistryProgress =
        logger.progress('Reading pub registry for package information');

    var pool = Pool(10);
    var unpublishedPackages = <MelosPackage>[];
    var latestPackageVersion = <String, String>{};

    await pool.forEach<MelosPackage, void>(currentWorkspace.packages,
        (package) {
      if (package.isPrivate) {
        return Future.value();
      }
      return package.getPublishedVersions().then((versions) async {
        if (versions.isEmpty ||
            !versions.contains(package.version.toString())) {
          unpublishedPackages.add(package);
          if (versions.isEmpty) {
            latestPackageVersion[package.name] = 'none';
          } else {
            // TODO if current version is a prerelease version then get the latest prerelease version instead
            latestPackageVersion[package.name] = versions[0];
          }
        }
      });
    }).drain();

    readRegistryProgress.finish(
        message: AnsiStyles.green('SUCCESS'), showTiming: true);

    if (unpublishedPackages.isEmpty) {
      logger.stdout(AnsiStyles.green.bold(
          '\nNo unpublished packages found - all local packages are already up to date.'));
      return;
    }

    if (dryRun) {
      logger.stdout(AnsiStyles.magentaBright.bold(
          '\nThe following packages will be validated only (dry run):\n'));
    } else {
      logger.stdout(AnsiStyles.yellowBright.bold(
          '\nThe following packages WILL be published to the registry:\n'));
    }

    logger.stdout(listAsPaddedTable([
      [
        AnsiStyles.underline.bold('Package Name'),
        AnsiStyles.underline.bold('Registry'),
        AnsiStyles.underline.bold('Local'),
      ],
      ...unpublishedPackages.map((package) {
        return [
          AnsiStyles.italic(package.name),
          AnsiStyles.dim(latestPackageVersion[package.name]),
          AnsiStyles.green(package.version.toString()),
        ];
      }).toList()
    ], paddingSize: 4));

    bool shouldContinue = promptBool();
    if (!shouldContinue) {
      logger.stdout(AnsiStyles.red('Operation was canceled.'));
      exitCode = 1;
      return;
    }

    logger.stdout('');
    var updateRegistryProgress = logger.progress(
        'Publishing ${unpublishedPackages.length} packages to registry:');

    // TODO flutter pub if flutter packages detected? May not be necessary
    List<String> execArgs = [
      if (isPubSubcommand()) 'dart',
      'pub',
      '--verbosity=warning',
      'publish'
    ];
    if (dryRun) {
      execArgs.add('--dry-run');
    } else {
      execArgs.add('--force');
    }
    await ExecCommand.execInPackages(unpublishedPackages, execArgs,
        concurrency: 1, failFast: true);

    if (exitCode != 1) {
      if (!dryRun && gitTagVersion) {
        logger.stdout('');
        logger.stdout(
            'Creating git tags for any versions not already created... ');
        await Future.forEach(unpublishedPackages, (MelosPackage package) async {
          String tag =
              gitTagForPackageVersion(package.name, package.version.toString());
          await gitTagCreate(tag, 'Publish $tag.',
              workingDirectory: package.path);
        });
      }
      updateRegistryProgress.finish(
          message: AnsiStyles.green('SUCCESS'), showTiming: true);

      if (!dryRun) {
        logger.stdout(AnsiStyles.green
            .bold('\nAll packages have successfully been published.'));
      } else {
        logger.stdout(AnsiStyles.green
            .bold('\nAll packages were validated successfully.'));
      }
    }
  }
}
