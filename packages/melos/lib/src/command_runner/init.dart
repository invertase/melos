import 'dart:io';

import 'package:path/path.dart' as p;

import '../../melos.dart';
import '../common/utils.dart';
import 'base.dart';

class InitCommand extends MelosCommand {
  InitCommand(super.config) {
    argParser.addOption(
      'directory',
      abbr: 'd',
      help: 'Directory to create project in. Defaults to the workspace name.',
    );

    argParser.addMultiOption(
      'packages',
      abbr: 'p',
      help: 'Comma separated packages to add in top level `packages` array.',
    );

    argParser.addOption(
      'project',
      abbr: 'P',
      help: 'Project name to be used in pubspec.yaml. '
          'Defaults to the workspace name.',
    );
  }

  @override
  final String name = 'init';

  @override
  final String description = 'Initialize a new Melos workspace.';

  @override
  Future<void> run() {
    final workspaceDefault = p.basename(Directory.current.absolute.path);
    final workspaceName = argResults!.rest.firstOrNull ??
        promptInput(
          'Enter your workspace name',
          defaultsTo: workspaceDefault,
        );
    final directory = argResults!['directory'] as String? ??
        promptInput(
          'Enter the directory',
          defaultsTo: workspaceDefault != workspaceName ? workspaceName : '.',
        );
    final packages = argResults!['packages'] as List<String>?;
    final project = argResults!['project'] as String? ??
        promptInput(
          'Enter the project name',
          defaultsTo: workspaceName,
        );
    final useAppsDir = promptBool(
      message: 'Do you want to add the apps directory to the list of packages?',
      defaultsTo: true,
    );

    final melos = Melos(logger: logger, config: config);

    return melos.init(
      workspaceName,
      directory: directory,
      packages: packages ?? const [],
      project: project,
      useAppDir: useAppsDir,
    );
  }
}
