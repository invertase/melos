import 'dart:io';

import 'package:args/command_runner.dart' show Command;

import '../common/logger.dart';
import '../common/workspace.dart';

class BootstrapCommand extends Command {
  @override
  final String name = 'bootstrap';

  @override
  final List<String> aliases = ['bs'];

  @override
  final String description =
      'Initialize a workspace for the FlutterFire repository in the current directory. Supports all package filtering options.';

  @override
  void run() async {
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos bootstrap")}\n');

    var bootstrapProgress = logger.progress('Bootstrapping project');
    await currentWorkspace.generatePubspecFile();

    var successful = currentWorkspace.exec(['flutter', 'pub', 'get']);
    if (!successful) {
      logger
          .stderr('Bootstrap failed, reason: pub get failed, see logs above.');
      exit(1);
    }

    bootstrapProgress.finish(
        message: '${logger.ansi.green}SUCCESS${logger.ansi.noColor}',
        showTiming: true);
    var linkingProgress = logger.progress('Linking project packages');

    currentWorkspace.linkPackages();
    linkingProgress.finish(
        message: '${logger.ansi.green}SUCCESS${logger.ansi.noColor}',
        showTiming: true);

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
