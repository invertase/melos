/*
 * Copyright (c) 2020-present Invertase Limited & Contributors
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

import 'dart:async';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart';

import 'common/intellij_project.dart';
import 'common/pub_dependency_list.dart';
import 'common/utils.dart' as utils;
import 'package.dart';
import 'workspace_configs.dart';

class IdeWorkspace {
  IdeWorkspace._(this._workspace);

  final MelosWorkspace _workspace;

  late final IntellijProject intelliJ =
      IntellijProject.fromWorkspace(_workspace);
}

/// A representation of a workspace. This includes it's packages, configuration
/// such as scripts and more.
class MelosWorkspace {
  MelosWorkspace._({
    required this.name,
    required this.path,
    required this.config,
    required this.allPackages,
    required this.filteredPackages,
    this.logger,
  });

  /// Build a [MelosWorkspace] from a workspace configuration.
  static Future<MelosWorkspace> fromConfig(
    MelosWorkspaceConfig workspaceConfig, {
    PackageFilter? filter,
    Logger? logger,
  }) async {
    final allPackages = await PackageMap.resolvePackages(
      workspacePath: workspaceConfig.path,
      packages: workspaceConfig.packages,
      ignore: workspaceConfig.ignore,
      logger: logger,
    );

    final filteredPackages = await allPackages.applyFilter(filter);

    return MelosWorkspace._(
      name: workspaceConfig.name,
      path: workspaceConfig.path,
      config: workspaceConfig,
      allPackages: allPackages,
      logger: logger,
      filteredPackages: filteredPackages,
    );
  }

  final Logger? logger;

  /// An optional name as defined in "melos.yaml". This name is used for logging
  /// purposes and also used when generating certain IDE files.
  final String name;

  /// Full file path to the location of this workspace.
  final String path;

  /// Configuration as defined in the "melos.yaml" file if it exists.
  final MelosWorkspaceConfig config;

  /// All packages according to [MelosWorkspaceConfig].
  ///
  /// Packages filtered by [MelosWorkspaceConfig.ignore] are not included.
  final PackageMap allPackages;

  final PackageMap filteredPackages;

  late final IdeWorkspace ide = IdeWorkspace._(this);

  /// Returns true if this workspace contains ANY Flutter package.
  late final bool isFlutterWorkspace =
      allPackages.values.any((package) => package.isFlutterPackage);

  /// Returns a string path to the 'melos_tool' directory in this workspace.
  /// This directory should be git ignored and is used by Melos for temporary tasks
  /// such as pub install.
  late final String melosToolPath = join(path, '.dart_tool', 'melos_tool');

  /// Execute a command in the root of this workspace.
  Future<int> exec(List<String> execArgs, {bool onlyOutputOnError = false}) {
    final environment = {
      'MELOS_ROOT_PATH': path,
    };

    return utils.startProcess(
      execArgs,
      logger: logger,
      environment: environment,
      workingDirectory: path,
      onlyOutputOnError: onlyOutputOnError,
    );
  }

  /// Execute a command in the melos_tool directory of this workspace.
  Future<int> execInMelosToolPath(
    List<String> execArgs, {
    bool onlyOutputOnError = false,
  }) {
    final environment = {
      'MELOS_ROOT_PATH': path,
    };

    return utils.startProcess(
      execArgs,
      logger: logger,
      environment: environment,
      workingDirectory: melosToolPath,
      onlyOutputOnError: onlyOutputOnError,
    );
  }

  /// Builds a dependency graph of dependencies and their dependents in this workspace.
  Future<Map<String, Set<String>>> getDependencyGraph() async {
    final pubDepsExecArgs = ['--style=list', '--dev'];
    final pubListCommandOutput = await Process.run(
      isFlutterWorkspace
          ? 'flutter'
          : utils.isPubSubcommand()
              ? 'dart'
              : 'pub',
      isFlutterWorkspace
          ? ['pub', 'deps', '--', ...pubDepsExecArgs]
          : [if (utils.isPubSubcommand()) 'pub', 'deps', ...pubDepsExecArgs],
      runInShell: true,
      workingDirectory: melosToolPath,
    );

    final pubDepList =
        PubDependencyList.parse(pubListCommandOutput.stdout as String);
    final allEntries = pubDepList.allEntries;
    final allEntriesMap = allEntries.map((entry, map) {
      return MapEntry(entry.name, map);
    });

    void addNestedEntries(Set<String> entriesSet) {
      final countBefore = entriesSet.length;
      final entriesSetClone = Set<String>.from(entriesSet);
      for (final entryName in entriesSetClone) {
        final depsForEntry = allEntriesMap[entryName];
        if (depsForEntry != null && depsForEntry.isNotEmpty) {
          depsForEntry.forEach((dependentName, _) {
            entriesSet.add(dependentName);
          });
        }
      }
      // We check if the set has grown since we may need gather nested entries
      // from newly discovered dependencies.
      if (countBefore != entriesSet.length) {
        addNestedEntries(entriesSet);
      }
    }

    final dependencyGraphFlat = <String, Set<String>>{};

    allEntries.forEach((entry, dependencies) {
      final entriesSet = <String>{};
      if (dependencies.isNotEmpty) {
        dependencies.forEach((dependentName, _) {
          entriesSet.add(dependentName);
        });
      }
      addNestedEntries(entriesSet);
      dependencyGraphFlat[entry.name] = entriesSet;
    });

    return dependencyGraphFlat;
  }
}
