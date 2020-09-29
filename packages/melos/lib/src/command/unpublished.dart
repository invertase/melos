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

import '../common/logger.dart';
import '../common/package.dart';
import '../common/workspace.dart';

class UnpublishedCommand extends Command {
  @override
  final String name = 'unpublished';

  @override
  final String description =
      'Discover and list unpublished packages or package versions in your repository.';

  @override
  void run() async {
    logger.stdout(AnsiStyles.yellow.bold('melos unpublished'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}\n');
    var readRegistryProgress =
        logger.progress('Reading registry for package information');

    var pool = Pool(10);
    var unpublishedPackages = <MelosPackage>[];
    var latestPackageVersion = <String, String>{};
    await pool.forEach<MelosPackage, void>(currentWorkspace.packages,
        (package) {
      return package.getPublishedVersions().then((versions) async {
        if (versions.isEmpty || !versions.contains(package.version)) {
          unpublishedPackages.add(package);
          if (versions.isEmpty) {
            latestPackageVersion[package.name] = 'none';
          } else {
            latestPackageVersion[package.name] = versions[0];
          }
        }
      });
    }).drain();

    readRegistryProgress.finish(
        message: AnsiStyles.green('SUCCESS'), showTiming: true);

    logger.stdout('');
    logger.stdout(
        '${AnsiStyles.yellow('\$')} ${AnsiStyles.bold('melos unpublished')}');
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}');
    if (unpublishedPackages.isNotEmpty) {
      logger.stdout(
          '       └> ${AnsiStyles.red.bold('UNPUBLISHED PACKAGES')} (${unpublishedPackages.length} packages)');
      unpublishedPackages.forEach((package) {
        logger.stdout('           └> ${AnsiStyles.yellow(package.name)}');
        logger.stdout(
            '               ${AnsiStyles.bullet} ${AnsiStyles.green('Local:')}   ${package.version ?? 'none'}');
        logger.stdout(
            '               ${AnsiStyles.bullet} ${AnsiStyles.cyan('Remote:')}   ${latestPackageVersion[package.name]}');
      });
      logger.stdout('');
      exitCode = 1;
      return;
    } else {
      logger.stdout(
          '       └> ${AnsiStyles.green.bold('NO UNPUBLISHED PACKAGES')}');
      logger.stdout('');
    }
  }
}
