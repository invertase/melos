import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';

import '../pub/pub_deps_list.dart';
import '../pub/pub_file_flutter_plugins.dart';
import '../pub/pub_file_package_config.dart';
import '../pub/pub_file_packages.dart';
import '../pub/pub_file_pubspec_lock.dart';
import 'logger.dart';
import 'package.dart';
import 'workspace_config.dart';

MelosWorkspace currentWorkspace;

class MelosWorkspace {
  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

  Map<String, Set<String>> _dependencyGraph;

  final MelosWorkspaceConfig _config;

  MelosWorkspaceConfig get config => _config;

  List<MelosPackage> _packages;

  List<MelosPackage> get packages => _packages;

  MelosWorkspace._(this._name, this._path, this._config);

  static Future<MelosWorkspace> fromDirectory(Directory directory,
      {@required ArgResults arguments}) async {
    final workspaceConfig = await MelosWorkspaceConfig.fromDirectory(directory);

    if (workspaceConfig == null) {
      return null;
    }

    return MelosWorkspace._(
        workspaceConfig.name, workspaceConfig.path, workspaceConfig);
  }

  Future<List<MelosPackage>> loadPackages(
      {List<String> scope, List<String> ignore}) async {
    if (_packages != null) return Future.value(_packages);

    _packages = await Directory(_path)
        .list(recursive: true, followLinks: false)
        .where((file) {
      return file.path.endsWith('pubspec.yaml');
    }).where((file) {
      // Filter matching 'packages' config from melos.yaml
      final packageGlobs = _config.packages;
      // No 'package' glob patterns in 'melos.yaml' so skip all packages.
      if (packageGlobs.isEmpty) return false;
      final matchedPattern = packageGlobs.firstWhere((pattern) {
        return pattern.matches(file.path);
      }, orElse: () => null);
      return matchedPattern != null;
    }).asyncMap((entity) async {
      // Convert into Package for further filtering
      return MelosPackage.fromPubspecPath(entity);
    }).where((package) {
      // Scoped packages filter.
      if (scope.isEmpty) return true;
      final matchedPattern = scope.firstWhere((pattern) {
        return Glob(pattern).matches(package.name);
      }, orElse: () => null);
      return matchedPattern != null;
    }).where((package) {
      // Ignore packages filter.
      if (ignore.isEmpty) return true;
      final matchedPattern = ignore.firstWhere((pattern) {
        return Glob(pattern).matches(package.name);
      }, orElse: () => null);
      return matchedPattern == null;
    }).toList();

    return _packages;
  }

  Map<String, Set<String>> dependencyGraph() {
    if (_dependencyGraph != null) {
      return _dependencyGraph;
    }

    final pubListCommandOutput = Process.runSync(
      'flutter',
      ['pub', 'deps', '--', '--style=list', '--dev'],
      runInShell: true,
      workingDirectory: _path,
    );

    final pubDepList = PubDepsList.parse(pubListCommandOutput.stdout as String);
    final allEntries = pubDepList.allEntries;
    final allEntriesMap = allEntries.map((entry, map) {
      return MapEntry(entry.name, map);
    });

    void addNestedEntries(Set entriesSet) {
      var countBefore = entriesSet.length;
      var entriesSetClone = Set.from(entriesSet);

      entriesSetClone.forEach((entryName) {
        var depsForEntry = allEntriesMap[entryName];
        if (depsForEntry != null && depsForEntry.isNotEmpty) {
          depsForEntry.forEach((dependentName, _) {
            entriesSet.add(dependentName);
          });
        }
      });

      if (countBefore != entriesSet.length) {
        addNestedEntries(entriesSet);
      }
    }

    // ignore: omit_local_variable_types
    Map<String, Set<String>> dependencyGraphFlat = {};

    allEntries.forEach((entry, dependencies) {
      var entriesSet = <String>{};
      if (dependencies.isNotEmpty) {
        dependencies.forEach((dependentName, _) {
          entriesSet.add(dependentName);
        });
      }
      addNestedEntries(entriesSet);
      dependencyGraphFlat[entry.name] = entriesSet;
    });

    _dependencyGraph = dependencyGraphFlat;
    return dependencyGraphFlat;
  }

  /// Execute a command in the root of this workspace.
  Future<void> exec(List<String> execArgs, {bool silent = true}) async {
    final execProcess = await Process.start(execArgs[0], execArgs.sublist(1),
        workingDirectory: _path,
        runInShell: true,
        includeParentEnvironment: true,
        environment: {
          'MELOS_ROOT_PATH': currentWorkspace.path,
        });

    if (!silent) {
      var stdoutSub;
      var stderrSub;

      final stdoutStream = execProcess.stdout;
      final stderrStream = execProcess.stderr;
      var completeFuture = Completer();

      stdoutSub =
          stdoutStream.listen(stdout.add, onDone: completeFuture.complete);
      stderrSub = stderrStream.listen(stderr.add);

      await completeFuture.future;
      await stdoutSub.cancel();
      await stderrSub.cancel();
      logger.stdout('\n');
    } else {
      await execProcess.exitCode;
    }
  }

  void linkPackages() {
    packages.forEach((MelosPackage package) {
      PackagesPubFile.fromWorkspacePackage(this, package).write();
      FlutterPluginsPubFile.fromWorkspacePackage(this, package).write();
      PubspecLockPubFile.fromWorkspacePackage(this, package).write();
      PackageConfigPubFile.fromWorkspacePackage(this, package).write();
    });
  }

  void clean() {
    // clean workspace
    PackagesPubFile.fromDirectory(path).delete();
    FlutterPluginsPubFile.fromDirectory(path).delete();
    PubspecLockPubFile.fromDirectory(path).delete();
    PackageConfigPubFile.fromDirectory(path).delete();

    // clean all packages
    packages.forEach((MelosPackage package) {
      PackagesPubFile.fromDirectory(package.path).delete();
      FlutterPluginsPubFile.fromDirectory(package.path).delete();
      PubspecLockPubFile.fromDirectory(package.path).delete();
      PackageConfigPubFile.fromDirectory(package.path).delete();
    });
  }
}
