import 'dart:io';

import 'package:args/command_runner.dart' show Command;
import 'package:meta/meta.dart';

import '../command_runner.dart';
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
      'Initialize the workspace, link local packages together and install remaining package dependencies.';
  // TODO move me - just here for easy testing
  Future<void> initIntellijProject() async {
    // TODO template cache
    Future<String> readTemplate(String fileName,
        {String templateCategory}) async {
      String ideTemplateDirectoryName = 'ide_templates';
      String intellijTemplateDirectoryName = 'intellij';
      String melosRootPath = utils.getMelosRoot();
      Directory intellijTemplateDirectory;
      if (templateCategory != null) {
        intellijTemplateDirectory = Directory(
            '$melosRootPath${Platform.pathSeparator}$ideTemplateDirectoryName${Platform.pathSeparator}$intellijTemplateDirectoryName${Platform.pathSeparator}$templateCategory');
      } else {
        intellijTemplateDirectory = Directory(
            '$melosRootPath${Platform.pathSeparator}$ideTemplateDirectoryName${Platform.pathSeparator}$intellijTemplateDirectoryName');
      }
      File templateFile = File(
          '${intellijTemplateDirectory.path}${Platform.pathSeparator}$fileName.tmpl');
      return templateFile.readAsString();
    }

    String injectTemplateVariable(
        {@required String sourceTemplate,
        @required String variableName,
        @required String variableValue}) {
      return sourceTemplate.replaceAll('{{#$variableName}}', variableValue);
    }

    String ideaModuleStringForName(String moduleName, {String relativePath}) {
      String module = '';
      if (relativePath == null) {
        module =
            '<module fileurl="file://\$PROJECT_DIR\$/$moduleName.iml" filepath="\$PROJECT_DIR\$/$moduleName.iml" />';
      } else {
        module =
            '<module fileurl="file://\$PROJECT_DIR\$/$relativePath/$moduleName.iml" filepath="\$PROJECT_DIR\$/$relativePath/$moduleName.iml" />';
      }
      // Pad to preserve formatting on generated file. Indent x6.
      return '      $module';
    }

    Future<void> writeTemplateToFile(
        String filePath, String fileContents) async {
      File outputFile = File(filePath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsString(fileContents);
    }

    List<String> ideaModules = [];
    String workspaceModuleName =
        (currentWorkspace.config.name ?? 'melos_workspace').toLowerCase();
    Directory ideaOutputDirectory =
        Directory('${currentWorkspace.path}${Platform.pathSeparator}.idea');

    // Create a .name file if the workspace name is defined.
    // This gets picked up by the IDE and is used for display purposes.
    if (currentWorkspace.config.name != null) {
      await writeTemplateToFile(
          File('${ideaOutputDirectory.path}${Platform.pathSeparator}.name')
              .path,
          currentWorkspace.config.name);
    }

    // Generate package modules.
    await Future.forEach(currentWorkspace.packages,
        (MelosPackage package) async {
      String template;
      if (!package.isFlutterPackage) {
        template = await readTemplate('dart_package_module.iml',
            templateCategory: 'modules');
      } else if (package.isFlutterApp) {
        template = await readTemplate('flutter_app_module.iml',
            templateCategory: 'modules');
      } else {
        template = await readTemplate('flutter_plugin_module.iml',
            templateCategory: 'modules');
      }

      // Generate package module.
      await writeTemplateToFile(
          File('${package.path}${Platform.pathSeparator}${package.name}.iml')
              .path,
          template);
      // Add package module to modules list.
      ideaModules.add(ideaModuleStringForName(package.name,
          relativePath: package.pathInWorkspace));
    });

    // Generate root module.
    String ideaWorkspaceModuleImlTemplate = await readTemplate(
        'workspace_root_module.iml',
        templateCategory: 'modules');
    await writeTemplateToFile(
        File('${currentWorkspace.path}${Platform.pathSeparator}$workspaceModuleName.iml')
            .path,
        ideaWorkspaceModuleImlTemplate);
    // Add root module to modules list.
    ideaModules.add(ideaModuleStringForName(workspaceModuleName));

    // Generate modules.xml
    String ideaModulesXmlTemplate = await readTemplate('modules.xml');
    String generatedModulesXml = injectTemplateVariable(
        sourceTemplate: ideaModulesXmlTemplate,
        variableName: 'modules',
        variableValue: ideaModules.join('\n'));
    await writeTemplateToFile(
        File('${ideaOutputDirectory.path}${Platform.pathSeparator}modules.xml')
            .path,
        generatedModulesXml);
  }

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

    // if (currentWorkspace.config.scripts.containsKey('postbootstrap')) {
    //   logger.stdout('Running postbootstrap script...\n');
    //   await MelosCommandRunner.instance.run(['run', 'postbootstrap']);
    // }

    logger.stdout('\nPackages:');
    currentWorkspace.packages.forEach((package) {
      logger.stdout(
          '  ${logger.ansi.bullet} ${logger.ansi.emphasized(package.name)}');
      logger.stdout(
          "    └> ${logger.ansi.blue + package.path.replaceAll(currentWorkspace.path, ".") + logger.ansi.none}");
    });
    logger.stdout(
        '\n -> ${currentWorkspace.packages.length} plugins bootstrapped');

    await initIntellijProject();
  }
}
