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
    var workspacePubspec = {};
    var workspaceName = currentWorkspace.config.name ?? 'MelosWorkspace';

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

    logger.stdout('Running pub get...');

    await currentWorkspace.exec(['flutter', 'pub', 'get']);

    logger.stdout('Linking packages...');

    currentWorkspace.linkPackages();

    logger.stdout('Workspace succesfully initialized!');
  }
}
