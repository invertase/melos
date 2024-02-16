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

import 'package:meta/meta.dart';

import 'git.dart';
import 'pending_package_update.dart';
import 'utils.dart';

/// A hosted git repository.
@immutable
abstract class HostedGitRepository {
  const HostedGitRepository();

  /// The name of this repository.
  String get name;

  /// The URL of this repository on the host's web site.
  Uri get url;

  /// The URL of the commit with the given [id] on the host's web site.
  Uri commitUrl(String id);

  /// The URL of the issue/PR with the given [id] on the host's web site.
  Uri issueUrl(String id);
}

mixin SupportsManualRelease on HostedGitRepository {
  /// Returns the URL to the prefilled release creation page for the release
  /// of a package.
  Uri releaseUrlForUpdate(MelosPendingPackageUpdate pendingPackageUpdate) {
    final packageName = pendingPackageUpdate.package.name;
    final packageVersion = pendingPackageUpdate.nextVersion.toString();

    final tag = gitTagForPackageVersion(packageName, packageVersion);
    final title = gitReleaseTitleForPackageVersion(packageName, packageVersion);
    final body = pendingPackageUpdate.changelog.markdown;
    final isPreRelease = pendingPackageUpdate.nextVersion.isPreRelease;

    return releaseUrl(
      tag: tag,
      title: title,
      body: body,
      isPreRelease: isPreRelease,
    );
  }

  /// Returns a URL to the release creation page with the given parameters.
  Uri releaseUrl({
    String? tag,
    String? title,
    String? body,
    bool? isPreRelease,
  });
}

/// A git repository, hosted by GitHub.
@immutable
class GitHubRepository extends HostedGitRepository with SupportsManualRelease {
  GitHubRepository({
    String origin = defaultOrigin,
    required this.owner,
    required this.name,
  }) : origin = removeTrailingSlash(origin);

  factory GitHubRepository.fromUrl(Uri uri) {
    if (uri.scheme == 'https' && uri.host == 'github.com') {
      final match = RegExp(r'^/(.+)/(.+)/?$').firstMatch(uri.path);
      if (match != null) {
        return GitHubRepository(
          owner: match.group(1)!,
          name: match.group(2)!,
        );
      }
    }

    throw FormatException('The URL $uri is not a valid GitHub repository URL.');
  }

  static const defaultOrigin = 'https://github.com';

  /// The origin of the GitHub server, defaults to `https://github.com`.
  final String origin;

  /// The username of the owner of this repository.
  final String owner;

  @override
  final String name;

  @override
  Uri get url => Uri.parse('$origin/$owner/$name/');

  @override
  Uri commitUrl(String id) => url.resolve('commit/$id');

  @override
  Uri issueUrl(String id) => url.resolve('issues/$id');

  @override
  Uri releaseUrl({
    String? tag,
    String? title,
    String? body,
    bool? isPreRelease,
  }) {
    return url.resolve('releases/new').replace(
      queryParameters: <String, String>{
        if (tag != null) 'tag': tag,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (isPreRelease != null) 'prerelease': '$isPreRelease',
      },
    );
  }

  @override
  String toString() {
    return '''
GitHubRepository(
  origin: $origin,
  owner: $owner,
  name: $name,
)''';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitHubRepository &&
          other.runtimeType == runtimeType &&
          other.origin == origin &&
          other.owner == owner &&
          other.name == name;

  @override
  int get hashCode => origin.hashCode ^ owner.hashCode ^ name.hashCode;
}

/// A git repository, hosted by GitLab.
@immutable
class GitLabRepository extends HostedGitRepository {
  GitLabRepository({
    String origin = defaultOrigin,
    required this.owner,
    required this.name,
  }) : origin = removeTrailingSlash(origin);

  factory GitLabRepository.fromUrl(Uri uri) {
    if (uri.scheme == 'https' && uri.host == 'gitlab.com') {
      final match = RegExp(r'^/(.+)?/(.+)/?$').firstMatch(uri.path);
      if (match != null) {
        return GitLabRepository(
          owner: match.group(1)!,
          name: match.group(2)!,
        );
      }
    }

    throw FormatException('The URL $uri is not a valid GitLab repository URL.');
  }

  static const defaultOrigin = 'https://gitlab.com';

  /// The origin of the GitLab server, defaults to `https://gitlab.com`.
  final String origin;

  /// The username of the owner of this repository.
  final String owner;

  @override
  final String name;

  @override
  Uri get url => Uri.parse('$origin/$owner/$name/');

  @override
  Uri commitUrl(String id) => url.resolve('-/commit/$id');

  @override
  Uri issueUrl(String id) => url.resolve('-/issues/$id');

  @override
  String toString() {
    return '''
GitLabRepository(
  origin: $origin,
  owner: $owner,
  name: $name,
)''';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitHubRepository &&
          other.runtimeType == runtimeType &&
          other.origin == origin &&
          other.owner == owner &&
          other.name == name;

  @override
  int get hashCode => origin.hashCode ^ owner.hashCode ^ name.hashCode;
}

class BitbucketRepository extends HostedGitRepository {
  BitbucketRepository({
    String origin = defaultOrigin,
    required this.owner,
    required this.name,
  }) : origin = removeTrailingSlash(origin);

  factory BitbucketRepository.fromUrl(Uri uri) {
    if (uri.scheme == 'https' && uri.host == 'bitbucket.org') {
      final match = RegExp(r'^/(.+)?/(.+)/?$').firstMatch(uri.path);
      if (match != null) {
        return BitbucketRepository(
          owner: match.group(1)!,
          name: match.group(2)!,
        );
      }
    }

    throw FormatException(
      'The URL $uri is not a valid Bitbucket repository URL.',
    );
  }

  static const defaultOrigin = 'https://bitbucket.org';

  /// The origin of the Bitbucket server, defaults to `https://bitbucket.org`.
  final String origin;

  /// The owning workspace name.
  final String owner;

  @override
  final String name;

  @override
  Uri commitUrl(String id) => url.resolve('commits/$id');

  // TODO(fenrirx22): Implementing an issueUrl for Bitbucket requires a Jira URL
  @override
  Uri issueUrl(String id) => Uri();

  @override
  Uri get url => Uri.parse('$origin/$owner/$name/');
}

final _hostsToUrlParser = {
  'GitHub': GitHubRepository.fromUrl,
  'GitLab': GitLabRepository.fromUrl,
  'Bitbucket': BitbucketRepository.fromUrl,
};

final _hostsToSpecParser = {
  'GitHub': GitHubRepository.new,
  'GitLab': GitLabRepository.new,
  'Bitbucket': BitbucketRepository.new,
};

/// Tries to parse [url] into a [HostedGitRepository].
///
/// Throws a [FormatException] it the given [url] cannot be parsed into an URL
/// of any of the supported git repository hosts.
HostedGitRepository parseHostedGitRepositoryUrl(Uri url) {
  for (final parser in _hostsToUrlParser.values) {
    try {
      return parser(url);
      // ignore: empty_catches
    } catch (e) {}
  }

  throw FormatException(
    'The URL $url is not a valid URL for a repository on any of the supported '
    'hosts: ${_hostsToUrlParser.keys.join(', ')}',
  );
}

/// Tries to find a [HostedGitRepository] for [type].
///
/// Throws a [FormatException] it the given [type] is not one of the supported
/// git repository host types.
HostedGitRepository parseHostedGitRepositorySpec(
  String type,
  String origin,
  String owner,
  String name,
) {
  for (final entry in _hostsToSpecParser.entries) {
    if (entry.key.toLowerCase() == type.toLowerCase()) {
      return entry.value(origin: origin, owner: owner, name: name);
    }
  }

  throw FormatException(
    '$type is not a valid type for a repository on any of the supported '
    'hosts: ${_hostsToSpecParser.keys.join(', ')}',
  );
}
