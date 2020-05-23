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
        PackageConfigPubFile.fromDirectory(workspace.path);
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
            '${workspace.path}${Platform.pathSeparator}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}$rootUri',
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
