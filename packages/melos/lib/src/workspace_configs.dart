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

import 'package:ansi_styles/ansi_styles.dart';
import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:pubspec/pubspec.dart';
import 'package:yaml/yaml.dart';

import '../melos.dart';
import 'common/git_repository.dart';
import 'common/glob.dart';
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

/// Melos command-specific configurations.
@immutable
class CommandConfigs {
  const CommandConfigs({
    this.bootstrap = BootstrapCommandConfigs.empty,
    this.clean = CleanCommandConfigs.empty,
    this.version = VersionCommandConfigs.empty,
  });

  factory CommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
    bool repositoryIsConfigured = false,
  }) {
    final bootstrapMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'bootstrap',
      map: yaml,
      path: 'command',
    );

    final cleanMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'clean',
      map: yaml,
      path: 'command',
    );

    final versionMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'version',
      map: yaml,
      path: 'command',
    );

    return CommandConfigs(
      bootstrap: BootstrapCommandConfigs.fromYaml(
        bootstrapMap ?? const {},
        workspacePath: workspacePath,
      ),
      clean: CleanCommandConfigs.fromYaml(
        cleanMap ?? const {},
        workspacePath: workspacePath,
      ),
      version: VersionCommandConfigs.fromYaml(
        versionMap ?? const {},
        workspacePath: workspacePath,
        repositoryIsConfigured: repositoryIsConfigured,
      ),
    );
  }

  static const CommandConfigs empty = CommandConfigs();

  final BootstrapCommandConfigs bootstrap;
  final CleanCommandConfigs clean;
  final VersionCommandConfigs version;

  Map<String, Object?> toJson() {
    return {
      'bootstrap': bootstrap.toJson(),
      'clean': clean.toJson(),
      'version': version.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CommandConfigs &&
      runtimeType == other.runtimeType &&
      other.bootstrap == bootstrap &&
      other.clean == clean &&
      other.version == version;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      bootstrap.hashCode ^
      clean.hashCode ^
      version.hashCode;

  @override
  String toString() {
    return '''
CommandConfigs(
  bootstrap: ${bootstrap.toString().indent('  ')},
  clean: ${clean.toString().indent('  ')},
  version: ${version.toString().indent('  ')},
)
''';
  }
}

/// Scripts to be executed before/after a melos command.
@immutable
class LifecycleHooks {
  const LifecycleHooks({this.pre, this.post});

  factory LifecycleHooks.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    return LifecycleHooks(
      pre: LifecycleHooks._namedScript('pre', yaml, workspacePath),
      post: LifecycleHooks._namedScript('post', yaml, workspacePath),
    );
  }

  static Script? _namedScript(
    String name,
    Map<Object?, Object?> yaml,
    String workspacePath,
  ) {
    final script = yaml[name];
    if (script == null) {
      return null;
    }
    return Script.fromYaml(script, name: name, workspacePath: workspacePath);
  }

  static const LifecycleHooks empty = LifecycleHooks();

  /// A script to execute before the melos command starts.
  final Script? pre;

  /// A script to execute before the melos command completed.
  final Script? post;

  Map<String, Object?> toJson() {
    return {
      'pre': pre?.toJson(),
      'post': post?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is LifecycleHooks &&
      runtimeType == other.runtimeType &&
      other.pre == pre &&
      other.post == post;

  @override
  int get hashCode => runtimeType.hashCode ^ pre.hashCode ^ post.hashCode;

  @override
  String toString() {
    return '''
LifecycleHooks(
  pre: $pre,
  post: $post,
)
''';
  }
}

/// [LifecycleHooks] for the `version` command.
@immutable
class VersionLifecycleHooks extends LifecycleHooks {
  const VersionLifecycleHooks({super.pre, super.post, this.preCommit});

  factory VersionLifecycleHooks.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    return VersionLifecycleHooks(
      pre: LifecycleHooks._namedScript('pre', yaml, workspacePath),
      post: LifecycleHooks._namedScript('post', yaml, workspacePath),
      preCommit: LifecycleHooks._namedScript('preCommit', yaml, workspacePath),
    );
  }

  /// A script to execute before the version command commits the the changes
  /// made during versioning.
  final Script? preCommit;

  static const VersionLifecycleHooks empty = VersionLifecycleHooks();

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'preCommit': preCommit?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is VersionLifecycleHooks &&
      runtimeType == other.runtimeType &&
      other.pre == pre &&
      other.post == post &&
      other.preCommit == preCommit;

  @override
  int get hashCode =>
      runtimeType.hashCode ^ pre.hashCode ^ post.hashCode ^ preCommit.hashCode;

  @override
  String toString() {
    return '''
VersionLifecycleHooks(
  pre: $pre,
  post: $post,
  preCommit: $preCommit,
)
''';
  }
}

/// Configurations for `melos bootstrap`.
@immutable
class BootstrapCommandConfigs {
  const BootstrapCommandConfigs({
    this.runPubGetInParallel = true,
    this.runPubGetOffline = false,
    this.enforceLockfile = false,
    this.environment,
    this.dependencies,
    this.devDependencies,
    this.dependencyOverridePaths = const [],
    this.hooks = LifecycleHooks.empty,
  });

  factory BootstrapCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    final runPubGetInParallel = assertKeyIsA<bool?>(
          key: 'runPubGetInParallel',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        true;

    final runPubGetOffline = assertKeyIsA<bool?>(
          key: 'runPubGetOffline',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        false;

    final enforceLockfile = assertKeyIsA<bool?>(
          key: 'enforceLockfile',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        false;

    final environment = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'environment',
      map: yaml,
    ).let(Environment.fromJson);

    final dependencies = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'dependencies',
      map: yaml,
    )?.map(
      (key, value) => MapEntry(
        key.toString(),
        DependencyReference.fromJson(value),
      ),
    );

    final devDependencies = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'dev_dependencies',
      map: yaml,
    )?.map(
      (key, value) => MapEntry(
        key.toString(),
        DependencyReference.fromJson(value),
      ),
    );

    final dependencyOverridePaths = assertListIsA<String>(
      key: 'dependencyOverridePaths',
      map: yaml,
      isRequired: false,
      assertItemIsA: (index, value) => assertIsA<String>(
        value: value,
        index: index,
        path: 'dependencyOverridePaths',
      ),
    );

    final hooksMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'hooks',
      map: yaml,
      path: 'command/bootstrap',
    );
    final hooks = hooksMap != null
        ? LifecycleHooks.fromYaml(hooksMap, workspacePath: workspacePath)
        : LifecycleHooks.empty;

    return BootstrapCommandConfigs(
      runPubGetInParallel: runPubGetInParallel,
      runPubGetOffline: runPubGetOffline,
      enforceLockfile: enforceLockfile,
      environment: environment,
      dependencies: dependencies,
      devDependencies: devDependencies,
      dependencyOverridePaths: dependencyOverridePaths
          .map(
            (override) =>
                createGlob(override, currentDirectoryPath: workspacePath),
          )
          .toList(),
      hooks: hooks,
    );
  }

  static const BootstrapCommandConfigs empty = BootstrapCommandConfigs();

  /// Whether to run `pub get` in parallel during bootstrapping.
  ///
  /// The default is `true`.
  final bool runPubGetInParallel;

  /// Whether to attempt to run `pub get` in offline mode during bootstrapping.
  /// Useful in closed network environments with pre-populated pubcaches.
  ///
  /// The default is `false`.
  final bool runPubGetOffline;

  /// Whether `pubspec.lock` is enforced when running `pub get` or not.
  /// Useful when you want to ensure the same versions of dependencies are used
  /// across different environments/machines.
  ///
  /// The default is `false`.
  final bool enforceLockfile;

  /// Environment configuration to be synced between all packages.
  final Environment? environment;

  /// Dependencies to be synced between all packages.
  final Map<String, DependencyReference>? dependencies;

  /// Dev dependencies to be synced between all packages.
  final Map<String, DependencyReference>? devDependencies;

  /// A list of [Glob]s for paths that contain packages to be used as dependency
  /// overrides for all packages managed in the Melos workspace.
  final List<Glob> dependencyOverridePaths;

  /// Lifecycle hooks for this command.
  final LifecycleHooks hooks;

  Map<String, Object?> toJson() {
    return {
      'runPubGetInParallel': runPubGetInParallel,
      'runPubGetOffline': runPubGetOffline,
      'enforceLockfile': enforceLockfile,
      if (environment != null) 'environment': environment!.toJson(),
      if (dependencies != null)
        'dependencies': dependencies!.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      if (devDependencies != null)
        'dev_dependencies': devDependencies!.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      if (dependencyOverridePaths.isNotEmpty)
        'dependencyOverridePaths':
            dependencyOverridePaths.map((path) => path.toString()).toList(),
      'hooks': hooks.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BootstrapCommandConfigs &&
      runtimeType == other.runtimeType &&
      other.runPubGetInParallel == runPubGetInParallel &&
      other.runPubGetOffline == runPubGetOffline &&
      other.enforceLockfile == enforceLockfile &&
      // Extracting equality from environment here as it does not implement ==
      other.environment?.sdkConstraint == environment?.sdkConstraint &&
      const DeepCollectionEquality().equals(
        other.environment?.unParsedYaml,
        environment?.unParsedYaml,
      ) &&
      const DeepCollectionEquality().equals(other.dependencies, dependencies) &&
      const DeepCollectionEquality()
          .equals(other.devDependencies, devDependencies) &&
      const DeepCollectionEquality(_GlobEquality())
          .equals(other.dependencyOverridePaths, dependencyOverridePaths) &&
      other.hooks == hooks;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      runPubGetInParallel.hashCode ^
      runPubGetOffline.hashCode ^
      enforceLockfile.hashCode ^
      // Extracting hashCode from environment here as it does not implement
      // hashCode
      (environment?.sdkConstraint).hashCode ^
      const DeepCollectionEquality().hash(
        environment?.unParsedYaml,
      ) ^
      const DeepCollectionEquality().hash(dependencies) ^
      const DeepCollectionEquality().hash(devDependencies) ^
      const DeepCollectionEquality(_GlobEquality())
          .hash(dependencyOverridePaths) ^
      hooks.hashCode;

  @override
  String toString() {
    return '''
BootstrapCommandConfigs(
  runPubGetInParallel: $runPubGetInParallel,
  runPubGetOffline: $runPubGetOffline,
  enforceLockfile: $enforceLockfile,
  environment: $environment,
  dependencies: $dependencies,
  devDependencies: $devDependencies,
  dependencyOverridePaths: $dependencyOverridePaths,
  hooks: $hooks,
)''';
  }
}

/// Configurations for `melos clean`.
@immutable
class CleanCommandConfigs {
  const CleanCommandConfigs({
    this.hooks = LifecycleHooks.empty,
  });

  factory CleanCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    final hooksMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'hooks',
      map: yaml,
      path: 'command/clean',
    );
    final hooks = hooksMap != null
        ? LifecycleHooks.fromYaml(hooksMap, workspacePath: workspacePath)
        : LifecycleHooks.empty;

    return CleanCommandConfigs(
      hooks: hooks,
    );
  }

  static const CleanCommandConfigs empty = CleanCommandConfigs();

  final LifecycleHooks hooks;

  Map<String, Object?> toJson() {
    return {
      'hooks': hooks.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CleanCommandConfigs &&
      runtimeType == other.runtimeType &&
      other.hooks == hooks;

  @override
  int get hashCode => runtimeType.hashCode ^ hooks.hashCode;

  @override
  String toString() {
    return '''
CleanCommandConfigs(
  hooks: $hooks,
)''';
  }
}

/// Configurations for `melos version`.
@immutable
class VersionCommandConfigs {
  const VersionCommandConfigs({
    this.branch,
    this.message,
    this.includeScopes = true,
    this.linkToCommits = false,
    this.includeCommitId = false,
    this.includeCommitBody = false,
    this.commitBodyOnlyBreaking = true,
    this.updateGitTagRefs = false,
    this.releaseUrl = false,
    List<AggregateChangelogConfig>? aggregateChangelogs,
    this.fetchTags = true,
    this.hooks = VersionLifecycleHooks.empty,
  }) : _aggregateChangelogs = aggregateChangelogs;

  factory VersionCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
    bool repositoryIsConfigured = false,
  }) {
    final branch = assertKeyIsA<String?>(
      key: 'branch',
      map: yaml,
      path: 'command/version',
    );
    final message = assertKeyIsA<String?>(
      key: 'message',
      map: yaml,
      path: 'command/version',
    );
    final includeScopes = assertKeyIsA<bool?>(
      key: 'includeScopes',
      map: yaml,
      path: 'command/version',
    );
    final includeCommitId = assertKeyIsA<bool?>(
      key: 'includeCommitId',
      map: yaml,
      path: 'command/version',
    );
    final linkToCommits = assertKeyIsA<bool?>(
      key: 'linkToCommits',
      map: yaml,
      path: 'command/version',
    );
    final updateGitTagRefs = assertKeyIsA<bool?>(
      key: 'updateGitTagRefs',
      map: yaml,
      path: 'command/version',
    );
    final releaseUrl = assertKeyIsA<bool?>(
      key: 'releaseUrl',
      map: yaml,
      path: 'command/version',
    );

    final workspaceChangelog = assertKeyIsA<bool?>(
      key: 'workspaceChangelog',
      map: yaml,
      path: 'command/version',
    );

    final aggregateChangelogs = <AggregateChangelogConfig>[];
    if (workspaceChangelog ?? true) {
      aggregateChangelogs.add(AggregateChangelogConfig.workspace());
    }

    final changelogsYaml = assertKeyIsA<List<Object?>?>(
      key: 'changelogs',
      map: yaml,
      path: 'command/version',
    );

    if (changelogsYaml != null) {
      for (var i = 0; i < changelogsYaml.length; i++) {
        final entry = changelogsYaml[i]! as Map<Object?, Object?>;

        final path = assertKeyIsA<String>(
          map: entry,
          path: 'command/version/changelogs[$i]',
          key: 'path',
        );

        final packageFiltersMap = assertKeyIsA<Map<Object?, Object?>>(
          map: entry,
          key: 'packageFilters',
          path: 'command/version/changelogs[$i]',
        );
        final packageFilters = PackageFilters.fromYaml(
          packageFiltersMap,
          path: 'command/version/changelogs[$i]',
          workspacePath: workspacePath,
        );

        final description = assertKeyIsA<String?>(
          map: entry,
          path: 'command/version/changelogs[$i]',
          key: 'description',
        );
        final changelogConfig = AggregateChangelogConfig(
          path: path,
          packageFilters: packageFilters,
          description: description,
        );

        aggregateChangelogs.add(changelogConfig);
      }
    }

    final fetchTags = assertKeyIsA<bool?>(
      key: 'fetchTags',
      map: yaml,
      path: 'command/version',
    );

    final hooksMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'hooks',
      map: yaml,
      path: 'command/version',
    );

    final hooks = hooksMap != null
        ? VersionLifecycleHooks.fromYaml(
            hooksMap,
            workspacePath: workspacePath,
          )
        : VersionLifecycleHooks.empty;

    final changelogCommitBodiesEntry = assertKeyIsA<Map<Object?, Object?>?>(
          key: 'changelogCommitBodies',
          map: yaml,
          path: 'command/version',
        ) ??
        const {};

    final includeCommitBodies = assertKeyIsA<bool?>(
      key: 'include',
      map: changelogCommitBodiesEntry,
      path: 'command/version/changelogCommitBodies',
    );

    final bodiesOnlyBreaking = assertKeyIsA<bool?>(
      key: 'onlyBreaking',
      map: changelogCommitBodiesEntry,
      path: 'command/version/changelogCommitBodies',
    );

    return VersionCommandConfigs(
      branch: branch,
      message: message,
      includeScopes: includeScopes ?? true,
      includeCommitId: includeCommitId ?? false,
      includeCommitBody: includeCommitBodies ?? false,
      commitBodyOnlyBreaking: bodiesOnlyBreaking ?? true,
      linkToCommits: linkToCommits ?? repositoryIsConfigured,
      updateGitTagRefs: updateGitTagRefs ?? false,
      releaseUrl: releaseUrl ?? false,
      aggregateChangelogs: aggregateChangelogs,
      fetchTags: fetchTags ?? true,
      hooks: hooks,
    );
  }

  static const VersionCommandConfigs empty = VersionCommandConfigs();

  /// If specified, prevents `melos version` from being used inside branches
  /// other than the one specified.
  final String? branch;

  /// A custom header for the generated CHANGELOG.md.
  final String? message;

  /// Whether to include conventional commit scopes in the generated
  /// CHANGELOG.md.
  final bool includeScopes;

  /// Whether to add commits ids in the generated CHANGELOG.md.
  final bool includeCommitId;

  /// Wheter to include commit bodies in the generated CHANGELOG.md.
  final bool includeCommitBody;

  /// Whether to only include commit bodies for breaking changes.
  final bool commitBodyOnlyBreaking;

  /// Whether to add links to commits in the generated CHANGELOG.md.
  final bool linkToCommits;

  /// Whether to also update pubspec with git referenced packages.
  final bool updateGitTagRefs;

  /// Whether to generate and print a link to the prefilled release creation
  /// page for each package after versioning.
  final bool releaseUrl;

  /// A list of changelogs configurations that will be used to generate
  /// changelogs which describe the changes in multiple packages.
  List<AggregateChangelogConfig> get aggregateChangelogs =>
      _aggregateChangelogs ?? [AggregateChangelogConfig.workspace()];

  final List<AggregateChangelogConfig>? _aggregateChangelogs;

  /// Whether to fetch tags from the `origin` remote before versioning.
  final bool fetchTags;

  /// Lifecycle hooks for this command.
  final VersionLifecycleHooks hooks;

  Map<String, Object?> toJson() {
    return {
      if (branch != null) 'branch': branch,
      if (message != null) 'message': message,
      'includeScopes': includeScopes,
      'includeCommitId': includeCommitId,
      'linkToCommits': linkToCommits,
      'updateGitTagRefs': updateGitTagRefs,
      'aggregateChangelogs':
          aggregateChangelogs.map((config) => config.toJson()).toList(),
      'fetchTags': fetchTags,
      'hooks': hooks.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is VersionCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.branch == branch &&
      other.message == message &&
      other.includeScopes == includeScopes &&
      other.includeCommitId == includeCommitId &&
      other.linkToCommits == linkToCommits &&
      other.updateGitTagRefs == updateGitTagRefs &&
      other.releaseUrl == releaseUrl &&
      const DeepCollectionEquality()
          .equals(other.aggregateChangelogs, aggregateChangelogs) &&
      other.fetchTags == fetchTags &&
      other.hooks == hooks;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      branch.hashCode ^
      message.hashCode ^
      includeScopes.hashCode ^
      includeCommitId.hashCode ^
      linkToCommits.hashCode ^
      updateGitTagRefs.hashCode ^
      releaseUrl.hashCode ^
      const DeepCollectionEquality().hash(aggregateChangelogs) ^
      fetchTags.hashCode ^
      hooks.hashCode;

  @override
  String toString() {
    return '''
VersionCommandConfigs(
  branch: $branch,
  message: $message,
  includeScopes: $includeScopes,
  includeCommitId: $includeCommitId,
  linkToCommits: $linkToCommits,
  updateGitTagRefs: $updateGitTagRefs,
  releaseUrl: $releaseUrl,
  aggregateChangelogs: $aggregateChangelogs,
  fetchTags: $fetchTags,
  hooks: $hooks,
)''';
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
      const DeepCollectionEquality(_GlobEquality())
          .equals(other.packages, packages) &&
      const DeepCollectionEquality(_GlobEquality())
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
      const DeepCollectionEquality(_GlobEquality()).hash(packages) &
          const DeepCollectionEquality(_GlobEquality()).hash(ignore) ^
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

class _GlobEquality implements Equality<Glob> {
  const _GlobEquality();

  @override
  bool equals(Glob e1, Glob e2) =>
      e1.pattern == e2.pattern && e1.context.current == e2.context.current;

  @override
  int hash(Glob e) => e.pattern.hashCode ^ e.context.current.hashCode;

  @override
  bool isValidKey(Object? o) => true;
}

/// An exception thrown when a Melos workspace could not be resolved.
class UnresolvedWorkspace implements MelosException {
  UnresolvedWorkspace(this.message);

  final String message;

  @override
  String toString() => message;
}
