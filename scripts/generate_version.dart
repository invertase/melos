import 'dart:io';

import 'package:path/path.dart' show joinAll;
import 'package:yaml/yaml.dart' show loadYaml;

void main() async {
  String outputPath = joinAll(
      [Directory.current.path, 'packages', 'melos', 'lib', 'version.dart']);
  print('Updating generated file $outputPath');
  String melosPubspecPath =
      joinAll([Directory.current.path, 'packages', 'melos', 'pubspec.yaml']);
  Map yamlMap = loadYaml(File(melosPubspecPath).readAsStringSync()) as Map;
  String currentVersion = yamlMap['version'] as String;
  String fileContents =
      '// This file is generated. Do not manually edit.\nString melosVersion = \'$currentVersion\';\n';
  await File(outputPath).writeAsString(fileContents);
  print('Updated version to $currentVersion in generated file $outputPath');
}
