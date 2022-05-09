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

import 'package:melos/src/common/git_repository.dart';
import 'package:test/test.dart';

void main() {
  group('GitHubRepository', () {
    group('fromUrl', () {
      test('parse GitHub repository URL correctly', () {
        final url = Uri.parse('https://github.com/a/b');
        final repo = GitHubRepository.fromUrl(url);
        expect(repo.owner, 'a');
        expect(repo.name, 'b');
        expect(repo.url, Uri.parse('https://github.com/a/b/'));
      });

      test('throws if URL is not a valid GitHub repository URL', () {
        void expectBadUrl(String url) {
          final uri = Uri.parse(url);
          expect(
            () => GitHubRepository.fromUrl(uri),
            throwsFormatException,
            reason: url,
          );
        }

        const [
          '',
          'http://github.com/a/b',
          'https://gitlab.com/a/b',
          'https://github.com/a',
          'https://github.com/',
          'https://github.com',
        ].forEach(expectBadUrl);
      });
    });

    test('commitUrl returns correct URL', () {
      final repo = GitHubRepository(owner: 'a', name: 'b');
      const commitId = 'b2841394a48cd7d84a4966a788842690e543b2ef';

      expect(
        repo.commitUrl(commitId),
        Uri.parse(
          'https://github.com/a/b/commit/b2841394a48cd7d84a4966a788842690e543b2ef',
        ),
      );
    });

    test('issueUrl returns correct URL', () {
      final repo = GitHubRepository(owner: 'a', name: 'b');
      const issueId = '123';

      expect(
        repo.issueUrl(issueId),
        Uri.parse('https://github.com/a/b/issues/123'),
      );
    });
  });

  group('GitLabRepository', () {
    group('fromUrl', () {
      test('parse GitLab repository URL correctly', () {
        final url = Uri.parse('https://gitlab.com/a/b');
        final repo = GitLabRepository.fromUrl(url);
        expect(repo.owner, 'a');
        expect(repo.name, 'b');
        expect(repo.url, Uri.parse('https://gitlab.com/a/b/'));
      });

      test('parse GitLab repository URL with nested groups correctly', () {
        final url = Uri.parse('https://gitlab.com/a/b/c');
        final repo = GitLabRepository.fromUrl(url);
        expect(repo.owner, 'a/b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://gitlab.com/a/b/c/'));
      });

      test('throws if URL is not a valid GitLab repository URL', () {
        void expectBadUrl(String url) {
          final uri = Uri.parse(url);
          expect(
            () => GitLabRepository.fromUrl(uri),
            throwsFormatException,
            reason: url,
          );
        }

        const [
          '',
          'http://gitlab.com/a/b',
          'https://github.com/a/b',
          'https://gitlab.com/a',
          'https://gitlab.com/',
          'https://gitlab.com',
        ].forEach(expectBadUrl);
      });
    });

    test('commitUrl returns correct URL', () {
      final repo = GitLabRepository(owner: 'a', name: 'b');
      const commitId = 'b2841394a48cd7d84a4966a788842690e543b2ef';

      expect(
        repo.commitUrl(commitId),
        Uri.parse(
          'https://gitlab.com/a/b/-/commit/b2841394a48cd7d84a4966a788842690e543b2ef',
        ),
      );
    });

    test('issueUrl returns correct URL', () {
      final repo = GitLabRepository(owner: 'a', name: 'b');
      const issueId = '123';

      expect(
        repo.issueUrl(issueId),
        Uri.parse('https://gitlab.com/a/b/-/issues/123'),
      );
    });
  });

  group('parseHostedGitRepositoryUrl', () {
    test('parses GitHub repository URL', () {
      final repo =
          parseHostedGitRepositoryUrl(Uri.parse('https://github.com/a/b'));
      expect(repo, isA<GitHubRepository>());
    });

    test('parses GitLab repository URL', () {
      final repo =
          parseHostedGitRepositoryUrl(Uri.parse('https://gitlab.com/a/b'));
      expect(repo, isA<GitLabRepository>());
    });

    test('throws if URL cannot be parsed as URL to one of known hosts', () {
      expect(
        () => parseHostedGitRepositoryUrl(Uri.parse('https://example.com')),
        throwsFormatException,
      );
    });
  });
}
