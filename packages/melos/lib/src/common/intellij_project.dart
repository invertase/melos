/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:io';

import 'package:path/path.dart' show join, joinAll;

import '../common/utils.dart' as utils;
import '../package.dart';
import '../workspace.dart';
import 'platform.dart';

const String _kTemplatesDirName = 'templates';
const String _kIntellijDirName = 'intellij';
const String _kDotIdeaDirName = '.idea';
const String _kTmplExtension = '.tmpl';

/// IntelliJ project IDE configuration helper.
class IntellijProject {
  /// Build a new [IntellijProject] from a [MelosWorkspace].
  IntellijProject.fromWorkspace(MelosWorkspace workspace)
      : _workspace = workspace;

  final MelosWorkspace _workspace;

  final Map<String, String> _cacheTemplates = <String, String>{};

  /// Fully qualified path to the intellij templates shipped as part of Melos.
  Future<String> get pathTemplates async {
    return joinAll([
      await utils.getMelosRoot(),
      _kTemplatesDirName,
      _kIntellijDirName,
    ]);
  }

  Directory get runConfigurationsDir =>
      Directory(join(dotIdeaDir.path, 'runConfigurations'));

  Directory get dotIdeaDir => Directory(join(_workspace.path, '.idea'));

  /// Path to the .idea folder in the current workspace.
  String get pathDotIdea {
    return joinAll([_workspace.path, _kDotIdeaDirName]);
  }

  /// Path to the .idea/.name file in the current workspace.
  /// This file generated with the workspace name as its contents. IntelliJ
  /// uses this to change the project display name the IDE.
  String get pathDotName {
    return joinAll([pathDotIdea, '.name']);
  }

  /// Path to the .idea/modules.xml file in the current workspace.
  /// This file is generated with a module for each discovered package in the
  /// current workspace.
  String get pathModulesXml {
    return joinAll([pathDotIdea, 'modules.xml']);
  }

  Future<String> pathTemplatesForDirectory(String directory) async {
    return joinAll([await pathTemplates, directory]);
  }

  String pathPackageModuleIml(Package package) {
    return joinAll([package.path, 'melos_${package.name}.iml']);
  }

  String injectTemplateVariable({
    required String template,
    required String variableName,
    required String variableValue,
  }) {
    return template.replaceAll('{{#$variableName}}', variableValue);
  }

  String injectTemplateVariables(
    String template,
    Map<String, String> variables,
  ) {
    var updatedTemplate = template;
    variables.forEach((key, value) {
      updatedTemplate = injectTemplateVariable(
        template: updatedTemplate,
        variableName: key,
        variableValue: value,
      );
    });
    return updatedTemplate;
  }

  String ideaModuleStringForName(String moduleName, {String? relativePath}) {
    var module = '';
    if (relativePath == null) {
      module =
          '<module fileurl="file://\$PROJECT_DIR\$/melos_$moduleName.iml" filepath="\$PROJECT_DIR\$/melos_$moduleName.iml" />';
    } else {
      module =
          '<module fileurl="file://\$PROJECT_DIR\$/$relativePath/melos_$moduleName.iml" filepath="\$PROJECT_DIR\$/$relativePath/melos_$moduleName.iml" />';
    }
    // Pad to preserve formatting on generated file. Indent x6.
    return '      $module';
  }

  /// Reads a file template from the templates directory.
  /// Additionally keeps a cache to reduce reads.
  Future<String> readFileTemplate(
    String fileName, {
    String? templateCategory,
  }) async {
    if (_cacheTemplates[fileName] != null) return _cacheTemplates[fileName]!;

    String templatesRootPath;
    if (templateCategory != null) {
      templatesRootPath = await pathTemplatesForDirectory(templateCategory);
    } else {
      templatesRootPath = await pathTemplates;
    }

    final templateFile =
        File(joinAll([templatesRootPath, '$fileName$_kTmplExtension']));
    final template = await templateFile.readAsString();

    _cacheTemplates[fileName] = template;

    return template;
  }

  Future<void> forceWriteToFile(String filePath, String fileContents) async {
    final outputFile = File(filePath);
    await outputFile.create(recursive: true);
    await outputFile.writeAsString(fileContents);
  }

  /// Create a .name file using the workspace name.
  /// This gets picked up by the IDE and is used for display purposes.
  Future<void> writeNameFile() {
    return forceWriteToFile(pathDotName, _workspace.config.name);
  }

  String moduleTemplateFileForPackageType(PackageType type) {
    switch (type) {
      case PackageType.flutterPackage:
      case PackageType.flutterPlugin:
        return 'flutter_plugin_module.iml';
      case PackageType.flutterApp:
        return 'flutter_app_module.iml';
      case PackageType.dartPackage:
      default:
        return 'dart_package_module.iml';
    }
  }

  Future<void> writePackageModule(Package package) async {
    final template = await readFileTemplate(
      moduleTemplateFileForPackageType(package.type),
      templateCategory: 'modules',
    );
    return forceWriteToFile(pathPackageModuleIml(package), template);
  }

  Future<void> writeWorkspaceModule() async {
    final ideaWorkspaceModuleImlTemplate = await readFileTemplate(
      'workspace_root_module.iml',
      templateCategory: 'modules',
    );
    final workspaceModuleName = _workspace.config.name.toLowerCase();
    return forceWriteToFile(
      joinAll([_workspace.path, 'melos_$workspaceModuleName.iml']),
      ideaWorkspaceModuleImlTemplate,
    );
  }

  Future<void> writeModulesXml() async {
    final ideaModules = <String>[];
    final workspaceModuleName = _workspace.config.name.toLowerCase();
    for (final package in _workspace.filteredPackages.values) {
      ideaModules.add(
        ideaModuleStringForName(
          package.name,
          relativePath: package.pathRelativeToWorkspace,
        ),
      );
    }
    ideaModules.add(ideaModuleStringForName(workspaceModuleName));
    final ideaModulesXmlTemplate = await readFileTemplate('modules.xml');
    final generatedModulesXml = injectTemplateVariable(
      template: ideaModulesXmlTemplate,
      variableName: 'modules',
      variableValue: ideaModules.join('\n'),
    );
    return forceWriteToFile(pathModulesXml, generatedModulesXml);
  }

  String getMelosBinForIde() {
    if (currentPlatform.isWindows) {
      if (currentPlatform.script.path.contains('Roaming')) {
        return r'$USER_HOME$/AppData/Roaming/Pub/Cache/bin/melos.bat';
      }
      return r'$USER_HOME$/AppData/Local/Pub/Cache/bin/melos.bat';
    }
    return r'$USER_HOME$/.pub-cache/bin/melos';
  }

  Future<void> writeMelosScripts() async {
    final melosScriptTemplate = await readFileTemplate(
      'shell_script.xml',
      templateCategory: 'runConfigurations',
    );
    final runConfigurations = <String, String>{
      'Melos -&gt; Bootstrap Workspace': 'bootstrap',
      'Melos -&gt; Clean Workspace': 'clean',
    };

    for (final key in _workspace.config.scripts.keys) {
      runConfigurations["Melos Run -&gt; '$key'"] = 'run $key';
    }

    await Future.forEach(runConfigurations.keys, (String scriptName) async {
      final scriptArgs = runConfigurations[scriptName]!;

      final generatedRunConfiguration =
          injectTemplateVariables(melosScriptTemplate, {
        'scriptName': scriptName,
        'scriptArgs': scriptArgs,
        'scriptPath': getMelosBinForIde(),
      });

      final outputFile = joinAll([
        pathDotIdea,
        'runConfigurations',
        'melos_${scriptArgs.replaceAll(RegExp('[^A-Za-z0-9]'), '_')}.xml'
      ]);

      await forceWriteToFile(outputFile, generatedRunConfiguration);
    });
  }

  Future<void> writeFlutterRunScripts() async {
    final flutterTestTemplate = await readFileTemplate(
      'flutter_run.xml',
      templateCategory: 'runConfigurations',
    );

    await Future.forEach(_workspace.filteredPackages.values,
        (Package package) async {
      if (!package.isFlutterApp) return;

      final generatedRunConfiguration =
          injectTemplateVariables(flutterTestTemplate, {
        'flutterRunName': "Flutter Run -&gt; '${package.name}'",
        'flutterRunMainDartPathRelative':
            joinAll([package.pathRelativeToWorkspace, 'lib', 'main.dart']),
      });
      final outputFile = joinAll([
        pathDotIdea,
        'runConfigurations',
        'melos_flutter_run_${package.name}.xml'
      ]);

      await forceWriteToFile(outputFile, generatedRunConfiguration);
    });
  }

  Future<void> writeFlutterTestScripts() async {
    final flutterTestTemplate = await readFileTemplate(
      'flutter_test.xml',
      templateCategory: 'runConfigurations',
    );

    await Future.forEach(_workspace.filteredPackages.values,
        (Package package) async {
      if (!package.isFlutterPackage ||
          package.isFlutterApp ||
          !package.hasTests) {
        return;
      }

      final generatedRunConfiguration =
          injectTemplateVariables(flutterTestTemplate, {
        'flutterTestsName': "Flutter Test -&gt; '${package.name}'",
        'flutterTestsRelativePath':
            joinAll([package.pathRelativeToWorkspace, 'test']),
      });
      final outputFile = joinAll([
        pathDotIdea,
        'runConfigurations',
        'melos_flutter_test_${package.name}.xml'
      ]);

      await forceWriteToFile(outputFile, generatedRunConfiguration);
    });
  }

  Future<void> generate() async {
    // <WORKSPACE_ROOT>/.idea/.name
    await writeNameFile();

    // <WORKSPACE_ROOT>/<PACKAGE_DIR>/<PACKAGE_NAME>.iml

    await Future.forEach(_workspace.filteredPackages.values,
        (Package package) async {
      await writePackageModule(package);
    });

    // <WORKSPACE_ROOT>/<WORKSPACE_NAME>.iml
    await writeWorkspaceModule();

    // <WORKSPACE_ROOT>/.idea/modules.xml
    await writeModulesXml();

    // <WORKSPACE_ROOT>/.idea/runConfigurations/<SCRIPT_NAME>.xml
    await writeMelosScripts();

    await writeFlutterRunScripts();
    await writeFlutterTestScripts();
  }
}
