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

/// A hosted git repository.
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

/// A git repository, hosted by GitHub.
class GitHubRepository extends HostedGitRepository {
  GitHubRepository({
    required this.owner,
    required this.name,
  });

  factory GitHubRepository.fromUrl(Uri uri) {
    if (uri.scheme == 'https' && uri.host == 'github.com') {
      final match = RegExp(r'^\/(.+)\/(.+)\/?$').firstMatch(uri.path);
      if (match != null) {
        return GitHubRepository(
          owner: match.group(1)!,
          name: match.group(2)!,
        );
      }
    }

    throw FormatException('The URL $uri is not a valid GitHub repository URL.');
  }

  /// The username of the owner of this repository.
  final String owner;

  @override
  final String name;

  @override
  late Uri url = Uri.parse('https://github.com/$owner/$name/');

  @override
  Uri commitUrl(String id) => url.resolve('commit/$id');

  @override
  Uri issueUrl(String id) => url.resolve('issues/$id');

  @override
  String toString() {
    return '''
GitHubRepository(
  owner: $owner,
  name: $name,
)''';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitHubRepository &&
          other.runtimeType == runtimeType &&
          other.owner == owner &&
          other.name == name;

  @override
  int get hashCode => owner.hashCode ^ name.hashCode;
}

/// A git repository, hosted by GitLab.
class GitLabRepository extends HostedGitRepository {
  GitLabRepository({
    required this.owner,
    required this.name,
  });

  factory GitLabRepository.fromUrl(Uri uri) {
    if (uri.scheme == 'https' && uri.host == 'gitlab.com') {
      final match = RegExp(r'^\/((?:.+[\/]?))?\/(.+)\/?$').firstMatch(uri.path);
      if (match != null) {
        return GitLabRepository(
          owner: match.group(1)!,
          name: match.group(2)!,
        );
      }
    }

    throw FormatException('The URL $uri is not a valid GitLab repository URL.');
  }

  /// The username of the owner of this repository.
  final String owner;

  @override
  final String name;

  @override
  late Uri url = Uri.parse('https://gitlab.com/$owner/$name/');

  @override
  Uri commitUrl(String id) => url.resolve('-/commit/$id');

  @override
  Uri issueUrl(String id) => url.resolve('-/issues/$id');

  @override
  String toString() {
    return '''
GitLabRepository(
  owner: $owner,
  name: $name,
)''';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitHubRepository &&
          other.runtimeType == runtimeType &&
          other.owner == owner &&
          other.name == name;

  @override
  int get hashCode => owner.hashCode ^ name.hashCode;
}

final _hostsToUrlParser = {
  'GitHub': (Uri url) => GitHubRepository.fromUrl(url),
  'GitLab': (Uri url) => GitLabRepository.fromUrl(url),
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
