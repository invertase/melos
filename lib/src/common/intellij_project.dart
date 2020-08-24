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

import 'package:meta/meta.dart';
import 'package:path/path.dart' show joinAll;

import '../common/package.dart';
import '../common/utils.dart' as utils;
import '../common/workspace.dart';

const String _kTemplatesDirName = 'templates';
const String _kIntellijDirName = 'intellij';
const String _kDotIdeaDirName = '.idea';
const String _kTmplExtension = '.tmpl';

/// IntelliJ project IDE configuration helper.
class IntellijProject {
  final MelosWorkspace _workspace;

  final Map<String, String> _cacheTemplates = <String, String>{};

  IntellijProject._(this._workspace);

  /// Build a new [IntellijProject] from a [MelosWorkspace].
  static IntellijProject fromWorkspace(MelosWorkspace workspace) {
    return IntellijProject._(workspace);
  }

  /// Fully qualified path to the intellij templates shiped as part of Melos.
  String get pathTemplates {
    return joinAll([
      utils.getMelosRoot(),
      _kTemplatesDirName,
      _kIntellijDirName,
    ]);
  }

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

  String pathTemplatesForDirectory(String directory) {
    return joinAll([pathTemplates, directory]);
  }

  String pathPackageModuleIml(MelosPackage package) {
    return joinAll([package.path, '${package.name}.iml']);
  }

  String injectTemplateVariable(
      {@required String template,
      @required String variableName,
      @required String variableValue}) {
    return template.replaceAll('{{#$variableName}}', variableValue);
  }

  String injectTemplateVariables(
      String template, Map<String, String> variables) {
    String updatedTemplate = template;
    variables.forEach((key, value) {
      updatedTemplate = injectTemplateVariable(
          template: updatedTemplate, variableName: key, variableValue: value);
    });
    return updatedTemplate;
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

  Future<void> cleanProject() async {
    // TODO
  }

  /// Reads a file template from the templates directory.
  /// Additionally keeps a cache to reduce reads.
  Future<String> readFileTemplate(String fileName,
      {String templateCategory}) async {
    if (_cacheTemplates[fileName] != null) {
      return _cacheTemplates[fileName];
    }
    String templatesRootPath;
    if (templateCategory != null) {
      templatesRootPath = pathTemplatesForDirectory(templateCategory);
    } else {
      templatesRootPath = pathTemplates;
    }

    File templateFile =
        File(joinAll([templatesRootPath, '$fileName$_kTmplExtension']));

    String template = await templateFile.readAsString();
    _cacheTemplates[fileName] = template;
    return template;
  }

  Future<void> forceWriteToFile(String filePath, String fileContents) async {
    File outputFile = File(filePath);
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

  Future<void> writePackageModule(MelosPackage package) async {
    String template = await readFileTemplate(
        moduleTemplateFileForPackageType(package.type),
        templateCategory: 'modules');
    // Generate package module.
    return forceWriteToFile(pathPackageModuleIml(package), template);
  }

  Future<void> writeWorkspaceModule() async {
    String ideaWorkspaceModuleImlTemplate = await readFileTemplate(
        'workspace_root_module.iml',
        templateCategory: 'modules');
    String workspaceModuleName = _workspace.config.name.toLowerCase();
    return forceWriteToFile(
        joinAll([_workspace.path, '$workspaceModuleName.iml']),
        ideaWorkspaceModuleImlTemplate);
  }

  Future<void> writeModulesXml() async {
    List<String> ideaModules = [];
    String workspaceModuleName = _workspace.config.name.toLowerCase();
    _workspace.packages.forEach((package) {
      ideaModules.add(ideaModuleStringForName(package.name,
          relativePath: package.pathRelativeToWorkspace));
    });
    ideaModules.add(ideaModuleStringForName(workspaceModuleName));
    String ideaModulesXmlTemplate = await readFileTemplate('modules.xml');
    String generatedModulesXml = injectTemplateVariable(
        template: ideaModulesXmlTemplate,
        variableName: 'modules',
        variableValue: ideaModules.join('\n'));
    return forceWriteToFile(pathModulesXml, generatedModulesXml);
  }

  Future<void> writeMelosScripts() async {
    String melosScriptTemplate = await readFileTemplate('melos_script.xml',
        templateCategory: 'runConfigurations');

    Map<String, String> runConfigurations = <String, String>{
      'Melos -&gt; Bootstrap Workspace': 'bootstrap',
      'Melos -&gt; Clean Workspace': 'clean',
    };
    _workspace.config.scripts.keys.forEach((key) {
      runConfigurations["Melos Run -&gt; '$key'"] = 'run $key';
    });

    await Future.forEach(runConfigurations.keys, (String scriptName) async {
      String scriptArgs = runConfigurations[scriptName];
      String generatedRunConfiguration = injectTemplateVariable(
          template: melosScriptTemplate,
          variableName: 'scriptName',
          variableValue: scriptName);
      generatedRunConfiguration = injectTemplateVariable(
          template: generatedRunConfiguration,
          variableName: 'scriptArgs',
          variableValue: scriptArgs);
      String outputFile = joinAll([
        pathDotIdea,
        'runConfigurations',
        'melos_${scriptArgs.replaceAll(' ', '_')}.xml'
      ]);
      await forceWriteToFile(outputFile, generatedRunConfiguration);
    });
  }

  Future<void> writeFlutterRunScripts() async {
    // todo
  }

  Future<void> writeFlutterTestScripts() async {
    // todo
  }

  Future<void> writeFiles() async {
    // <WORKSPACE_ROOT>/.idea/.name
    await writeNameFile();

    // <WORKSPACE_ROOT>/<PACKAGE_DIR>/<PACKAGE_NAME>.iml
    await Future.forEach(_workspace.packages, (MelosPackage package) async {
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
