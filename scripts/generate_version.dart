// @dart=2.9

import 'dart:io' show Directory, File;
import 'package:path/path.dart' show joinAll;
import 'package:yaml/yaml.dart' show YamlMap, loadYaml;

Future<void> main() async {
  final outputPath = joinAll(
    [Directory.current.path, 'packages', 'melos', 'lib', 'version.g.dart'],
  );
  // ignore: avoid_print
  print('Updating generated file $outputPath');
  final melosPubspecPath =
      joinAll([Directory.current.path, 'packages', 'melos', 'pubspec.yaml']);
  final yamlMap =
      loadYaml(File(melosPubspecPath).readAsStringSync()) as YamlMap;
  final currentVersion = yamlMap['version'] as String;
  final fileContents =
      "// This file is generated. Do not manually edit.\nString melosVersion = '$currentVersion';\n";
  await File(outputPath).writeAsString(fileContents);
  // ignore: avoid_print
  print('Updated version to $currentVersion in generated file $outputPath');
}
