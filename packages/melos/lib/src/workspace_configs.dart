import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import '../melos.dart';
import 'command_configs/command_configs.dart';
import 'common/git_repository.dart';
import 'common/glob.dart';
import 'common/glob_equality.dart';
import 'common/io.dart';
import 'common/utils.dart';
import 'common/validation.dart';
import 'package.dart';

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
  const IntelliJConfig({
    this.enabled = _defaultEnabled,
    this.moduleNamePrefix = _defaultModuleNamePrefix,
  });

  factory IntelliJConfig.fromYaml(Object? yaml) {
    if (yaml is Map<Object?, Object?>) {
      final moduleNamePrefix = yaml.containsKey('moduleNamePrefix')
          ? assertKeyIsA<String>(
              map: yaml,
              key: 'moduleNamePrefix',
              path: 'ide/intellij',
            )
          : _defaultModuleNamePrefix;
      final enabled = yaml.containsKey('enabled')
          ? assertKeyIsA<bool>(key: 'enabled', map: yaml, path: 'ide/intellij')
          : _defaultEnabled;
      return IntelliJConfig(
        enabled: enabled,
        moduleNamePrefix: moduleNamePrefix,
      );
    } else {
      final enabled = assertIsA<bool>(
        value: yaml,
        key: 'intellij',
        path: 'ide',
      );
      return IntelliJConfig(enabled: enabled);
    }
  }

  static const empty = IntelliJConfig();
  static const _defaultModuleNamePrefix = 'melos_';
  static const _defaultEnabled = true;

  final bool enabled;

  final String moduleNamePrefix;

  Object? toJson() {
    return {
      'enabled': enabled,
      'moduleNamePrefix': moduleNamePrefix,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is IntelliJConfig &&
      runtimeType == other.runtimeType &&
      other.enabled == enabled &&
      other.moduleNamePrefix == moduleNamePrefix;

  @override
  int get hashCode =>
      runtimeType.hashCode ^ enabled.hashCode ^ moduleNamePrefix.hashCode;

  @override
  String toString() {
    return '''
IntelliJConfig(
  enabled: $enabled,
  moduleNamePrefix: $moduleNamePrefix,
)
''';
  }
}

@immutable
class AggregateChangelogConfig {
  const AggregateChangelogConfig({
    this.isWorkspaceChangelog = false,
    required this.path,
    required this.packageFilters,
    this.description,
  });

  AggregateChangelogConfig.workspace()
      : this(
          isWorkspaceChangelog: true,
          path: 'CHANGELOG.md',
          packageFilters: PackageFilters(),
          description: '''
All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.
''',
        );

  final bool isWorkspaceChangelog;
  final String path;
  final PackageFilters packageFilters;
  final String? description;

  Map<String, Object?> toJson() {
    return {
      'isWorkspaceChangelog': isWorkspaceChangelog,
      'path': path,
      'packageFilters': packageFilters,
      'description': description,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AggregateChangelogConfig &&
      runtimeType == other.runtimeType &&
      other.isWorkspaceChangelog == isWorkspaceChangelog &&
      other.path == path &&
      other.packageFilters == packageFilters &&
      other.description == description;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      isWorkspaceChangelog.hashCode ^
      path.hashCode ^
      packageFilters.hashCode ^
      description.hashCode;

  @override
  String toString() {
    return '''
AggregateChangelogConfig(
  isWorkspaceChangelog: $isWorkspaceChangelog,
  path: $path,
  packageFilters: $packageFilters,
  description: $description,
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
    if (!isValidPubPackageName(name)) {
      throw MelosConfigException(
        'The name $name is not a valid pub package name.',
      );
    }

    HostedGitRepository? repository;
    if (yaml.containsKey('repository')) {
      final repositoryYaml = yaml['repository'];

      if (repositoryYaml is Map<Object?, Object?>) {
        final type = assertKeyIsA<String>(
          key: 'type',
          map: repositoryYaml,
          path: 'repository',
        );
        final origin = assertKeyIsA<String>(
          key: 'origin',
          map: repositoryYaml,
          path: 'repository',
        );
        final owner = assertKeyIsA<String>(
          key: 'owner',
          map: repositoryYaml,
          path: 'repository',
        );
        final name = assertKeyIsA<String>(
          key: 'name',
          map: repositoryYaml,
          path: 'repository',
        );

        try {
          repository = parseHostedGitRepositorySpec(type, origin, owner, name);
        } on FormatException catch (e) {
          throw MelosConfigException(e.toString());
        }
      } else if (repositoryYaml is String) {
        Uri repositoryUrl;
        try {
          repositoryUrl = Uri.parse(repositoryYaml);
        } on FormatException catch (e) {
          throw MelosConfigException(
            'The repository URL $repositoryYaml is not a valid URL:\n $e',
          );
        }

        try {
          repository = parseHostedGitRepositoryUrl(repositoryUrl);
        } on FormatException catch (e) {
          throw MelosConfigException(e.toString());
        }
      } else if (repositoryYaml != null) {
        throw MelosConfigException(
          'The repository value must be a string or repository spec',
        );
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
          : CommandConfigs.fromYaml(
              commandMap,
              workspacePath: path,
              repositoryIsConfigured: repository != null,
            ),
    );
  }

  MelosWorkspaceConfig.empty()
      : this(
          name: 'Melos',
          packages: [],
          path: Directory.current.path,
          commands: CommandConfigs.empty,
        );

  /// Loads the [MelosWorkspaceConfig] for the workspace at [workspaceRoot].
  static Future<MelosWorkspaceConfig> fromWorkspaceRoot(
    Directory workspaceRoot,
  ) async {
    final melosYamlFile = File(melosYamlPathForDirectory(workspaceRoot.path));

    if (!melosYamlFile.existsSync()) {
      throw UnresolvedWorkspace(
        multiLine([
          'Found no melos.yaml file in "${workspaceRoot.path}".',
          '',
          'You must have a ${AnsiStyles.bold('melos.yaml')} file in the root '
              'of your workspace.',
          '',
          'For more information, see: '
              'https://melos.invertase.dev/configuration/overview',
        ]),
      );
    }

    Object? melosYamlContents;
    try {
      melosYamlContents = loadYamlNode(
        await melosYamlFile.readAsString(),
        sourceUrl: melosYamlFile.uri,
      ).toPlainObject();
    } on YamlException catch (error) {
      throw MelosConfigException('Failed to parse melos.yaml:\n$error');
    }

    if (melosYamlContents is! Map<Object?, Object?>) {
      throw MelosConfigException('melos.yaml must contain a YAML map.');
    }

    final melosOverridesYamlFile =
        File(melosOverridesYamlPathForDirectory(workspaceRoot.path));
    if (melosOverridesYamlFile.existsSync()) {
      Object? melosOverridesYamlContents;
      try {
        melosOverridesYamlContents = loadYamlNode(
          await melosOverridesYamlFile.readAsString(),
          sourceUrl: melosOverridesYamlFile.uri,
        ).toPlainObject();
      } on YamlException catch (error) {
        throw MelosConfigException(
          'Failed to parse melos_overrides.yaml:\n$error',
        );
      }

      if (melosOverridesYamlContents is! Map<Object?, Object?>) {
        throw MelosConfigException(
          'melos_overrides.yaml must contain a YAML map.',
        );
      }

      mergeMap(melosYamlContents, melosOverridesYamlContents);
    }

    return MelosWorkspaceConfig.fromYaml(
      melosYamlContents,
      path: workspaceRoot.path,
    )..validatePhysicalWorkspace();
  }

  /// Handles the case where a workspace could not be found in the [current]
  /// or a parent directory by throwing an error with a helpful message.
  static Future<Never> handleWorkspaceNotFound(Directory current) async {
    final legacyWorkspace = await _findMelosYaml(current);
    if (legacyWorkspace != null) {
      throw UnresolvedWorkspace(
        multiLine([
          'Found a melos.yaml file in "${legacyWorkspace.path}" but no local '
              'installation of Melos.',
          '',
          'From version 3.0.0, the ${AnsiStyles.bold('melos')} package must be '
              'installed in a ${AnsiStyles.bold('pubspec.yaml')} file next to '
              'the melos.yaml file.',
          '',
          'For more information on migrating to version 3.0.0, see: '
              'https://melos.invertase.dev/guides/migrations#200-to-300',
          '',
          'To migrate at a later time, ensure you have version 2.9.0 or below '
              'installed: dart pub global activate melos 2.9.0',
        ]),
      );
    }

    throw UnresolvedWorkspace(
      multiLine([
        'Your current directory does not appear to be within a Melos '
            'workspace.',
        '',
        'For setting up a workspace, see: '
            'https://melos.invertase.dev/getting-started#setup',
      ]),
    );
  }

  static Future<Directory?> _findMelosYaml(Directory start) async {
    final melosYamlFile = File(melosYamlPathForDirectory(start.path));
    if (melosYamlFile.existsSync()) {
      return start;
    }

    final parent = start.parent;
    return parent.path == start.path ? null : _findMelosYaml(parent);
  }

  /// The absolute path to the workspace folder.
  final String path;

  /// The name of the melos workspace – used by IDE documentation.
  final String name;

  /// The hosted git repository which contains the workspace.
  final HostedGitRepository? repository;

  /// A list of [Glob]s for paths that should be searched for packages.
  final List<Glob> packages;

  /// A list of [Glob]s for paths that should be excluded from the search for
  /// packages.
  final List<Glob> ignore;

  /// A list of scripts that can be executed with `melos run` or will be
  /// executed before/after some specific melos commands.
  final Scripts scripts;

  /// IDE-specific configurations.
  ///
  /// This allows connecting the different [scripts] to the IDE or tells melos
  /// to generate the necessary files for mono-repositories to work in the IDE.
  final IDEConfigs ide;

  /// Command-specific configurations.
  ///
  /// This allows customizing the default behaviour of melos commands.
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
    if (linkToCommits && repository == null) {
      throw MelosConfigException(
        'repository must be specified if commands/version/linkToCommits is true',
      );
    }

    scripts.validate();
  }

  /// Validates the physical workspace on the file system.
  void validatePhysicalWorkspace() {
    if (!dirExists(path)) {
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
      const DeepCollectionEquality(GlobEquality())
          .equals(other.packages, packages) &&
      const DeepCollectionEquality(GlobEquality())
          .equals(other.ignore, ignore) &&
      other.scripts == scripts &&
      other.ide == ide &&
      other.commands == commands;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      path.hashCode ^
      name.hashCode ^
      repository.hashCode ^
      const DeepCollectionEquality(GlobEquality()).hash(packages) &
          const DeepCollectionEquality(GlobEquality()).hash(ignore) ^
      scripts.hashCode ^
      ide.hashCode ^
      commands.hashCode;

  Map<String, Object> toJson() {
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

/// An exception thrown when a Melos workspace could not be resolved.
class UnresolvedWorkspace implements MelosException {
  UnresolvedWorkspace(this.message);

  final String message;

  @override
  String toString() => message;
}
