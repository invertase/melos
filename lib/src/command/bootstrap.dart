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
import 'package:melos/src/common/intellij_project.dart';

import '../command_runner.dart';
import '../common/logger.dart';
import '../common/workspace.dart';

class BootstrapCommand extends Command {
  @override
  final String name = 'bootstrap';

  @override
  final List<String> aliases = ['bs'];

  @override
  final String description =
      'Initialize the workspace, link local packages together and install remaining package dependencies.';

  @override
  void run() async {
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos bootstrap")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(currentWorkspace.path)}${logger.ansi.noColor}\n');
    var successMessage = '${logger.ansi.green}SUCCESS${logger.ansi.noColor}';
    var bootstrapProgress = logger.progress('Bootstrapping project');
    await currentWorkspace.generatePubspecFile();

    var processExitCode = await currentWorkspace.execInMelosToolPath(
        ['flutter', 'pub', 'get'],
        onlyOutputOnError: true);
    if (processExitCode > 0) {
      logger
          .stderr('Bootstrap failed, reason: pub get failed, see logs above.');
      exitCode = 1;
      return;
    }

    bootstrapProgress.finish(message: successMessage, showTiming: true);
    if (Platform.isWindows) {
      // TODO Manual print finish status as it doesn't show on Windows, bug with progress library.
      print('  > $successMessage');
    }

    var linkingProgress = logger.progress('Linking project packages');
    var intellijProject = IntellijProject.fromWorkspace(currentWorkspace);
    await currentWorkspace.linkPackages();
    currentWorkspace.clean(cleanPackages: false);
    await intellijProject.cleanFiles();

    linkingProgress.finish(message: successMessage, showTiming: true);
    if (Platform.isWindows) {
      // TODO Manual print finish status as it doesn't show on Windows, bug with progress library.
      print('  > $successMessage');
    }

    if (currentWorkspace.config.scripts.containsKey('postbootstrap')) {
      logger.stdout('Running postbootstrap script...\n');
      await MelosCommandRunner.instance.run(['run', 'postbootstrap']);
    }

    logger.stdout('\nPackages:');
    currentWorkspace.packages.forEach((package) {
      logger.stdout(
          '  ${logger.ansi.bullet} ${logger.ansi.emphasized(package.name)}');
      logger.stdout(
          "    └> ${logger.ansi.blue + package.path.replaceAll(currentWorkspace.path, ".") + logger.ansi.none}");
    });
    logger.stdout(
        '\n -> ${currentWorkspace.packages.length} plugins bootstrapped');

    await IntellijProject.fromWorkspace(currentWorkspace).writeFiles();
  }
}
