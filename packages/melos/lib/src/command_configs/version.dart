import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../melos.dart';
import '../common/validation.dart';
import '../lifecycle_hooks/version.dart';
import '../workspace_configs.dart';

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
