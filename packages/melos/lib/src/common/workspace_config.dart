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
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import 'glob.dart';
import 'utils.dart';
import 'validation.dart';
import 'workspace_command_config.dart';
import 'workspace_scripts.dart';

class PackageFilter {
  const PackageFilter({
    this.scope = const [],
    this.ignore = const [],
    this.dirExists = const [],
    this.fileExists = const [],
    this.dependsOn = const [],
    this.noDependsOn = const [],
    this.updatedSince,
    this.privatePackages,
    this.published,
    this.nullSafe,
    this.flutter,
  });

  factory PackageFilter.fromYaml(
    Map<Object?, Object?> yaml, {
    required String scriptName,
  }) {
    final packagePath = 'scripts/$scriptName/select-package';

    final scope = assertListOrString(
      key: filterOptionScope,
      map: yaml,
      path: packagePath,
    );
    final ignore = assertListOrString(
      key: filterOptionIgnore,
      map: yaml,
      path: packagePath,
    );
    final dirExists = assertListOrString(
      key: filterOptionDirExists,
      map: yaml,
      path: packagePath,
    );
    final fileExists = assertListOrString(
      key: filterOptionFileExists,
      map: yaml,
      path: packagePath,
    );
    final dependsOn = assertListOrString(
      key: filterOptionDependsOn,
      map: yaml,
      path: packagePath,
    );
    final noDependsOn = assertListOrString(
      key: filterOptionNoDependsOn,
      map: yaml,
      path: packagePath,
    );

    final updatedSince = assertIsA<String?>(
      value: yaml[filterOptionSince],
      key: filterOptionSince,
      path: packagePath,
    );

    final privatePackages = assertIsA<bool?>(
      value: yaml[filterOptionNoPrivate],
      key: filterOptionNoPrivate,
      path: packagePath,
    );
    final published = assertIsA<bool?>(
      value: yaml[filterOptionPublished],
      key: filterOptionPublished,
      path: packagePath,
    );
    final nullSafe = assertIsA<bool?>(
      value: yaml[filterOptionNullsafety],
      key: filterOptionNullsafety,
      path: packagePath,
    );
    final flutter = assertIsA<bool?>(
      value: yaml[filterOptionFlutter],
      key: filterOptionFlutter,
      path: packagePath,
    );

    return PackageFilter(
      scope: scope,
      ignore: ignore,
      dirExists: dirExists,
      fileExists: fileExists,
      dependsOn: dependsOn,
      noDependsOn: noDependsOn,
      updatedSince: updatedSince,
      privatePackages: privatePackages,
      published: published,
      nullSafe: nullSafe,
      flutter: flutter,
    );
  }

  /// Patterns for filtering packages by name.
  final List<Pattern> scope;

  /// Patterns for excluding packages by name.
  final List<Pattern> ignore;

  /// Include a package only if a given directory exists.
  final List<String> dirExists;

  /// Include a package only if a given file exists.
  final List<String> fileExists;

  /// Include only packages that depend on a specific package.
  final List<String> dependsOn;

  /// Include only packages that do not depend on a specific package.
  final List<String> noDependsOn;

  /// Filter package based on whether they received changed since a specific git commit/tag ID.
  final String? updatedSince;

  /// Include/Exlude packages with `publish_to: none`.
  final bool? privatePackages;

  /// Include/exlude packages that are up-to-date on pub.dev
  final bool? published;

  /// Include/exclude packages that are null-safe.
  final bool? nullSafe;

  /// Include/exclude packages that depends on Flutter.
  final bool? flutter;
}

/// Scripts to be executed before/after a melos command.
class LifecycleHook {
  LifecycleHook._({required this.pre, required this.post});

  /// A script to execute before the melos command starts.
  final Script? pre;

  /// A script to execute before the melos command completed.
  final Script? post;
}

class Scripts extends MapView<String, Script> {
  const Scripts(Map<String, Script> map) : super(map);

  factory Scripts.fromYaml(Map<Object?, Object?> yaml) {
    final scripts = yaml.map<String, Script>((key, value) {
      final name = assertIsA<String>(value: key, key: 'scripts');

      if (value == null) {
        throw MelosConfigException('The script $name has no value');
      }

      final script = Script.fromYaml(value, name: name);

      return MapEntry(name, script);
    });

    return Scripts(UnmodifiableMapView(scripts));
  }

  static const Scripts empty = Scripts({});

  LifecycleHook get bootstrap => _lifecycleHookFor('bootstrap');
  LifecycleHook get version => _lifecycleHookFor('version');
  LifecycleHook get clean => _lifecycleHookFor('clean');

  Set<Script> lifecycles() {
    return {
      for (final lifecycle in [bootstrap, version, clean]) ...[
        if (lifecycle.pre != null) lifecycle.pre!,
        if (lifecycle.post != null) lifecycle.post!,
      ],
    };
  }

  LifecycleHook _lifecycleHookFor(String name) {
    return LifecycleHook._(
      pre: this[name],
      post: this['post$name'],
    );
  }
}

class Script {
  Script({
    required this.name,
    required this.run,
    required this.description,
    required this.env,
    required this.packageFilter,
  });

  factory Script.fromYaml(Object yaml, {required String name}) {
    final scriptPath = 'scripts/$name';
    String run;
    String? description;
    var env = <String, String>{};
    PackageFilter? packageFilter;

    if (yaml is String) {
      run = yaml;
    } else if (yaml is Map<Object?, Object?>) {
      run = assertKeyIsA<String>(
        key: 'run',
        map: yaml,
        path: scriptPath,
      );
      description = assertKeyIsA<String?>(
        key: 'description',
        map: yaml,
        path: scriptPath,
      );
      final envMap = assertKeyIsA<Map<Object?, Object?>?>(
        key: 'env',
        map: yaml,
        path: scriptPath,
      );

      env = <String, String>{
        if (envMap != null)
          for (final entry in envMap.entries)
            assertIsA<String>(
              value: entry.key,
              key: 'env',
              path: scriptPath,
            ): assertIsA<String>(
              value: entry.value,
              key: entry.key,
              path: '$scriptPath/env',
            ),
      };

      final packageFilterMap = assertKeyIsA<Map<Object?, Object?>?>(
        key: 'select-package',
        map: yaml,
        path: scriptPath,
      );

      packageFilter = packageFilterMap == null
          ? null
          : PackageFilter.fromYaml(packageFilterMap, scriptName: name);
    } else {
      throw MelosConfigException('Unsupported value for script $name');
    }

    return Script(
      name: name,
      run: run,
      description: description,
      env: env,
      packageFilter: packageFilter,
    );
  }

  /// A unique identifier for the script
  final String name;

  /// The command to execute
  final String run;

  /// A short description, shown when using `melos run` with no argument.
  final String? description;

  /// Environment variables that will be passed to[run].
  final Map<String, String> env;

  /// If the [run] command is a melos command, allows filtering packages
  /// that will execute the command.
  final PackageFilter? packageFilter;
}

/// IDE-specific configurations.
class IDEConfigs {
  const IDEConfigs({required this.intelliJ});

  factory IDEConfigs.fromYaml(Map<Object?, Object?> yaml) {
    return IDEConfigs(intelliJ: IntelliJConfig.fromYaml(yaml['intellij']));
  }

  static const empty = IDEConfigs(intelliJ: IntelliJConfig(enabled: true));

  final IntelliJConfig intelliJ;
}

/// IntelliJ-specific configurations
class IntelliJConfig {
  const IntelliJConfig({required this.enabled});

  factory IntelliJConfig.fromYaml(Object? yaml) {
    // TODO support more granular configuration than just a boolean

    final enabled = assertIsA<bool>(
      value: yaml,
      key: 'intellij',
      path: 'ide',
    );

    return IntelliJConfig(enabled: enabled);
  }

  final bool enabled;
}

/// Melos command-specific configurations.
class CommandConfigs {
  const CommandConfigs({required this.version});

  factory CommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final versionMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'version',
      map: yaml,
      path: 'commands',
    );

    return CommandConfigs(
      version: VersionCommandConfigs.fromYaml(versionMap ?? {}),
    );
  }

  static const CommandConfigs empty = CommandConfigs(
    version: VersionCommandConfigs.empty,
  );

  final VersionCommandConfigs version;
}

/// Configurations for `melos version`.
class VersionCommandConfigs {
  const VersionCommandConfigs({this.message, this.branch});

  factory VersionCommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final message = assertKeyIsA<String?>(
      key: 'message',
      map: yaml,
      path: 'command/version',
    );
    final branch = assertKeyIsA<String?>(
      key: 'branch',
      map: yaml,
      path: 'command/version',
    );

    return VersionCommandConfigs(
      branch: branch,
      message: message,
    );
  }

  static const VersionCommandConfigs empty = VersionCommandConfigs();

  /// A custom header for the generated CHANGELOG.md.
  final String? message;

  /// If specified, prevents `melos version` from being used inside branches
  /// other than the one specified.
  final String? branch;
}

class MelosWorkspaceConfig {
  MelosWorkspaceConfig({
    required this.path,
    required this.name,
    required this.packages,
    this.ignore = const [],
    this.scripts = Scripts.empty,
    this.ide = IDEConfigs.empty,
    this.commands = CommandConfigs.empty,
  }) {
    if (!FileSystemEntity.isDirectorySync(path)) {
      throw MelosConfigException(
        'The path $path does not point to a directory',
      );
    }
    final workspaceDir = Directory(path);
    if (!workspaceDir.isAbsolute) {
      throw MelosConfigException('path must be an absolute path but got $path');
    }
  }

  factory MelosWorkspaceConfig.fromYaml(
    Map<Object?, Object?> yaml, {
    required String path,
  }) {
    final name = assertKeyIsA<String>(key: 'name', map: yaml);
    final isValidDartPackageNameRegExp =
        RegExp(r'^[a-z][a-z\d_-]*$', caseSensitive: false);
    if (!isValidDartPackageNameRegExp.hasMatch(name)) {
      throw MelosConfigException(
        'The name $name is not a valid dart package name',
      );
    }

    final packages = assertListIsA<String>(
      key: 'packages',
      map: yaml,
      isRequired: true,
      assertItemIsA: (index, value) => assertIsA<String>(
        value: value,
        index: index,
        path: 'packages',
      ),
    );
    final ignore = assertListIsA<String>(
      key: 'ignore',
      map: yaml,
      isRequired: false,
      assertItemIsA: (index, value) => assertIsA<String>(
        value: value,
        index: index,
        path: 'ignore',
      ),
    );

    final scriptsMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'scripts',
      map: yaml,
    );

    final ideMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'ide',
      map: yaml,
    );

    final commandMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'command',
      map: yaml,
    );

    return MelosWorkspaceConfig(
      path: path,
      name: name,
      packages: packages
          .map((package) => createGlob(package, currentDirectoryPath: path))
          .toList(),
      ignore: ignore
          .map((ignore) => createGlob(ignore, currentDirectoryPath: path))
          .toList(),
      scripts:
          scriptsMap == null ? Scripts.empty : Scripts.fromYaml(scriptsMap),
      ide: ideMap == null ? IDEConfigs.empty : IDEConfigs.fromYaml(ideMap),
      commands: commandMap == null
          ? CommandConfigs.empty
          : CommandConfigs.fromYaml(commandMap),
    );
  }

  MelosWorkspaceConfig.fallback({required String path})
      : this(
          name: 'Melos',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          path: path,
        );

  // /// Constructs a workspace config from a [YamlMap] representation of
  // /// `melos.yaml`.
  // factory MelosWorkspaceConfig.fromYaml(YamlMap yamlMap) {
  //   final melosYamlPath = yamlMap.span.sourceUrl?.toFilePath();
  //   assert(
  //     melosYamlPath != null,
  //     'Config yaml does not have an associated path. Was it loaded from disk?',
  //   );

  //   return MelosWorkspaceConfig.fromYaml(yamlMap, path: melosYamlPath!);

  //   // return MelosWorkspaceConfig._(
  //   //   yamlMap['name'] as String,
  //   //   dirname(melosYamlPath),
  //   //   yamlMap,
  //   // );
  // }

  static Directory? _searchForAncestorDirectoryWithMelosYaml(Directory from) {
    for (var testedDirectory = from;
        testedDirectory.path != testedDirectory.parent.path;
        testedDirectory = testedDirectory.parent) {
      if (isWorkspaceDirectory(testedDirectory)) {
        return testedDirectory;
      }
    }
    return null;
  }

  /// Creates a new configuration from a [Directory].
  ///
  /// If no `melos.yaml` is found, but [Directory] contains a `packages/`
  /// sub-directory, a configuration for those packages will be created.
  static Future<MelosWorkspaceConfig?> fromDirectory(
    Directory directory,
  ) async {
    final melosWorkspaceDirectory =
        _searchForAncestorDirectoryWithMelosYaml(directory);

    if (melosWorkspaceDirectory == null) {
      // Allow melos to use a project without a `melos.yaml` file if a `packages`
      // directory exists.
      final packagesDirectory =
          Directory(joinAll([directory.path, 'packages']));

      if (packagesDirectory.existsSync()) {
        return MelosWorkspaceConfig.fallback(path: directory.path);
      }

      return null;
    }

    final melosYamlPath = melosYamlPathForDirectory(melosWorkspaceDirectory);
    final yamlContents = await loadYamlFile(melosYamlPath);
    if (yamlContents == null) {
      return null;
    }

    return MelosWorkspaceConfig.fromYaml(yamlContents, path: melosYamlPath);
  }

  /// The absolute path to the workspace folder.
  final String path;

  /// The name of the melos workspace – used by IDE documentation.
  final String name;

  /// A list of paths to packages that are included in the melos workspace.
  final List<Glob> packages;

  /// A list of paths to exclude from the melos workspace.
  final List<Glob> ignore;

  /// A list of scripts that can be executed with `melos run` or will be executed
  /// before/after some specific melos commands.
  final Scripts scripts;

  /// IDE-specific configurations.
  ///
  /// This allows connecting the different [scripts] to the IDE or tells melos
  /// to generate the necessary files for mono-repositories to work in the IDE.
  final IDEConfigs ide;

  /// Command-specific configurations.
  ///
  /// This allows customizing the default behavior of melos commands.
  final CommandConfigs commands;
}
