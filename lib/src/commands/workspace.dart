part of flutterfire_tools;

class WorkspaceCommand extends Command {
  final String name = "workspace";

  final List<String> aliases = ["ws"];

  final String description = "Commands relating to the workspace.";

  WorkspaceCommand() {
    addSubcommand(WorkspaceBootstrapCommand());
    addSubcommand(WorkspaceLaunchCommand());
    addSubcommand(WorkspacePubCommand());
  }
}
