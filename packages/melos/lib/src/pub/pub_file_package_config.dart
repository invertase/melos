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
import '../common/utils.dart' as utils;
import '../common/workspace.dart';
import '../pub/pub_file.dart';

class PackageConfigPubFile extends PubFile {
  List<Map> _packages;

  Map<String, dynamic> _jsonParsed;

  Future<List<Map>> get packages async {
    if (_packages != null) return _packages;

    var input = await File(filePath).readAsString();

    _jsonParsed = Map.from(json.decode(input) as LinkedHashMap);

    if (_jsonParsed['packages'] != null) {
      _packages = List.from(_jsonParsed['packages'] as List);
    } else {
      _packages = [];
    }

    return _packages;
  }

  PackageConfigPubFile._(String rootDirectory)
      : super(rootDirectory,
            '.dart_tool${Platform.pathSeparator}package_config.json');

  factory PackageConfigPubFile.fromDirectory(String fileRootDirectory) {
    return PackageConfigPubFile._(fileRootDirectory);
  }

  static Future<PackageConfigPubFile> fromWorkspacePackage(
      MelosWorkspace workspace, MelosPackage package) async {
    PackageConfigPubFile workspaceFile =
        PackageConfigPubFile.fromDirectory(workspace.melosToolPath);
    List<Map> packagePackages = [];
    List<Map> workspacePackages = await workspaceFile.packages;
    Set<String> dependencyGraph = await package.getDependencyGraph();

    workspacePackages.forEach((packageMap) {
      if (!dependencyGraph.contains(packageMap['name']) &&
          packageMap['name'] != package.name) {
        return;
      }

      var pluginPackage = json.decode(json.encode(packageMap)) as Map;
      var rootUri = pluginPackage['rootUri'] as String;

      if (!rootUri.startsWith('file:')) {
        rootUri = utils.relativePath(
            '${workspace.melosToolPath}${Platform.pathSeparator}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}$rootUri',
            '${package.path}${Platform.pathSeparator}.dart_tool');

        pluginPackage['rootUri'] = rootUri;
      }

      packagePackages.add(pluginPackage);
    });

    var packageFile = PackageConfigPubFile._(package.path);
    packageFile._packages = packagePackages;
    packageFile._jsonParsed = Map.from(workspaceFile._jsonParsed);
    packageFile._jsonParsed['packages'] = packagePackages;
    return packageFile;
  }

  @override
  String toString() {
    var encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_jsonParsed);
  }
}
