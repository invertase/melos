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

  List<Map> get packages {
    if (_packages != null) return _packages;

    var input = File(filePath).readAsStringSync();

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

  factory PackageConfigPubFile.fromWorkspacePackage(
      MelosWorkspace workspace, MelosPackage package) {
    var workspacePackageConfigPubFile =
        PackageConfigPubFile.fromDirectory(workspace.path);

    // ignore: omit_local_variable_types
    List<Map> newPackages = [];
    var dependencyGraph = package.getDependencyGraph();

    workspacePackageConfigPubFile.packages.forEach((packageMap) {
      if (!dependencyGraph.contains(packageMap['name'])) {
        return;
      }

      var pluginPackage = json.decode(json.encode(packageMap)) as Map;
      var rootUri = pluginPackage['rootUri'] as String;

      if (!rootUri.startsWith('file:')) {
        rootUri = utils.relativePath(
            '${workspace.path}${Platform.pathSeparator}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}$rootUri',
            '${package.path}${Platform.pathSeparator}.dart_tool');

        pluginPackage['rootUri'] = rootUri;
      }

      newPackages.add(pluginPackage);
    });

    var packageConfigFile = PackageConfigPubFile._(package.path);
    packageConfigFile._packages = newPackages;
    packageConfigFile._jsonParsed =
        Map.from(workspacePackageConfigPubFile._jsonParsed);
    packageConfigFile._jsonParsed['packages'] = newPackages;
    return packageConfigFile;
  }

  @override
  String toString() {
    var encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_jsonParsed);
  }
}
