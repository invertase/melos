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
import 'package:pool/pool.dart' show Pool;

import '../common/git.dart';
import '../common/logger.dart';
import '../common/package.dart';
import '../common/utils.dart';
import '../common/workspace.dart';
import 'base.dart';
import 'exec.dart';

class PublishCommand extends MelosCommand {
  PublishCommand() {
    argParser.addFlag(
      'dry-run',
      abbr: 'n',
      defaultsTo: true,
      help: 'Validate but do not publish the package.',
    );
    argParser.addFlag(
      'git-tag-version',
      abbr: 't',
      negatable: false,
      help: 'Add any missing git tags for release. '
          'Note tags are only created if --no-dry-run is also set.',
    );
    argParser.addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Skip the Y/n confirmation prompt when using --no-dry-run.',
    );
  }

  @override
  final String name = 'publish';

  @override
  final String description =
      'Publish any unpublished packages or package versions in your repository to pub.dev. '
      'Dry run is on by default.';

  @override
  Future<void> run() async {
    final dryRun = argResults!['dry-run'] as bool;
    final gitTagVersion = argResults!['git-tag-version'] as bool;
    final yes = argResults!['yes'] as bool || false;

    logger.stdout(
        AnsiStyles.yellow.bold('melos publish${dryRun ? " --dry-run" : ''}'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace!.path)}\n');

    final readRegistryProgress =
        logger.progress('Reading pub registry for package information');

    final pool = Pool(10);
    final unpublishedPackages = <MelosPackage>[];
    final latestPackageVersion = <String, String>{};

    await pool.forEach<MelosPackage, void>(currentWorkspace!.packages!,
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
            // If current version is a prerelease version then get the latest
            // prerelease version with a matching preid instead if any.
            if (package.version.isPreRelease) {
              final preid = package.version.preRelease.length == 4
                  ? package.version.preRelease[2] as String
                  : package.version.preRelease[0] as String;
              final versionsWithPreid =
                  versions.where((version) => version.contains(preid)).toList();
              latestPackageVersion[package.name] = versionsWithPreid.isEmpty
                  ? versions[0]
                  : versionsWithPreid[0];
            } else {
              latestPackageVersion[package.name] = versions[0];
            }
          }
        }
      });
    }).drain<void>();

    readRegistryProgress.finish(
      message: AnsiStyles.green('SUCCESS'),
      showTiming: true,
    );

    if (unpublishedPackages.isEmpty) {
      logger.stdout(
        AnsiStyles.green.bold(
            '\nNo unpublished packages found - all local packages are already up to date.'),
      );
      return;
    }

    if (dryRun) {
      logger.stdout(
        AnsiStyles.magentaBright.bold(
            '\nThe following packages will be validated only (dry run):\n'),
      );
    } else {
      logger.stdout(
        AnsiStyles.yellowBright.bold(
            '\nThe following packages WILL be published to the registry:\n'),
      );
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

    if (!yes) {
      final shouldContinue = promptBool();
      if (!shouldContinue) {
        logger.stdout(AnsiStyles.red('Operation was canceled.'));
        exitCode = 1;
        return;
      }
      logger.stdout('');
    }

    final updateRegistryProgress = logger.progress(
      'Publishing ${unpublishedPackages.length} packages to registry:',
    );
    final execArgs = [
      if (isPubSubcommand()) 'dart',
      'pub',
      'publish',
    ];

    if (dryRun) {
      execArgs.add('--dry-run');
    } else {
      execArgs.add('--force');
    }

    await ExecCommand.execInPackages(
      unpublishedPackages,
      execArgs,
      concurrency: 1,
      failFast: true,
    );

    if (exitCode != 1) {
      if (!dryRun && gitTagVersion) {
        logger.stdout('');
        logger.stdout(
          'Creating git tags for any versions not already created... ',
        );
        await Future.forEach(unpublishedPackages, (MelosPackage package) async {
          final tag =
              gitTagForPackageVersion(package.name, package.version.toString());
          await gitTagCreate(
            tag,
            'Publish $tag.',
            workingDirectory: package.path,
          );
        });
      }

      updateRegistryProgress.finish(
        message: AnsiStyles.green('SUCCESS'),
        showTiming: true,
      );

      if (!dryRun) {
        logger.stdout(
          AnsiStyles.green
              .bold('\nAll packages have successfully been published.'),
        );
      } else {
        logger.stdout(
          AnsiStyles.green.bold('\nAll packages were validated successfully.'),
        );
      }
    }
  }
}
