import 'dart:io';

import 'package:args/command_runner.dart' show Command;
import 'package:cli_util/cli_logging.dart' show Progress;

import '../common/logger.dart';
import '../common/plugin.dart';
import '../common/utils.dart' as utils;

class PubCommand extends Command {
  final String name = "pub";

  final List<String> aliases = ["p"];

  final String description =
      "Run a Flutter Pub command in all plugins including the root workspace.";

  void run() async {
    print(argResults.arguments);
    if (argResults.arguments == null) return;
    String pubCommand = argResults.arguments[0];

    Directory currentDirectory = Directory.current;
    if (!utils.isWorkspaceDirectory(currentDirectory)) {
      logger.stderr(
          "Your current directory does not appear to be a valid plugins repository.");
      logger.trace("Current directory: $currentDirectory");
      exit(1);
    }

    List<Package> plugins =
        utils.getPluginsForDirectory(Directory.current);

    if (plugins.isEmpty) {
      logger.stderr("No plugins have been detected in the current directory.");
      exit(1);
    }

    // TODO workspace name customise maybe
    String workspaceName = "MelosWorkspace";
    Directory workspaceDirectory =
        utils.getWorkspaceDirectoryForProjectDirectory(currentDirectory);
    Directory workspaceIdeRootDirectory = Directory(
        workspaceDirectory.path + Platform.pathSeparator + workspaceName);

    Progress pubGetRoot =
        logger.progress("Running 'flutter pub $pubCommand' in workspace");
    await utils.flutterPubCommand(pubCommand, workspaceIdeRootDirectory.path,
        root: true);
    pubGetRoot.finish(showTiming: true);

    await Future.forEach(plugins, (Package plugin) async {
      Progress progress = logger.progress(
          "Running 'flutter pub $pubCommand' in plugin '${plugin.name}'");
      await utils.flutterPubCommand(pubCommand, plugin.path);
      progress.finish(showTiming: true);
    });

    await Future.forEach(plugins, (Package plugin) async {
      Progress progress =
          logger.progress("Linking dependencies in plugin '${plugin.name}'");
      await utils.linkPluginDependencies(
          workspaceIdeRootDirectory, plugin, plugins);
      progress.finish(showTiming: true);
    });
  }
}
