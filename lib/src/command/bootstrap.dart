import 'dart:io';

import 'package:args/command_runner.dart' show Command;
import 'package:yamlicious/yamlicious.dart' show toYamlString;

import '../common/logger.dart';
import '../common/package.dart';
import '../common/utils.dart' as utils;
import '../common/workspace.dart';

class BootstrapCommand extends Command {
  @override
  final String name = 'bootstrap';

  @override
  final List<String> aliases = ['bs'];

  @override
  final String description =
      'Initialize a workspace for the FlutterFire repository in the current directory.';

  @override
  void run() async {
    var workspaceName = currentWorkspace.config.name ?? 'MelosWorkspace';
    var workspaceDirectory = utils.getWorkspaceDirectoryForProjectDirectory(
        Directory(currentWorkspace.path));
    var workspaceIdeRootDirectory = Directory(
        workspaceDirectory.path + Platform.pathSeparator + workspaceName);

    workspaceIdeRootDirectory.createSync(recursive: true);
    File(workspaceDirectory.path + Platform.pathSeparator + '.name')
        .writeAsStringSync(workspaceName);
    File(workspaceDirectory.path + Platform.pathSeparator + '.path')
        .writeAsStringSync(currentWorkspace.path);

    var workspacePubspec = {};

    workspacePubspec['name'] = workspaceName;
    workspacePubspec['version'] = currentWorkspace.config.version ?? '0.0.0';
    workspacePubspec['dependencies'] =
        Map.from(currentWorkspace.config.dependencies);
    workspacePubspec['dependency_overrides'] =
        Map.from(currentWorkspace.config.devDependencies);
    workspacePubspec['environment'] =
        Map.from(currentWorkspace.config.environment);

    currentWorkspace.packages.forEach((MelosPackage plugin) {
      var pluginRelativePath =
          utils.relativePath(plugin.path, currentWorkspace.path);
      workspacePubspec['dependencies'][plugin.name] = {
        'path': pluginRelativePath,
      };
      workspacePubspec['dependency_overrides'][plugin.name] = {
        'path': pluginRelativePath,
      };
    });

    var header = '# Generated file - do not modify or commit this file.';
    var pubspecYaml = '$header\n${toYamlString(workspacePubspec)}';

    await File(utils.pubspecPathForDirectory(Directory(currentWorkspace.path)))
        .writeAsString(pubspecYaml);

    await currentWorkspace.exec(['flutter', 'pub', 'get']);

    logger.stdout('Workspace succesfully initialized!');
    logger.stdout(workspaceDirectory.path);
  }
}
