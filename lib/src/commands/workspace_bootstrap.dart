part of flutterfire_tools;

class WorkspaceBootstrapCommand extends Command {
  final String name = "bootstrap";

  final List<String> aliases = ["bs"];

  final String description =
      "Initialize a workspace for the FlutterFire repository in the current directory.";

  void run() async {
    Directory currentDirectory = Directory.current;

    if (!utils.isValidPluginsDirectory(currentDirectory)) {
      logger.stderr(
          "Your current directory does not appear to be a valid plugins repository.");
      logger.trace("Current directory: $currentDirectory");
      exit(1);
    }

    Progress progress =
    logger.progress('Looking for plugins in current directory');
    List<FlutterPlugin> plugins =
    utils.getPluginsForDirectory(Directory.current);
    progress.finish(showTiming: true);

    if (plugins.isEmpty) {
      logger.stderr("No plugins have been detected in the current directory.");
      exit(1);
    }

    logger.stdout("Found ${plugins.length} plugins:");
    plugins.forEach((f) {
      logger
          .stdout("  ${logger.ansi.bullet} ${logger.ansi.emphasized(f.name)}");
      logger.stdout(
          "    └> ${logger.ansi.blue +
              f.path.replaceAll(currentDirectory.path, ".") +
              logger.ansi.none}");
    });

    String workspaceName = "MelosWorkspace";
    Directory workspaceDirectory =
    utils.getWorkspaceDirectoryForProjectDirectory(currentDirectory);
    Directory workspaceIdeRootDirectory = Directory(
        workspaceDirectory.path + Platform.pathSeparator + workspaceName);

    workspaceIdeRootDirectory.createSync(recursive: true);
    File(workspaceDirectory.path + Platform.pathSeparator + ".name")
        .writeAsStringSync(workspaceName);
    File(workspaceDirectory.path + Platform.pathSeparator + ".path")
        .writeAsStringSync(currentDirectory.path);

    Map workspacePubspec =
    json.decode(json.encode(yaml.loadYaml(partials.workspacePubspec)));
    workspacePubspec['dependencies'] = {};
    workspacePubspec['dependency_overrides'] = {};

    String workspaceImlContentRoots = '';

    plugins.forEach((FlutterPlugin plugin) {
      String pluginRelativePath =
      utils.relativePath(plugin.path, workspaceIdeRootDirectory.path);

      workspacePubspec['dependencies'][plugin.name] = {
        "path": pluginRelativePath,
      };
      workspacePubspec['dependency_overrides'][plugin.name] = {
        "path": pluginRelativePath,
      };
      workspaceImlContentRoots += partials.workspaceImlContentRoot
          .replaceAll('__pluginRelativePath__', pluginRelativePath);
    });

    utils.templateCopyTo("intellij", workspaceIdeRootDirectory, {
      "workspaceName": workspaceName,
      "pubspecYaml": toYamlString(workspacePubspec),
      "projectPath": currentDirectory.path,
      "workspaceImlContentRoots": workspaceImlContentRoots,
      "androidSdkRoot": utils.getAndroidSdkRoot(),
      "flutterSdkRoot": utils.getFlutterSdkRoot(),
      "flutterSdkRootRelative": utils.relativePath(
          utils.getFlutterSdkRoot(), workspaceIdeRootDirectory.path),
    });

    logger.stdout("Workspace succesfully initialized!");
  }
}
