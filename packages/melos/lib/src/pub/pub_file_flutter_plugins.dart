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

import '../common/package.dart';
import '../common/workspace.dart';
import '../pub/pub_file.dart';

class FlutterPluginsPubFile extends PubFile {
  Map<String, String> _entries;

  Future<Map<String, String>> get entries async {
    if (_entries != null) return _entries;

    var input = await File(filePath).readAsString();

    // ignore: omit_local_variable_types
    Map<String, String> packages = {};

    final regex = RegExp('^([a-z_A-Z0-9-]*)=(.*)\$', multiLine: true);

    regex.allMatches(input).forEach((match) {
      return packages[match[1]] = match[2];
    });

    _entries = packages;
    return _entries;
  }

  FlutterPluginsPubFile._(String rootDirectory)
      : super(rootDirectory, '.flutter-plugins');

  factory FlutterPluginsPubFile.fromDirectory(String fileRootDirectory) {
    return FlutterPluginsPubFile._(fileRootDirectory);
  }

  static Future<FlutterPluginsPubFile> fromWorkspacePackage(
      MelosWorkspace workspace, MelosPackage package) async {
    FlutterPluginsPubFile workspaceFlutterPluginsPubFile =
        FlutterPluginsPubFile.fromDirectory(workspace.melosToolPath);
    Map<String, String> newEntries = {};
    Map<String, String> workspaceEntries =
        await workspaceFlutterPluginsPubFile.entries;
    Set<String> dependencyGraph = await package.getDependencyGraph();

    workspaceEntries.forEach((name, path) {
      if (!dependencyGraph.contains(name) && name != package.name) {
        return;
      }
      newEntries[name] = path;
    });

    var flutterPluginsFile = FlutterPluginsPubFile._(package.path);
    flutterPluginsFile._entries = newEntries;
    return flutterPluginsFile;
  }

  @override
  String toString() {
    var string =
        '# This is a generated file; do not edit or check into version control.';
    _entries.forEach((key, value) {
      string += '\n$key=$value';
    });
    return string;
  }
}
