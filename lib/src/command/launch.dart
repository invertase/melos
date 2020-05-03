import 'dart:io';

import 'package:args/command_runner.dart' show Command;

import '../common/logger.dart';
import '../common/utils.dart' as utils;

class LaunchCommand extends Command {
  final String name = "launch";

  final List<String> aliases = ["l"];

  final String description =
      "Opens your IDE for the workspace in the current directory.";

  void run() async {
    Directory currentDirectory = Directory.current;
    if (!utils.isWorkspaceDirectory(currentDirectory)) {
      logger.stderr(
          "Your current directory does not appear to be a valid plugins repository.");
      logger.trace("Current directory: $currentDirectory");
      exit(1);
    }

    // TODO workspace name customise maybe
    String workspaceName = "MelosWorkspace";
    Directory workspaceDirectory =
        utils.getWorkspaceDirectoryForProjectDirectory(currentDirectory);
    Directory workspaceIdeRootDirectory = Directory(
        workspaceDirectory.path + Platform.pathSeparator + workspaceName);

    // TODO allow choosing IDE enum through CLI (both work, just not exposed)
    utils.launchIde(workspaceIdeRootDirectory.path, utils.IDE.AndroidStudio);
  }
}
