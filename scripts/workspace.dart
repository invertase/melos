import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:yamlicious/yamlicious.dart';

Map<String, String> detectedPlugins = Map();

String workspaceTemplate = '''
<?xml version="1.0" encoding="UTF-8"?>
<module type="JAVA_MODULE" version="4">
  <component name="NewModuleRootManager" inherit-compiler-output="true">
    <exclude-output />
[[CONTENT_ROOTS]]
    <content url="file://\$MODULE_DIR\$">
      <excludeFolder url="file://\$MODULE_DIR\$/.dart_tool" />
      <excludeFolder url="file://\$MODULE_DIR\$/.pub" />
      <excludeFolder url="file://\$MODULE_DIR\$/build" />
    </content>
    <orderEntry type="inheritedJdk" />
    <orderEntry type="sourceFolder" forTests="false" />
    <orderEntry type="library" name="Dart SDK" level="project" />
    <orderEntry type="library" name="Flutter Plugins" level="project" />
    <orderEntry type="library" name="Dart Packages" level="project" />
  </component>
</module>
''';

String workspaceContentRootTemplate = '''
    <content url="file://\$MODULE_DIR\$/[[CONTENT_ROOT]]">
      <excludeFolder url="file://\$MODULE_DIR\$/[[CONTENT_ROOT]]/.dart_tool" />
      <excludeFolder url="file://\$MODULE_DIR\$/[[CONTENT_ROOT]]/.pub" />
      <excludeFolder url="file://\$MODULE_DIR\$/[[CONTENT_ROOT]]/build" />
    </content>
''';

String yamlTemplate = '''
name: "flutterfire_workspace"
description: "A monorepo workspace to help plugin development for FlutterFire."
version: "0.0.1"
dependencies: 
  flutter: 
    sdk: "flutter"
environment: 
  flutter: ">=1.12.13+hotfix.4 <2.0.0"
  sdk: ">=2.0.0-dev.28.0 <3.0.0"
''';

Map loadYamlFileSync(String path) {
  File file = new File(path);
  if (file?.existsSync() == true) {
    return loadYaml(file.readAsStringSync());
  }
  return null;
}

void addDetectedPlugin(String pluginRoot, String pluginYamlPath) {
  Map yamlFile = loadYamlFileSync(pluginYamlPath);
  String pluginName = yamlFile['name'];
  String pluginRelativeDir =
      pluginRoot.replaceFirst(Directory.current.parent.path, '../..');
  detectedPlugins[pluginName] = pluginRelativeDir;
  print('Plugin "$pluginName" detected in "$pluginRelativeDir"');
}

void main() {
  Directory pluginsRepoDir = Directory(
      Directory.current.parent.path + Platform.pathSeparator + 'flutterfire');
  Directory pluginsPackagesDir =
      Directory(pluginsRepoDir.path + Platform.pathSeparator + 'packages');

  print('CWD: ' + Directory.current.path);
  print('Plugins Root: ' + pluginsRepoDir.path);
  print('Packages Root: ' + pluginsPackagesDir.path);

  pluginsPackagesDir.listSync().forEach((FileSystemEntity rootEntity) {
    bool isDirectory = FileSystemEntity.isDirectorySync(rootEntity.path);
    if (!isDirectory) return;

    String rootPluginYamlPath =
        rootEntity.path + Platform.pathSeparator + 'pubspec.yaml';

    if (FileSystemEntity.isFileSync(rootPluginYamlPath)) {
      return addDetectedPlugin(rootEntity.path, rootPluginYamlPath);
    }

    Directory(rootEntity.path)
        .listSync()
        .forEach((FileSystemEntity childEntity) {
      bool isDirectory = FileSystemEntity.isDirectorySync(childEntity.path);
      if (!isDirectory) return;

      String nestedPluginYamlPath =
          childEntity.path + Platform.pathSeparator + 'pubspec.yaml';

      if (FileSystemEntity.isFileSync(nestedPluginYamlPath)) {
        return addDetectedPlugin(childEntity.path, nestedPluginYamlPath);
      }
    });
  });

  if (detectedPlugins.isEmpty) {
    print('No plugins detected! :(');
    exit(1);
  }

  String workspaceImlPath = Directory.current.path +
      Platform.pathSeparator +
      'workspace' +
      Platform.pathSeparator +
      'workspace.iml';
  String workspaceYamlPath = Directory.current.path +
      Platform.pathSeparator +
      'workspace' +
      Platform.pathSeparator +
      'pubspec.yaml';

  Map workspaceYaml = json.decode(json.encode(loadYaml(yamlTemplate)));
  workspaceYaml['dependencies'] = {};
  workspaceYaml['dependency_overrides'] = {};

  String workspaceImlContentRoots = '';

  detectedPlugins.forEach((String pluginName, String pluginPath) {
    workspaceYaml['dependencies'][pluginName] = {
      "path": pluginPath,
    };
    workspaceYaml['dependency_overrides'][pluginName] = {
      "path": pluginPath,
    };
    workspaceImlContentRoots +=
        workspaceContentRootTemplate.replaceAll('[[CONTENT_ROOT]]', pluginPath);
  });

  File(workspaceYamlPath).writeAsStringSync(toYamlString(workspaceYaml));
  File(workspaceImlPath).writeAsStringSync(workspaceTemplate.replaceAll(
      '[[CONTENT_ROOTS]]', workspaceImlContentRoots));
}
