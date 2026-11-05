// ignore_for_file: avoid_print

import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Future<void> main() async {
  final outputPath = p.joinAll(
    [Directory.current.path, 'packages', 'melos', 'lib', 'version.g.dart'],
  );
  print('Updating generated file $outputPath');
  final melosPubspecPath = p.joinAll([
    Directory.current.path,
    'packages',
    'melos',
    'pubspec.yaml',
  ]);
  final yamlMap =
      loadYaml(File(melosPubspecPath).readAsStringSync()) as YamlMap;
  final currentVersion = yamlMap['version'] as String;
  final fileContents =
      "// This file is generated. Do not manually edit.\nString melosVersion = '$currentVersion';\n";
  await File(outputPath).writeAsString(fileContents);
  print('Updated version to $currentVersion in generated file $outputPath');
}
