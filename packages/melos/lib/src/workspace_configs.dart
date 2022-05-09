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

import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'common/git_repository.dart';
import 'common/glob.dart';
import 'common/platform.dart';
import 'common/utils.dart';
import 'common/validation.dart';
import 'scripts.dart';

/// IDE-specific configurations.
@immutable
class IDEConfigs {
  const IDEConfigs({this.intelliJ = IntelliJConfig.empty});

  factory IDEConfigs.fromYaml(Map<Object?, Object?> yaml) {
    return IDEConfigs(
      intelliJ: yaml.containsKey('intellij')
          ? IntelliJConfig.fromYaml(yaml['intellij'])
          : IntelliJConfig.empty,
    );
  }

  static const empty = IDEConfigs();

  final IntelliJConfig intelliJ;

  Map<String, Object?> toJson() {
    return {
      'intellij': intelliJ.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is IDEConfigs &&
      runtimeType == other.runtimeType &&
      other.intelliJ == intelliJ;

  @override
  int get hashCode => runtimeType.hashCode ^ intelliJ.hashCode;

  @override
  String toString() {
    return '''
IDEConfigs(
  intelliJ: ${intelliJ.toString().indent('  ')},
)''';
  }
}

/// IntelliJ-specific configurations
@immutable
class IntelliJConfig {
  const IntelliJConfig({this.enabled = true});

  factory IntelliJConfig.fromYaml(Object? yaml) {
    // TODO support more granular configuration than just a boolean

    final enabled = assertIsA<bool>(
      value: yaml,
      key: 'intellij',
      path: 'ide',
    );

    return IntelliJConfig(enabled: enabled);
  }

  static const empty = IntelliJConfig();

  final bool enabled;

  Object? toJson() {
    return enabled;
  }

  @override
  bool operator ==(Object other) =>
      other is IntelliJConfig &&
      runtimeType == other.runtimeType &&
      other.enabled == enabled;

  @override
  int get hashCode => runtimeType.hashCode ^ enabled.hashCode;

  @override
  String toString() {
    return '''
IntelliJConfig(
  enabled: $enabled,
)
''';
  }
}

/// Melos command-specific configurations.
@immutable
class CommandConfigs {
  const CommandConfigs({
    this.bootstrap = BootstrapCommandConfigs.empty,
    this.version = VersionCommandConfigs.empty,
  });

  factory CommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final bootstrapMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'bootstrap',
      map: yaml,
      path: 'command',
    );

    final versionMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'version',
      map: yaml,
      path: 'command',
    );

    return CommandConfigs(
      bootstrap: BootstrapCommandConfigs.fromYaml(bootstrapMap ?? {}),
      version: VersionCommandConfigs.fromYaml(versionMap ?? {}),
    );
  }

  static const CommandConfigs empty = CommandConfigs();

  final BootstrapCommandConfigs bootstrap;
  final VersionCommandConfigs version;

  Map<String, Object?> toJson() {
    return {
      'bootstrap': bootstrap.toJson(),
      'version': version.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CommandConfigs &&
      runtimeType == other.runtimeType &&
      other.bootstrap == bootstrap &&
      other.version == version;

  @override
  int get hashCode =>
      runtimeType.hashCode ^ bootstrap.hashCode ^ version.hashCode;

  @override
  String toString() {
    return '''
CommandConfigs(
  bootstrap: ${bootstrap.toString().indent('  ')},
  version: ${version.toString().indent('  ')},
)
''';
  }
}

/// Configurations for `melos bootstrap`.
@immutable
class BootstrapCommandConfigs {
  const BootstrapCommandConfigs({
    this.usePubspecOverrides = false,
    this.runPubGetInParallel = true,
  });

  factory BootstrapCommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final usePubspecOverrides = assertKeyIsA<bool?>(
          key: 'usePubspecOverrides',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        false;

    final runPubGetInParallel = assertKeyIsA<bool?>(
          key: 'runPubGetInParallel',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        true;

    return BootstrapCommandConfigs(
      usePubspecOverrides: usePubspecOverrides,
      runPubGetInParallel: runPubGetInParallel,
    );
  }

  static const BootstrapCommandConfigs empty = BootstrapCommandConfigs();

  /// Whether to use `pubspec_overrides.yaml` for overriding workspace
  /// dependencies during development.
  final bool usePubspecOverrides;

  /// Whether to run `pub get` in parallel during bootstrapping.
  ///
  /// The default is `true`.
  final bool runPubGetInParallel;

  Map<String, Object?> toJson() {
    return {
      'usePubspecOverrides': usePubspecOverrides,
      'runPubGetInParallel': runPubGetInParallel,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BootstrapCommandConfigs &&
      runtimeType == other.runtimeType &&
      other.usePubspecOverrides == usePubspecOverrides &&
      other.runPubGetInParallel == runPubGetInParallel;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      usePubspecOverrides.hashCode ^
      runPubGetInParallel.hashCode;

  @override
  String toString() {
    return '''
BootstrapCommandConfigs(
  usePubspecOverrides: $usePubspecOverrides,
  runPubGetInParallel: $runPubGetInParallel,
)''';
  }
}

/// Configurations for `melos version`.
@immutable
class VersionCommandConfigs {
  const VersionCommandConfigs({
    this.message,
    this.linkToCommits,
    this.branch,
    this.workspaceChangelog = false,
    this.updateGitTagRefs = false,
  });

  factory VersionCommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final message = assertKeyIsA<String?>(
      key: 'message',
      map: yaml,
      path: 'command/version',
    );
    final linkToCommits = assertKeyIsA<bool?>(
      key: 'linkToCommits',
      map: yaml,
      path: 'command/version',
    );
    final branch = assertKeyIsA<String?>(
      key: 'branch',
      map: yaml,
      path: 'command/version',
    );

    final workspaceChangelog = assertKeyIsA<bool?>(
      key: 'workspaceChangelog',
      map: yaml,
      path: 'command/version',
    );

    final updateGitTagRefs = assertKeyIsA<bool?>(
      key: 'updateGitTagRefs',
      map: yaml,
      path: 'command/version',
    );

    return VersionCommandConfigs(
      branch: branch,
      linkToCommits: linkToCommits,
      message: message,
      workspaceChangelog: workspaceChangelog ?? false,
      updateGitTagRefs: updateGitTagRefs ?? false,
    );
  }

  static const VersionCommandConfigs empty = VersionCommandConfigs();

  /// A custom header for the generated CHANGELOG.md.
  final String? message;

  /// Whether to add links to commits in the generated CHANGELOG.md.
  final bool? linkToCommits;

  /// Whether to also generate a CHANGELOG.md for the entire workspace at the root.
  final bool workspaceChangelog;

  /// Whether to also update pubspec with git referenced packages.
  final bool updateGitTagRefs;

  /// If specified, prevents `melos version` from being used inside branches
  /// other than the one specified.
  final String? branch;

  Map<String, Object?> toJson() {
    return {
      if (message != null) 'message': message,
      if (linkToCommits != null) 'linkToCommits': linkToCommits,
      if (branch != null) 'branch': branch,
      'workspaceChangelog': workspaceChangelog,
      'updateGitTagRefs': updateGitTagRefs,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is VersionCommandConfigs &&
      runtimeType == other.runtimeType &&
      other.message == message &&
      other.linkToCommits == linkToCommits &&
      other.workspaceChangelog == workspaceChangelog &&
      other.updateGitTagRefs == updateGitTagRefs &&
      other.branch == branch;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      message.hashCode ^
      linkToCommits.hashCode ^
      workspaceChangelog.hashCode ^
      updateGitTagRefs.hashCode ^
      branch.hashCode;

  @override
  String toString() {
    return '''
VersionCommandConfigs(
  message: $message,
  linkToCommits: $linkToCommits,
  workspaceChangelog: $workspaceChangelog,
  updateGitTagRefs: $updateGitTagRefs,
  branch: $branch,
)''';
  }
}

@immutable
class MelosWorkspaceConfig {
  MelosWorkspaceConfig({
    required this.path,
    required this.name,
    this.sdkPath,
    this.repository,
    required this.packages,
    this.ignore = const [],
    this.scripts = Scripts.empty,
    this.ide = IDEConfigs.empty,
    this.commands = CommandConfigs.empty,
  }) {
    _validate();
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

    HostedGitRepository? repository;
    final repositoryUrlString =
        assertKeyIsA<String?>(key: 'repository', map: yaml);
    if (repositoryUrlString != null) {
      Uri repositoryUrl;
      try {
        repositoryUrl = Uri.parse(repositoryUrlString);
      } on FormatException catch (e) {
        throw MelosConfigException(
          'The repository URL $repositoryUrlString is not a valid URL:\n $e',
        );
      }

      try {
        repository = parseHostedGitRepositoryUrl(repositoryUrl);
      } on FormatException catch (e) {
        throw MelosConfigException(e.toString());
      }
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

    final sdkPath = assertKeyIsA<String?>(
      key: 'sdkPath',
      map: yaml,
    );

    return MelosWorkspaceConfig(
      path: path,
      name: name,
      repository: repository,
      sdkPath: sdkPath,
      packages: packages
          .map((package) => createGlob(package, currentDirectoryPath: path))
          .toList(),
      ignore: ignore
          .map((ignore) => createGlob(ignore, currentDirectoryPath: path))
          .toList(),
      scripts: scriptsMap == null
          ? Scripts.empty
          : Scripts.fromYaml(scriptsMap, workspacePath: path),
      ide: ideMap == null ? IDEConfigs.empty : IDEConfigs.fromYaml(ideMap),
      commands: commandMap == null
          ? CommandConfigs.empty
          : CommandConfigs.fromYaml(commandMap),
    );
  }

  MelosWorkspaceConfig.fallback({
    required String path,
    bool usePubspecOverrides = false,
  }) : this(
          name: 'Melos',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          path: currentPlatform.isWindows
              ? windows.normalize(path).replaceAll(r'\', r'\\')
              : path,
          commands: usePubspecOverrides
              ? const CommandConfigs(
                  bootstrap: BootstrapCommandConfigs(
                    usePubspecOverrides: true,
                  ),
                )
              : CommandConfigs.empty,
        );

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
  static Future<MelosWorkspaceConfig> fromDirectory(
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
        return MelosWorkspaceConfig.fallback(path: directory.path)
          ..validatePhysicalWorkspace();
      }

      throw MelosConfigException(
        '''
Your current directory does not appear to be a valid Melos workspace.

You must have one of the following to be a valid Melos workspace:
  - a "melos.yaml" file in the root with a "packages" option defined
  - a "packages" directory
''',
      );
    }

    final melosYamlPath = melosYamlPathForDirectory(melosWorkspaceDirectory);
    final yamlContents = await loadYamlFile(melosYamlPath);

    if (yamlContents == null) {
      throw MelosConfigException('Failed to parse the melos.yaml file');
    }

    return MelosWorkspaceConfig.fromYaml(
      yamlContents,
      path: melosWorkspaceDirectory.path,
    )..validatePhysicalWorkspace();
  }

  /// The absolute path to the workspace folder.
  final String path;

  /// The name of the melos workspace – used by IDE documentation.
  final String name;

  /// The hosted git repository which contains the workspace.
  final HostedGitRepository? repository;

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

  /// Path to the Dart/Flutter SDK that should be used, unless overridden though
  /// the command line option or the environment variable.
  final String? sdkPath;

  /// Validates this workspace configuration for consistency.
  void _validate() {
    final workspaceDir = Directory(path);
    if (!workspaceDir.isAbsolute) {
      throw MelosConfigException('path must be an absolute path but got $path');
    }

    final linkToCommits = commands.version.linkToCommits;
    if (linkToCommits != null && linkToCommits == true && repository == null) {
      throw MelosConfigException(
        'repository must be specified if commands/version/linkToCommits is true',
      );
    }
  }

  /// Validates the physical workspace on the file system.
  void validatePhysicalWorkspace() {
    final workspaceDir = Directory(path);
    if (!workspaceDir.existsSync()) {
      throw MelosConfigException(
        'The path $path does not point to a directory',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MelosWorkspaceConfig &&
      runtimeType == other.runtimeType &&
      other.path == path &&
      other.name == name &&
      other.repository == repository &&
      const DeepCollectionEquality().equals(other.packages, packages) &&
      const DeepCollectionEquality().equals(other.ignore, ignore) &&
      other.scripts == scripts &&
      other.ide == ide &&
      other.commands == commands;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      path.hashCode ^
      name.hashCode ^
      repository.hashCode ^
      const DeepCollectionEquality().hash(packages) &
          const DeepCollectionEquality().hash(ignore) ^
      scripts.hashCode ^
      ide.hashCode ^
      commands.hashCode;

  Map<Object?, Object> toJson() {
    return {
      'name': name,
      'path': path,
      if (repository != null) 'repository': repository!,
      'packages': packages.map((p) => p.toString()).toList(),
      if (ignore.isNotEmpty) 'ignore': ignore.map((p) => p.toString()).toList(),
      if (scripts.isNotEmpty) 'scripts': scripts.toJson(),
      'ide': ide.toJson(),
      'command': commands.toJson(),
    };
  }

  @override
  String toString() {
    return '''
MelosWorkspaceConfig(
  path: $path,
  name: $name,
  repository: $repository,
  packages: $packages,
  ignore: $ignore,
  scripts: ${scripts.toString().indent('  ')},
  ide: ${ide.toString().indent('  ')},
  commands: ${commands.toString().indent('  ')},
)''';
  }
}
