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

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'common/environment_variable_key.dart';
import 'common/intellij_project.dart';
import 'common/io.dart';
import 'common/platform.dart';
import 'common/utils.dart' as utils;
import 'common/validation.dart';
import 'global_options.dart';
import 'logging.dart';
import 'package.dart';
import 'workspace_configs.dart';

class IdeWorkspace {
  IdeWorkspace._(this._workspace);

  final MelosWorkspace _workspace;

  late final IntellijProject intelliJ =
      IntellijProject.fromWorkspace(_workspace);
}

/// A representation of a workspace. This includes its packages, configuration
/// such as scripts and more.
class MelosWorkspace {
  MelosWorkspace({
    required this.name,
    required this.path,
    required this.config,
    required this.allPackages,
    required this.filteredPackages,
    required this.dependencyOverridePackages,
    required this.sdkPath,
    required this.logger,
  });

  /// Build a [MelosWorkspace] from a workspace configuration.
  static Future<MelosWorkspace> fromConfig(
    MelosWorkspaceConfig workspaceConfig, {
    GlobalOptions? global,
    PackageFilters? packageFilters,
    required MelosLogger logger,
  }) async {
    final allPackages = await PackageMap.resolvePackages(
      workspacePath: workspaceConfig.path,
      packages: workspaceConfig.packages,
      ignore: workspaceConfig.ignore,
      logger: logger,
    );
    final dependencyOverridePackages = await PackageMap.resolvePackages(
      workspacePath: workspaceConfig.path,
      packages: workspaceConfig.commands.bootstrap.dependencyOverridePaths,
      ignore: const [],
      logger: logger,
    );

    final filteredPackages = await allPackages.applyFilters(packageFilters);

    return MelosWorkspace(
      name: workspaceConfig.name,
      path: workspaceConfig.path,
      config: workspaceConfig,
      allPackages: allPackages,
      logger: logger,
      filteredPackages: filteredPackages,
      dependencyOverridePackages: dependencyOverridePackages,
      sdkPath: resolveSdkPath(
        configSdkPath: workspaceConfig.sdkPath,
        envSdkPath:
            currentPlatform.environment[EnvironmentVariableKey.melosSdkPath],
        commandSdkPath: global?.sdkPath,
        workspacePath: workspaceConfig.path,
      ),
    );
  }

  final MelosLogger logger;

  /// An optional name as defined in "melos.yaml". This name is used for logging
  /// purposes and also used when generating certain IDE files.
  final String name;

  /// Full file path to the location of this workspace.
  final String path;

  /// Configuration as defined in the "melos.yaml" file if it exists.
  final MelosWorkspaceConfig config;

  /// All packages managed in this Melos workspace.
  ///
  /// Packages specified in [MelosWorkspaceConfig.packages] are included,
  /// except for those specified in [MelosWorkspaceConfig.ignore].
  final PackageMap allPackages;

  /// The packages in this Melos workspace after applying filters.
  ///
  /// Filters are typically specified on the command line.
  final PackageMap filteredPackages;

  /// The packages specified in
  /// [BootstrapCommandConfigs.dependencyOverridePaths].
  final PackageMap dependencyOverridePackages;

  late final IdeWorkspace ide = IdeWorkspace._(this);

  /// Returns true if this workspace contains ANY Flutter package.
  late final bool isFlutterWorkspace =
      allPackages.values.any((package) => package.isFlutterPackage);

  /// Path to the Dart/Flutter SDK, if specified by the user.
  final String? sdkPath;

  /// Returns the path to a [tool] from the Dart/Flutter SDK.
  ///
  /// If no [sdkPath] is specified, this will return the name of the tool
  /// as is so that it can be used as an executable from
  /// [EnvironmentVariableKey.path].
  String sdkTool(String tool) {
    final sdkPath = this.sdkPath;
    if (sdkPath != null) {
      return p.join(sdkPath, 'bin', tool);
    }
    return tool;
  }

  /// [EnvironmentVariableKey.path] environment variable for child processes
  /// launched in this workspace.
  ///
  /// Is `null` if the [EnvironmentVariableKey.path] for child processes is the
  /// same as the [EnvironmentVariableKey.path] for the current process.
  late final String? childProcessPath = sdkPath == null
      ? null
      : utils.addToPathEnvVar(
          directory: p.join(sdkPath!, 'bin'),
          currentPath:
              currentPlatform.environment[EnvironmentVariableKey.path]!,
          // We prepend the path to the bin directory in the Dart/Flutter SDK
          // because we want to shadow any system wide SDK.
          prepend: true,
        );

  /// Validates this workspace against the environment.
  ///
  /// By making this a separate method we can create workspaces for testing
  /// which are not strictly valid.
  void validate() {
    if (sdkPath != null) {
      final dartTool = sdkTool('dart');
      if (!fileExists(dartTool)) {
        throw MelosConfigException(
          'SDK path is not valid. Could not find dart tool at $dartTool',
        );
      }
      if (isFlutterWorkspace) {
        final flutterTool = sdkTool('flutter');
        if (!fileExists(flutterTool)) {
          throw MelosConfigException(
            'SDK path is not valid. Could not find flutter tool at $dartTool',
          );
        }
      }
    }
  }

  /// Execute a command in the root of this workspace.
  Future<int> exec(List<String> execArgs, {bool onlyOutputOnError = false}) {
    final environment = {
      EnvironmentVariableKey.melosRootPath: path,
      if (sdkPath != null) EnvironmentVariableKey.melosSdkPath: sdkPath!,
      if (childProcessPath != null)
        EnvironmentVariableKey.path: childProcessPath!,
    };

    return utils.startCommand(
      execArgs,
      logger: logger,
      environment: environment,
      workingDirectory: path,
      onlyOutputOnError: onlyOutputOnError,
    );
  }
}

/// Takes the raw SDK paths from the workspace config file, the environment
/// variable and the command line and resolves the final path.
///
/// The path provided through the command line takes precedence over the path
/// from the config file.
///
/// Relative paths are resolved relative to the workspace path.
@visibleForTesting
String? resolveSdkPath({
  required String? configSdkPath,
  required String? envSdkPath,
  required String? commandSdkPath,
  required String workspacePath,
}) {
  var sdkPath = commandSdkPath ?? envSdkPath ?? configSdkPath;
  if (sdkPath == utils.autoSdkPathOptionValue) {
    return null;
  }

  /// If the sdk path is a relative one, prepend the workspace path
  /// to make it a valid full absolute path now.
  if (sdkPath != null && p.isRelative(sdkPath)) {
    sdkPath = p.join(workspacePath, sdkPath);
  }

  return sdkPath;
}
