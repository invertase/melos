import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

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
    this.executeInTerminal = _defaultExecuteInTerminal,
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
      final executeInTerminal = yaml.containsKey('executeInTerminal')
          ? assertKeyIsA<bool>(
              key: 'executeInTerminal',
              map: yaml,
              path: 'ide/intellij',
            )
          : _defaultExecuteInTerminal;
      return IntelliJConfig(
        enabled: enabled,
        moduleNamePrefix: moduleNamePrefix,
        executeInTerminal: executeInTerminal,
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
  static const _defaultExecuteInTerminal = true;

  final bool enabled;

  final String moduleNamePrefix;

  final bool executeInTerminal;

  Object? toJson() {
    return {
      'enabled': enabled,
      'moduleNamePrefix': moduleNamePrefix,
      'executeInTerminal': executeInTerminal,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is IntelliJConfig &&
      runtimeType == other.runtimeType &&
      other.enabled == enabled &&
      other.moduleNamePrefix == moduleNamePrefix &&
      other.executeInTerminal == executeInTerminal;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      enabled.hashCode ^
      moduleNamePrefix.hashCode ^
      executeInTerminal.hashCode;

  @override
  String toString() {
    return '''
IntelliJConfig(
  enabled: $enabled,
  moduleNamePrefix: $moduleNamePrefix,
  executeInTerminal: $executeInTerminal,
)
''';
  }
}

@immutable
class AggregateChangelogConfig {
  const AggregateChangelogConfig({
    required this.path,
    required this.packageFilters,
    this.isWorkspaceChangelog = false,
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
      'packageFilters': packageFilters.toJson(),
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
    required this.packages,
    this.sdkPath,
    this.repository,
    this.categories = const {},
    this.ignore = const [],
    this.scripts = Scripts.empty,
    this.ide = IDEConfigs.empty,
    this.commands = CommandConfigs.empty,
  }) {
    _validate();
  }

  factory MelosWorkspaceConfig.fromYaml(
    Map<Object?, Object?> pubspecYaml, {
    required String path,
  }) {
    final name = assertKeyIsA<String>(key: 'name', map: pubspecYaml);
    if (!isValidPubPackageName(name)) {
      throw MelosConfigException(
        'The name $name is not a valid pub package name.',
      );
    }

    final melosYaml = pubspecYaml['melos'] as Map<Object?, Object?>? ?? {};

    HostedGitRepository? repository;
    if (melosYaml.containsKey('repository')) {
      final repositoryYaml = melosYaml['repository'];

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
        final repositoryName = assertKeyIsA<String>(
          key: 'name',
          map: repositoryYaml,
          path: 'repository',
        );

        try {
          repository = parseHostedGitRepositorySpec(
            type,
            origin,
            owner,
            repositoryName,
          );
        } on FormatException catch (e) {
          throw MelosConfigException(e.toString());
        }
      } else if (repositoryYaml is String) {
        repository = _urlToRepository(repositoryYaml);
      } else if (repositoryYaml != null) {
        throw MelosConfigException(
          'The repository value must be a string or repository spec',
        );
      }
    } else if (pubspecYaml.containsKey('repository')) {
      final repositoryYaml = pubspecYaml['repository'];
      if (repositoryYaml is String) {
        repository = _urlToRepository(repositoryYaml);
      }
    }

    final packages = assertListIsA<String>(
      key: 'workspace',
      map: pubspecYaml,
      isRequired: false,
      assertItemIsA: (index, value) => assertIsA<String>(
        value: value,
        index: index,
        path: 'workspace',
      ),
    );

    final categories = assertMapIsA<String, List<String>>(
      key: 'categories',
      map: melosYaml,
      isRequired: false,
      assertKey: (value) => assertIsA<String>(
        value: value,
      ),
      assertValue: (key, value) => assertListIsA<String>(
        key: key!,
        map: (melosYaml['categories'] ?? {}) as Map<Object?, Object?>,
        isRequired: false,
        assertItemIsA: (index, value) => assertIsA<String>(
          value: value,
          index: index,
        ),
      ),
    );

    final ignore = assertListIsA<String>(
      key: 'ignore',
      map: melosYaml,
      isRequired: false,
      assertItemIsA: (index, value) => assertIsA<String>(
        value: value,
        index: index,
        path: 'ignore',
      ),
    );

    final scriptsMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'scripts',
      map: melosYaml,
    );

    final ideMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'ide',
      map: melosYaml,
    );

    final commandMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'command',
      map: melosYaml,
    );

    final sdkPath = assertKeyIsA<String?>(
      key: 'sdkPath',
      map: melosYaml,
    );

    return MelosWorkspaceConfig(
      path: path,
      name: name,
      repository: repository,
      sdkPath: sdkPath,
      categories: categories.map(
        (key, value) => MapEntry(
          key,
          value.map(Glob.new).toList(),
        ),
      ),
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

  @visibleForTesting
  MelosWorkspaceConfig.emptyWith({
    String? name,
    String? path,
  }) : this(
         name: name ?? 'Melos',
         packages: [],
         path: path ?? Directory.current.path,
         commands: CommandConfigs.empty,
       );

  /// Loads the [MelosWorkspaceConfig] for the workspace at [workspaceRoot].
  static Future<MelosWorkspaceConfig> fromWorkspaceRoot(
    Directory workspaceRoot,
  ) async {
    final rootPubspecFile = File(pubspecPathForDirectory(workspaceRoot.path));

    if (!rootPubspecFile.existsSync()) {
      throw UnresolvedWorkspace(
        multiLine([
          'Found no pubspec.yaml file in "${workspaceRoot.path}".',
          '',
          'You must have a ${AnsiStyles.bold('pubspec.yaml')} file in the root '
              'of your workspace.',
          '',
          'For more information, see: '
              'https://melos.invertase.dev/configuration/overview',
        ]),
      );
    }

    late final Object? rootPubspecContent;
    try {
      rootPubspecContent = loadYamlNode(
        await rootPubspecFile.readAsString(),
        sourceUrl: rootPubspecFile.uri,
      ).toPlainObject();
    } on YamlException catch (error) {
      throw MelosConfigException('Failed to parse root pubspec.yaml:\n$error');
    }

    if (rootPubspecContent is! Map<Object?, Object?>) {
      throw MelosConfigException('pubspec.yaml must contain a valid YAML.');
    }

    if (rootPubspecContent['melos'] is! Map<Object?, Object?>?) {
      throw MelosConfigException(
        'If a melos section is present in the root pubspec.yaml file, it must '
        'be a map.',
      );
    }

    return MelosWorkspaceConfig.fromYaml(
      rootPubspecContent,
      path: workspaceRoot.path,
    );
  }

  /// Handles the case where a workspace could not be found in the [current]
  /// or a parent directory by throwing an error with a helpful message.
  static Future<Never> handleWorkspaceNotFound(Directory current) async {
    final legacyWorkspace = await _findRootPubspec(current);
    if (legacyWorkspace != null) {
      throw UnresolvedWorkspace(
        multiLine([
          'From version 7.0.0, the ${AnsiStyles.bold('melos')} package must be '
              'added as a dev_dependency in the root '
              '${AnsiStyles.bold('pubspec.yaml')} file.',
          '',
          'For more information on migrating to version 7.0.0, see: '
              'https://melos.invertase.dev/guides/migrations#6xx-to-7xx'
              '',
          'To migrate at a later time, ensure you have version 6.3.0 or below '
              'installed: dart pub global activate melos 6.3.0',
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

  static Future<Directory?> _findRootPubspec(Directory start) async {
    final rootPubspecFile = File(pubspecPathForDirectory(start.path));
    if (rootPubspecFile.existsSync()) {
      final pubspec = Pubspec.parse(rootPubspecFile.readAsStringSync());
      if (pubspec.devDependencies.keys.contains('melos')) {
        return start;
      }
    }

    final parent = start.parent;
    return parent.path == start.path ? null : _findRootPubspec(parent);
  }

  static HostedGitRepository _urlToRepository(String repositoryYaml) {
    Uri repositoryUrl;
    try {
      repositoryUrl = Uri.parse(repositoryYaml);
    } on FormatException catch (e) {
      throw MelosConfigException(
        'The repository URL $repositoryYaml is not a valid URL:\n $e',
      );
    }

    try {
      return parseHostedGitRepositoryUrl(repositoryUrl);
    } on FormatException catch (e) {
      throw MelosConfigException(e.toString());
    }
  }

  /// The absolute path to the workspace folder.
  final String path;

  /// The name of the melos workspace – used by IDE documentation.
  final String name;

  /// The hosted git repository which contains the workspace.
  final HostedGitRepository? repository;

  /// A list of [Glob]s for paths that should be searched for packages.
  final List<Glob> packages;

  /// A map of [Glob]s for paths that should be searched for packages.
  final Map<String, List<Glob>> categories;

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
    _validatePhysicalWorkspace();
  }

  /// Validates the physical workspace on the file system.
  void _validatePhysicalWorkspace() {
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
      const DeepCollectionEquality(
        GlobEquality(),
      ).equals(other.packages, packages) &&
      const DeepCollectionEquality(
        GlobEquality(),
      ).equals(other.ignore, ignore) &&
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
      'melos': {
        if (repository != null) 'repository': repository!,
        'categories': categories.map((category, packages) {
          return MapEntry(
            category,
            packages.map((p) => p.pattern).toList(),
          );
        }),
        if (ignore.isNotEmpty)
          'ignore': ignore.map((p) => p.toString()).toList(),
        if (scripts.isNotEmpty) 'scripts': scripts.toJson(),
        'ide': ide.toJson(),
        'command': commands.toJson(),
      },
    };
  }

  YamlNode toYaml() {
    return wrapAsYamlNode(toJson());
  }

  @override
  String toString() {
    return '''
MelosWorkspaceConfig(
  path: $path,
  name: $name,
  repository: $repository,
  categories: $categories,
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
