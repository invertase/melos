import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' show relative;
import 'package:yaml/yaml.dart';

import 'logger.dart';

String getAndroidSdkRoot() {
  var possibleSdkRoot = Platform.environment['ANDROID_SDK_ROOT'];
  if (possibleSdkRoot == null) {
    logger.stderr(
        "Android SDK root could not be found, ensure you've set the ANDROID_SDK_ROOT environment variable.");
    return '';
  }
  return possibleSdkRoot;
}

String getFlutterSdkRoot() {
  var result = Process.runSync('which', ['flutter']);
  var possiblePath = result.stdout.toString();
  if (!possiblePath.contains('bin/flutter')) {
    logger.stderr('Flutter SDK could not be found.');
    exit(1);
  }
  return File(result.stdout as String).parent.parent.path;
}

Map loadYamlFileSync(String path) {
  var file = File(path);
  if (file?.existsSync() == true) {
    return loadYaml(file.readAsStringSync()) as Map;
  }
  return null;
}

Future<Map> loadYamlFile(String path) async {
  var file = File(path);
  if (await file?.exists() == true) {
    return loadYaml(await file.readAsString()) as Map;
  }
  return null;
}

String melosYamlPathForDirectory(Directory pluginDirectory) {
  return pluginDirectory.path + Platform.pathSeparator + 'melos.yaml';
}

String pubspecPathForDirectory(Directory pluginDirectory) {
  return pluginDirectory.path + Platform.pathSeparator + 'pubspec.yaml';
}

String relativePath(String path, String from) {
  return relative(path, from: from);
}

/// Simple check to see if the [Directory] qualifies as a plugin repository.
bool isWorkspaceDirectory(Directory directory) {
  var melosYamlPath = melosYamlPathForDirectory(directory);
  return FileSystemEntity.isFileSync(melosYamlPath);
}

bool isPackageDirectory(Directory directory) {
  var pluginYamlPath = pubspecPathForDirectory(directory);
  return FileSystemEntity.isFileSync(pluginYamlPath);
}
