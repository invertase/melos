import 'dart:io';

import 'package:args/command_runner.dart' show Command;

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
    var bootstrapProgress = logger.progress('Bootstrapping project');
    await currentWorkspace.generatePubspecFile();

    var exitCode = await currentWorkspace
        .exec(['flutter', 'pub', 'get'], onlyOutputOnError: true);
    if (exitCode > 0) {
      logger
          .stderr('Bootstrap failed, reason: pub get failed, see logs above.');
      exit(1);
    }

    bootstrapProgress.finish(
        message: '${logger.ansi.green}SUCCESS${logger.ansi.noColor}',
        showTiming: true);
    var linkingProgress = logger.progress('Linking project packages');

    await currentWorkspace.linkPackages();

    linkingProgress.finish(
        message: '${logger.ansi.green}SUCCESS${logger.ansi.noColor}',
        showTiming: true);

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
  }
}
