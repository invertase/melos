import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:yamlicious/yamlicious.dart';

Map<String, String> detectedPlugins = Map();

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
      pluginRoot.replaceFirst(Directory.current.parent.path, '..');
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

  String sidecarYamlPath =
      Directory.current.path + Platform.pathSeparator + 'pubspec.yaml';
  Map sideCarYaml = json.decode(json.encode(loadYamlFileSync(sidecarYamlPath)));

  detectedPlugins.forEach((String pluginName, String pluginPath) {
    sideCarYaml['dependencies'][pluginName] = {
      "path": pluginPath,
    };
    sideCarYaml['dependency_overrides'][pluginName] = {
      "path": pluginPath,
    };
  });

  File(sidecarYamlPath).writeAsStringSync(toYamlString(sideCarYaml));
}
