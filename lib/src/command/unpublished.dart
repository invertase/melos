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

import '../common/logger.dart';
import '../common/package.dart';
import '../common/workspace.dart';

class UnpublishedCommand extends Command {
  @override
  final String name = 'unpublished';

  @override
  final List<String> aliases = ['unp'];

  @override
  final String description =
      'Discover and list unpublished packages or package versions in your repository.';

  @override
  void run() async {
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos unpublished")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(currentWorkspace.path)}${logger.ansi.noColor}\n');
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
        message: '${logger.ansi.green}SUCCESS${logger.ansi.noColor}',
        showTiming: true);

    logger.stdout('');
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos unpublished")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(currentWorkspace.path)}${logger.ansi.noColor}');
    if (unpublishedPackages.isNotEmpty) {
      logger.stdout(
          '       └> ${logger.ansi.red}${logger.ansi.emphasized('UNPUBLISHED PACKAGES')}${logger.ansi.noColor} (${unpublishedPackages.length} packages)');
      unpublishedPackages.forEach((package) {
        logger.stdout(
            '           └> ${logger.ansi.yellow}${package.name}${logger.ansi.noColor}');
        logger.stdout(
            '               ${logger.ansi.bullet} ${logger.ansi.green}Local:${logger.ansi.noColor}   ${package.version ?? 'none'}');
        logger.stdout(
            '               ${logger.ansi.bullet} ${logger.ansi.cyan}Remote:${logger.ansi.noColor}  ${latestPackageVersion[package.name]}');
      });
      logger.stdout('');
      exit(1);
    } else {
      logger.stdout(
          '       └> ${logger.ansi.green}${logger.ansi.emphasized('NO UNPUBLISHED PACKAGES')}${logger.ansi.noColor}');
      logger.stdout('');
    }
  }
}
