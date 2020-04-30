part of flutterfire_tools;

class WorkspacePubCommand extends Command {
  final String name = "pub";

  final List<String> aliases = ["p"];

  final String description =
      "Run a Flutter Pub command in all plugins including the root workspace.";

  WorkspacePubCommand() {
    argParser.addCommand('get');
  }

  void run() async {
    if (argResults.command == null) return;
    String pubCommand = argResults.command.name;

    Directory currentDirectory = Directory.current;
    if (!utils.isValidPluginsDirectory(currentDirectory)) {
      logger.stderr(
          "Your current directory does not appear to be a valid plugins repository.");
      logger.trace("Current directory: $currentDirectory");
      exit(1);
    }

    List<FlutterPlugin> plugins =
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

    await Future.forEach(plugins, (FlutterPlugin plugin) async {
      Progress progress = logger.progress(
          "Running 'flutter pub $pubCommand' in plugin '${plugin.name}'");
      await utils.flutterPubCommand(pubCommand, plugin.path);
      progress.finish(showTiming: true);
    });

    await Future.forEach(plugins, (FlutterPlugin plugin) async {
      Progress progress = logger.progress(
          "Linking dependencies in plugin '${plugin.name}'");
      await utils.linkPluginDependencies(plugin, plugins);
      progress.finish(showTiming: true);
    });

    Progress pubGetRoot =
    logger.progress("Running 'flutter pub $pubCommand' in workspace");
    await utils.flutterPubCommand(pubCommand, workspaceIdeRootDirectory.path,
        root: true);
    pubGetRoot.finish(showTiming: true);
  }
}
