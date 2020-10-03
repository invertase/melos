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

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import '../common/package.dart';
import '../common/workspace.dart';
import '../pub/pub_file.dart';

class FlutterDependenciesPubFile extends PubFile {
  List<Map> _dependencyGraph;

  Map<String, List> _plugins;

  Map<String, dynamic> _jsonParsed;

  Future<List<Map>> get dependencyGraph async {
    if (_dependencyGraph != null) return _dependencyGraph;

    var input = await File(filePath).readAsString();

    _jsonParsed = Map.from(json.decode(input) as LinkedHashMap);

    if (_jsonParsed['dependencyGraph'] != null) {
      _dependencyGraph = List.from(_jsonParsed['dependencyGraph'] as List);
    } else {
      _dependencyGraph = [];
    }

    return _dependencyGraph;
  }

  Future<Map<String, List>> get plugins async {
    if (_plugins != null) return _plugins;

    var input = await File(filePath).readAsString();

    _jsonParsed = Map.from(json.decode(input) as LinkedHashMap);

    if (_jsonParsed['plugins'] != null) {
      _plugins = Map.from(_jsonParsed['plugins'] as LinkedHashMap);
    } else {
      _plugins = {};
    }

    return _plugins;
  }

  FlutterDependenciesPubFile._(String rootDirectory)
      : super(rootDirectory, '.flutter-plugins-dependencies');

  factory FlutterDependenciesPubFile.fromDirectory(String fileRootDirectory) {
    return FlutterDependenciesPubFile._(fileRootDirectory);
  }

  static Future<FlutterDependenciesPubFile> fromWorkspacePackage(
      MelosWorkspace workspace, MelosPackage package) async {
    FlutterDependenciesPubFile workspaceFile =
        FlutterDependenciesPubFile.fromDirectory(workspace.melosToolPath);

    List<Map> packageDependencyGraph = [];
    Map<String, List> packagePlugins = {
      kAndroid: [],
      kIos: [],
      kLinux: [],
      kMacos: [],
      kWeb: [],
      kWindows: [],
    };
    Set<String> pluginsForPackage = <String>{};
    Map<String, List> workspacePlugins = await workspaceFile.plugins;
    List<Map> workspaceDependencyGraph = await workspaceFile.dependencyGraph;
    Set<String> pubDependencyGraph = await package.getDependencyGraph();

    workspaceDependencyGraph.forEach((dependencyGraphMap) {
      if (!pubDependencyGraph.contains(dependencyGraphMap['name']) &&
          dependencyGraphMap['name'] != package.name) {
        return;
      }
      List<String> dependencies =
          List.from(dependencyGraphMap['dependencies'] as List);
      pluginsForPackage.add(dependencyGraphMap['name'] as String);
      pluginsForPackage.addAll(dependencies);
    });

    [kAndroid, kIos, kLinux, kMacos, kWeb, kWindows].forEach((platform) {
      workspacePlugins[platform].forEach((plugin) {
        if (pluginsForPackage.contains(plugin['name'])) {
          packagePlugins[platform].add(Map.from(plugin as Map));
        }
      });
    });

    workspaceDependencyGraph.forEach((dependencyGraphMap) {
      if (pluginsForPackage.contains(dependencyGraphMap['name'])) {
        packageDependencyGraph.add(Map.from(dependencyGraphMap));
      }
    });

    var packageFile = FlutterDependenciesPubFile._(package.path);
    packageFile._dependencyGraph = packageDependencyGraph;
    packageFile._plugins = packagePlugins;
    packageFile._jsonParsed = Map.from(workspaceFile._jsonParsed);
    packageFile._jsonParsed['plugins'] = packagePlugins;
    packageFile._jsonParsed['dependencyGraph'] = packageDependencyGraph;
    return packageFile;
  }

  @override
  String toString() {
    var encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_jsonParsed);
  }
}
