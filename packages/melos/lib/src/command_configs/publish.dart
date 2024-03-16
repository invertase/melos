import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../melos.dart';
import '../common/validation.dart';
import '../lifecycle_hooks/publish.dart';
import '../workspace_configs.dart';

/// Configurations for `melos publish`.
@immutable
class PublishCommandConfigs {
  const PublishCommandConfigs({
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
    this.hooks = PublishLifecycleHooks.empty,
  }) : _aggregateChangelogs = aggregateChangelogs;

  factory PublishCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
    bool repositoryIsConfigured = false,
  }) {
    final branch = assertKeyIsA<String?>(
      key: 'branch',
      map: yaml,
      path: 'command/publish',
    );
    final message = assertKeyIsA<String?>(
      key: 'message',
      map: yaml,
      path: 'command/publish',
    );
    final includeScopes = assertKeyIsA<bool?>(
      key: 'includeScopes',
      map: yaml,
      path: 'command/publish',
    );
    final includeCommitId = assertKeyIsA<bool?>(
      key: 'includeCommitId',
      map: yaml,
      path: 'command/publish',
    );
    final linkToCommits = assertKeyIsA<bool?>(
      key: 'linkToCommits',
      map: yaml,
      path: 'command/publish',
    );
    final updateGitTagRefs = assertKeyIsA<bool?>(
      key: 'updateGitTagRefs',
      map: yaml,
      path: 'command/publish',
    );
    final releaseUrl = assertKeyIsA<bool?>(
      key: 'releaseUrl',
      map: yaml,
      path: 'command/publish',
    );

    final workspaceChangelog = assertKeyIsA<bool?>(
      key: 'workspaceChangelog',
      map: yaml,
      path: 'command/publish',
    );

    final aggregateChangelogs = <AggregateChangelogConfig>[];
    if (workspaceChangelog ?? true) {
      aggregateChangelogs.add(AggregateChangelogConfig.workspace());
    }

    final changelogsYaml = assertKeyIsA<List<Object?>?>(
      key: 'changelogs',
      map: yaml,
      path: 'command/publish',
    );

    if (changelogsYaml != null) {
      for (var i = 0; i < changelogsYaml.length; i++) {
        final entry = changelogsYaml[i]! as Map<Object?, Object?>;

        final path = assertKeyIsA<String>(
          map: entry,
          path: 'command/publish/changelogs[$i]',
          key: 'path',
        );

        final packageFiltersMap = assertKeyIsA<Map<Object?, Object?>>(
          map: entry,
          key: 'packageFilters',
          path: 'command/publish/changelogs[$i]',
        );
        final packageFilters = PackageFilters.fromYaml(
          packageFiltersMap,
          path: 'command/publish/changelogs[$i]',
          workspacePath: workspacePath,
        );

        final description = assertKeyIsA<String?>(
          map: entry,
          path: 'command/publish/changelogs[$i]',
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
      path: 'command/publish',
    );

    final hooksMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'hooks',
      map: yaml,
      path: 'command/publish',
    );

    final hooks = hooksMap != null
        ? PublishLifecycleHooks.fromYaml(
            hooksMap,
            workspacePath: workspacePath,
          )
        : PublishLifecycleHooks.empty;

    final changelogCommitBodiesEntry = assertKeyIsA<Map<Object?, Object?>?>(
          key: 'changelogCommitBodies',
          map: yaml,
          path: 'command/publish',
        ) ??
        const {};

    final includeCommitBodies = assertKeyIsA<bool?>(
      key: 'include',
      map: changelogCommitBodiesEntry,
      path: 'command/publish/changelogCommitBodies',
    );

    final bodiesOnlyBreaking = assertKeyIsA<bool?>(
      key: 'onlyBreaking',
      map: changelogCommitBodiesEntry,
      path: 'command/publish/changelogCommitBodies',
    );

    return PublishCommandConfigs(
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

  static const PublishCommandConfigs empty = PublishCommandConfigs();

  /// If specified, prevents `melos publish` from being used inside branches
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
  /// page for each package after publishing.
  final bool releaseUrl;

  /// A list of changelogs configurations that will be used to generate
  /// changelogs which describe the changes in multiple packages.
  List<AggregateChangelogConfig> get aggregateChangelogs =>
      _aggregateChangelogs ?? [AggregateChangelogConfig.workspace()];

  final List<AggregateChangelogConfig>? _aggregateChangelogs;

  /// Whether to fetch tags from the `origin` remote before publishing.
  final bool fetchTags;

  /// Lifecycle hooks for this command.
  final PublishLifecycleHooks hooks;

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
      other is PublishCommandConfigs &&
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
PublishCommandConfigs(
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
