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

import 'package:ansi_styles/ansi_styles.dart';
import 'package:dart_style/dart_style.dart' show DartFormatter;
import 'package:pub_semver/pub_semver.dart';

import './workspace_config.dart';
import 'logger.dart';
import 'utils.dart';

export 'package:dart_style/dart_style.dart' show FormatterException;

DartFormatter _dartFormatter;

enum CodeModType {
  none,
  deleteFile,
  stripTaggedCode,
  stripTaggedCodeHasInvalidPair,
}

class NullsafetyModifiedFile {
  final String workingDirectory;
  final String path;

  NullsafetyModifiedFile(this.workingDirectory, this.path);

  @override
  bool operator ==(Object other) =>
      other is NullsafetyModifiedFile && other.hashCode == hashCode;

  @override
  int get hashCode => '$workingDirectory,$path'.hashCode;
}

Map<String, dynamic> _validateFilterPackageOptions(
  Map<String, dynamic> filterPackageOptions,
) {
  Map<String, dynamic> result = {};

  List<String> _asStringList(String optionName, dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return List<String>.from(value);
    logger.stderr(AnsiStyles.red(
      'Filter package option "$optionName" in nullsafety filter config is invalid, option should be either a string or a list of strings.',
    ));
    exit(1);
  }

  String _asString(String optionName, dynamic value) {
    if (value is String) return value;
    logger.stderr(AnsiStyles.red(
      'Filter package option "$optionName" in nullsafety filter config is invalid, option should be a string value.',
    ));
    exit(1);
  }

  bool _asBool(String optionName, dynamic value) {
    if (value is bool) return value;
    logger.stderr(AnsiStyles.red(
      'Filter package option "$optionName" in nullsafety filter config is invalid, option should be a bool value.',
    ));
    exit(1);
  }

  // String or List
  result[filterOptionScope] = _asStringList(
    filterOptionScope,
    filterPackageOptions[filterOptionScope],
  );
  result[filterOptionIgnore] = _asStringList(
    filterOptionIgnore,
    filterPackageOptions[filterOptionIgnore],
  );
  result[filterOptionDirExists] = _asStringList(
    filterOptionDirExists,
    filterPackageOptions[filterOptionDirExists],
  );
  result[filterOptionFileExists] = _asStringList(
    filterOptionFileExists,
    filterPackageOptions[filterOptionFileExists],
  );

  // String
  if (filterPackageOptions.containsKey(filterOptionSince)) {
    result[filterOptionSince] = _asString(
      filterOptionSince,
      filterPackageOptions[filterOptionSince],
    );
  }

  // bool
  if (filterPackageOptions.containsKey(filterOptionNoPrivate)) {
    result[filterOptionNoPrivate] = _asBool(
      filterOptionNoPrivate,
      filterPackageOptions[filterOptionNoPrivate],
    );
  }
  if (filterPackageOptions.containsKey(filterOptionPublished)) {
    result[filterOptionPublished] = _asBool(
      filterOptionPublished,
      filterPackageOptions[filterOptionPublished],
    );
  }

  return result;
}

class MelosWorkspaceNullsafetyConfig {
  final MelosWorkspaceConfig _workspaceConfig;

  bool get exists {
    return _workspaceConfig.exists &&
        _workspaceConfig.map['nullsafety'] != null &&
        _workspaceConfig.map['nullsafety'] is Map;
  }

  bool get environmentExists {
    return exists &&
        _workspaceConfig.map['nullsafety']['environment'] != null &&
        _workspaceConfig.map['nullsafety']['environment'] is Map;
  }

  String get environmentSdkVersion {
    if (!environmentExists) return null;
    return _workspaceConfig.map['nullsafety']['environment']['sdk'] as String;
  }

  String get environmentFlutterVersion {
    if (!environmentExists) return null;
    return _workspaceConfig.map['nullsafety']['environment']['flutter']
        as String;
  }

  bool get shouldFilterPackages {
    return exists && _workspaceConfig.map['nullsafety']['filter'] is Map;
  }

  bool get shouldUpdateDependencies {
    return exists && _workspaceConfig.map['nullsafety']['dependencies'] is Map;
  }

  Map<String, String> get dependencies {
    if (!shouldUpdateDependencies) return null;
    return Map<String, String>.from(
        _workspaceConfig.map['nullsafety']['dependencies'] as Map);
  }

  Map get filterPackageOptions {
    if (!shouldFilterPackages) return null;
    return _validateFilterPackageOptions(
      Map.from(_workspaceConfig.map['nullsafety']['filter'] as Map),
    );
  }

  MelosWorkspaceNullsafetyConfig(this._workspaceConfig);
}

Version nullsafetyVersionFromCurrentVersion(Version currentVersion) {
  if (currentVersion.isPreRelease) {
    int currentPre = currentVersion.preRelease.length == 2
        ? currentVersion.preRelease[1] as int
        : -1;
    String currentPreidName = currentVersion.preRelease[0] as String;

    return Version(
      currentVersion.major,
      currentVersion.minor,
      currentVersion.patch,
      pre: 'nullsafety.$currentPreidName.$currentPre',
    );
  }

  int currentBuild =
      currentVersion.build.length == 1 ? currentVersion.build[0] as int : null;
  return Version(
    currentVersion.major,
    currentVersion.minor,
    currentVersion.patch,
    build: currentBuild != null ? currentBuild.toString() : null,
    pre: 'nullsafety',
  );
}

Future<void> setEnvironmentSdkVersionForYamlFile(
    String updatedVersion, String pathToYamlFile) async {
  File pubspec = File(pathToYamlFile);
  String originalContents = await pubspec.readAsString();

  RegExp replaceSdkEnvironmentRegex = RegExp(
    // https://regex101.com/r/mNvnAU/6
    '''(?<prefix>^environment:[^\\r\\n]*[\\r\\n].*?[\\s\\S]*?^\\s+sdk:\\s?["']?)(?<version>[^"'\\r\\n]*)(?<postfix>.*?\$)''',
    multiLine: true,
  );
  String updatedContents = originalContents.replaceAllMapped(
    replaceSdkEnvironmentRegex,
    (Match match) {
      return '${match.group(1)}$updatedVersion${match.group(3)}';
    },
  );

  // Sanity check that contents actually changed.
  if (originalContents == updatedContents) {
    logger.stdout(
      AnsiStyles.yellowBright(
        'Failed to update environment.sdk in file $pathToYamlFile to $updatedVersion, you should probably report this issue with a copy of your pubspec.yaml file.',
      ),
    );
    return;
  }

  return pubspec.writeAsString(updatedContents);
}

Future<void> setEnvironmentFlutterVersionForYamlFile(
    String updatedVersion, String pathToYamlFile) async {
  File pubspec = File(pathToYamlFile);
  String originalContents = await pubspec.readAsString();

  RegExp replaceFlutterEnvironmentRegex = RegExp(
    // https://regex101.com/r/mNvnAU/6
    '''(?<prefix>^environment:[^\\r\\n]*[\\r\\n].*?[\\s\\S]*?^\\s+flutter:\\s?["']?)(?<version>[^"'\\r\\n]*)(?<postfix>.*?\$)''',
    multiLine: true,
  );
  String updatedContents = originalContents.replaceAllMapped(
    replaceFlutterEnvironmentRegex,
    (Match match) {
      return '${match.group(1)}$updatedVersion${match.group(3)}';
    },
  );

  // Sanity check that contents actually changed.
  if (originalContents == updatedContents) {
    logger.stdout(
      AnsiStyles.yellowBright(
        'Failed to update environment.flutter in file $pathToYamlFile to $updatedVersion, you should probably report this issue with a copy of your pubspec.yaml file.',
      ),
    );
    return;
  }

  return pubspec.writeAsString(updatedContents);
}

Future<CodeModType> applyNullsafetyCodeModsToFile(File file) async {
  String fileContent = await file.readAsString();

  if (fileContent.contains('melos-nullsafety-delete-file')) {
    await File(file.path).delete();
    return CodeModType.deleteFile;
  }

  if (fileContent.contains('melos-nullsafety-remove-start')) {
    String fileContentModified = fileContent.replaceAll(
      // https://regex101.com/r/pSNFgf/5/
      RegExp(
        r'([^\S\r\n]+)?\/\*\s?melos-nullsafety-remove-start\s?\*\/[\s\S\n]+?(\/\*\s?melos-nullsafety-remove-end\s?\*\/\n?)',
      ),
      '',
    );

    // Check if contents still contain a start or end tag - this would indicate
    // somewhere in the file there's an invalid start & end pair added by the user.
    if (fileContentModified.contains('melos-nullsafety-remove-start') ||
        fileContentModified.contains('melos-nullsafety-remove-end')) {
      return CodeModType.stripTaggedCodeHasInvalidPair;
    }

    _dartFormatter ??= DartFormatter();
    fileContentModified = _dartFormatter.format(fileContentModified);
    await File(file.path).writeAsString(fileContentModified);
    return CodeModType.stripTaggedCode;
  }

  return CodeModType.none;
}
