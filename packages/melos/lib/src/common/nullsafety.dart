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

import 'package:dart_style/dart_style.dart' show DartFormatter;

import './workspace_config.dart';

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

  MelosWorkspaceNullsafetyConfig(this._workspaceConfig);
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
