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

class IntellijProject {
  final MelosWorkspace _workspace;

  final Map<String, String> _cacheTemplates = <String, String>{};

  IntellijProject._(this._workspace);

  static IntellijProject fromWorkspace(MelosWorkspace workspace) {
    return IntellijProject._(workspace);
  }

  String get pathTemplates {
    return joinAll([
      utils.getMelosRoot(),
      _kTemplatesDirName,
      _kIntellijDirName,
    ]);
  }

  String get pathDotIdea {
    return joinAll([_workspace.path, _kDotIdeaDirName]);
  }

  String get pathDotName {
    return joinAll([pathDotIdea, '.name']);
  }

  String get pathModulesXml {
    return joinAll([pathDotIdea, 'modules.xml']);
  }

  String pathTemplatesForCategory(String category) {
    return joinAll([pathTemplates, category]);
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
      templatesRootPath = pathTemplatesForCategory(templateCategory);
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

    // TODO move to own fn
    // TODO flutter run scripts for apps
    // TODO flutter test scripts for flutter packages (but not apps)
    // TODO dart test scripts for dart packages
    // Generate Melos scripts.
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
      await forceWriteToFile(
          File('$pathDotIdea${Platform.pathSeparator}runConfigurations${Platform.pathSeparator}melos_${scriptArgs.replaceAll(' ', '_')}.xml')
              .path,
          generatedRunConfiguration);
    });
  }
}
