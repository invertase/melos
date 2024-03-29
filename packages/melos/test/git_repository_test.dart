import 'package:melos/src/common/git_repository.dart';
import 'package:test/test.dart';

void main() {
  group('GitHubRepository', () {
    group('fromUrl', () {
      test('parse GitHub repository URL correctly', () {
        final url = Uri.parse('https://github.com/a/b');
        final repo = GitHubRepository.fromUrl(url);

        expect(repo.origin, 'https://github.com');
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

    group('fromSpec', () {
      test('parse GitHub repository spec correctly', () {
        final repo = GitHubRepository(
          origin: 'https://github.invertase.dev',
          owner: 'a',
          name: 'b',
        );

        expect(repo.origin, 'https://github.invertase.dev');
        expect(repo.owner, 'a');
        expect(repo.name, 'b');
        expect(repo.url, Uri.parse('https://github.invertase.dev/a/b/'));
      });

      test('parse GitHub repository spec with sub-path correctly', () {
        final repo = GitHubRepository(
          origin: 'https://invertase.dev/github',
          owner: 'a',
          name: 'b',
        );

        expect(repo.origin, 'https://invertase.dev/github');
        expect(repo.owner, 'a');
        expect(repo.name, 'b');
        expect(repo.url, Uri.parse('https://invertase.dev/github/a/b/'));
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

        expect(repo.origin, 'https://gitlab.com');
        expect(repo.owner, 'a');
        expect(repo.name, 'b');
        expect(repo.url, Uri.parse('https://gitlab.com/a/b/'));
      });

      test('parse GitLab repository URL with nested groups correctly', () {
        final url = Uri.parse('https://gitlab.com/a/b/c');
        final repo = GitLabRepository.fromUrl(url);

        expect(repo.origin, 'https://gitlab.com');
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

    group('fromSpec', () {
      test('parse GitLab repository spec correctly', () {
        final repo = GitLabRepository(
          origin: 'https://gitlab.invertase.dev',
          owner: 'a',
          name: 'b',
        );

        expect(repo.origin, 'https://gitlab.invertase.dev');
        expect(repo.owner, 'a');
        expect(repo.name, 'b');
        expect(repo.url, Uri.parse('https://gitlab.invertase.dev/a/b/'));
      });

      test('parse GitLab repository spec with sub-path correctly', () {
        final repo = GitLabRepository(
          origin: 'https://invertase.dev/gitlab',
          owner: 'a',
          name: 'b',
        );

        expect(repo.origin, 'https://invertase.dev/gitlab');
        expect(repo.owner, 'a');
        expect(repo.name, 'b');
        expect(repo.url, Uri.parse('https://invertase.dev/gitlab/a/b/'));
      });

      test('parse GitLab repository spec with nested groups correctly', () {
        final repo = GitLabRepository(
          origin: 'https://gitlab.invertase.dev',
          owner: 'a/b',
          name: 'c',
        );

        expect(repo.origin, 'https://gitlab.invertase.dev');
        expect(repo.owner, 'a/b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://gitlab.invertase.dev/a/b/c/'));
      });

      test(
          'parse GitLab repository spec with sub-path and nested groups '
          'correctly', () {
        final repo = GitLabRepository(
          origin: 'https://invertase.dev/gitlab',
          owner: 'a/b',
          name: 'c',
        );

        expect(repo.origin, 'https://invertase.dev/gitlab');
        expect(repo.owner, 'a/b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://invertase.dev/gitlab/a/b/c/'));
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

  group('BitBucketRepository', () {
    group('fromUrl', () {
      test('parse Bitbucket repository URL correctly', () {
        final url = Uri.parse('https://bitbucket.org/a/b');
        final repo = BitbucketRepository.fromUrl(url);

        expect(repo.origin, 'https://bitbucket.org');
        expect(repo.owner, 'a');
        expect(repo.name, 'b');
        expect(repo.url, Uri.parse('https://bitbucket.org/a/b/'));
      });

      test('throws if URL is not a valid GitLab repository URL', () {
        void expectBadUrl(String url) {
          final uri = Uri.parse(url);
          expect(
            () => BitbucketRepository.fromUrl(uri),
            throwsFormatException,
            reason: url,
          );
        }

        const [
          '',
          'http://bitbucket.org/a/b',
          'https://gitlab.com/a/b',
          'https://github.com/a/b',
          'https://bitbucket.org/a',
          'https://bitbucket.org/',
          'https://bitbucket.org',
        ].forEach(expectBadUrl);
      });
    });

    group('fromSpec', () {
      test('parse Bitbucket repository spec correctly', () {
        final repo = BitbucketRepository(
          origin: 'https://bitbucket.invertase.dev',
          owner: 'a',
          name: 'b',
        );

        expect(repo.origin, 'https://bitbucket.invertase.dev');
        expect(repo.owner, 'a');
        expect(repo.name, 'b');
        expect(repo.url, Uri.parse('https://bitbucket.invertase.dev/a/b/'));
      });

      test('parse Bitbucket repository spec with nested groups correctly', () {
        final repo = BitbucketRepository(
          origin: 'https://bitbucket.invertase.dev',
          owner: 'a/b',
          name: 'c',
        );

        expect(repo.origin, 'https://bitbucket.invertase.dev');
        expect(repo.owner, 'a/b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://bitbucket.invertase.dev/a/b/c/'));
      });

      test(
          'parse Bitbucket repository spec with sub-path and nested groups '
          'correctly', () {
        final repo = BitbucketRepository(
          origin: 'https://invertase.dev/bitbucket',
          owner: 'a/b',
          name: 'c',
        );

        expect(repo.origin, 'https://invertase.dev/bitbucket');
        expect(repo.owner, 'a/b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://invertase.dev/bitbucket/a/b/c/'));
      });
    });

    test('commitUrl returns correct URL', () {
      final repo = BitbucketRepository(owner: 'a', name: 'b');
      const commitId = 'b2841394a48cd7d84a4966a788842690e543b2ef';

      expect(
        repo.commitUrl(commitId),
        Uri.parse(
          'https://bitbucket.org/a/b/commits/b2841394a48cd7d84a4966a788842690e543b2ef',
        ),
      );
    });

    test('issueUrl returns empty URL', () {
      final repo = BitbucketRepository(owner: 'a', name: 'b');
      const issueId = '123';

      expect(
        repo.issueUrl(issueId),
        Uri(),
      );
    });
  });

  group('AzureDevOpsRepository', () {
    group('fromUrl', () {
      test('parse Azure DevOps repository URL correctly', () {
        final url = Uri.parse('https://dev.azure.com/a/b/_git/c');
        final repo = AzureDevOpsRepository.fromUrl(url);

        expect(repo.origin, 'https://dev.azure.com/a');
        expect(repo.owner, 'b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://dev.azure.com/a/b/_git/c/'));
      });

      test('parse Azure DevOps (old URL format) repository URL correctly', () {
        final url = Uri.parse('https://a.visualstudio.com/b/_git/c');
        final repo = AzureDevOpsRepository.fromUrl(url);

        expect(repo.origin, 'https://a.visualstudio.com');
        expect(repo.owner, 'b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://a.visualstudio.com/b/_git/c/'));
      });

      test('parse Azure DevOps Server repository URL correctly', () {
        final url = Uri.parse('https://a.visualstudio.com/b/_git/c');
        final repo = AzureDevOpsRepository.fromUrl(url);

        expect(repo.origin, 'https://a.visualstudio.com');
        expect(repo.owner, 'b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://a.visualstudio.com/b/_git/c/'));
      });

      test('throws if URL is not a valid Azure DevOps repository URL', () {
        void expectBadUrl(String url) {
          final uri = Uri.parse(url);
          expect(
            () => AzureDevOpsRepository.fromUrl(uri),
            throwsFormatException,
            reason: url,
          );
        }

        const [
          '',
          'http://dev.azure.com/a/b/_git/c',
          'https://www.visualstudio.com/b/c',
          'https://gitlab.com/a/b',
          'https://github.com/a/b',
          'https://dev.azure.com/a',
          'https://dev.azure.com/',
          'https://dev.azure.com',
        ].forEach(expectBadUrl);
      });
    });

    group('fromSpec', () {
      test('parse Azure DevOps repository spec correctly', () {
        final repo = AzureDevOpsRepository(
          origin: 'https://dev.azure.com/a',
          owner: 'b',
          name: 'c',
        );

        expect(repo.origin, 'https://dev.azure.com/a');
        expect(repo.owner, 'b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://dev.azure.com/a/b/_git/c/'));
      });

      test('parse Azure DevOps (old URL format) repository spec correctly', () {
        final repo = AzureDevOpsRepository(
          origin: 'https://a.visualstudio.com/',
          owner: 'b',
          name: 'c',
        );

        expect(repo.origin, 'https://a.visualstudio.com');
        expect(repo.owner, 'b');
        expect(repo.name, 'c');
        expect(repo.url, Uri.parse('https://a.visualstudio.com/b/_git/c/'));
      });
    });

    test('commitUrl returns correct URL', () {
      final repo = AzureDevOpsRepository(
        origin: 'https://dev.azure.com/a',
        owner: 'b',
        name: 'c',
      );
      const commitId = 'b6849381';

      expect(
        repo.commitUrl(commitId),
        Uri.parse('https://dev.azure.com/a/b/_git/c/commit/b6849381'),
      );
    });

    test('commitUrl returns correct URL (old format)', () {
      final repo = AzureDevOpsRepository(
        origin: 'https://a.visualstudio.com',
        owner: 'b',
        name: 'c',
      );
      const commitId = 'b6849381';

      expect(
        repo.commitUrl(commitId),
        Uri.parse('https://a.visualstudio.com/b/_git/c/commit/b6849381'),
      );
    });

    test('issueUrl returns correct URL', () {
      final repo = AzureDevOpsRepository(
        origin: 'https://dev.azure.com/a',
        owner: 'b',
        name: 'c',
      );
      const issueId = '123';

      expect(
        repo.issueUrl(issueId),
        Uri.parse('https://dev.azure.com/a/b/_workitems/edit/123'),
      );
    });

    test('issueUrl returns correct URL (old format)', () {
      final repo = AzureDevOpsRepository(
        origin: 'https://a.visualstudio.com',
        owner: 'b',
        name: 'c',
      );
      const issueId = '123';

      expect(
        repo.issueUrl(issueId),
        Uri.parse('https://a.visualstudio.com/b/_workitems/edit/123'),
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

    test('parses Azure DevOps repository URL', () {
      final repo = parseHostedGitRepositoryUrl(
        Uri.parse('https://dev.azure.com/a/b/_git/c'),
      );
      expect(repo, isA<AzureDevOpsRepository>());
    });

    test('parses Azure DevOps repository URL (old format)', () {
      final repo = parseHostedGitRepositoryUrl(
        Uri.parse('https://a.visualstudio.com/b/_git/c'),
      );
      expect(repo, isA<AzureDevOpsRepository>());
    });

    test('throws if URL cannot be parsed as URL to one of known hosts', () {
      expect(
        () => parseHostedGitRepositoryUrl(Uri.parse('https://example.com')),
        throwsFormatException,
      );
    });
  });

  group('parseHostedGitRepositorySpec', () {
    test('parses GitHub repository spec', () {
      final repo = parseHostedGitRepositorySpec(
        'github',
        'https://github.invertase.com',
        'a',
        'b',
      );

      expect(repo, isA<GitHubRepository>());
    });

    test('parses GitLab repository spec', () {
      final repo = parseHostedGitRepositorySpec(
        'gitlab',
        'https://gitlab.invertase.com',
        'a',
        'b',
      );

      expect(repo, isA<GitLabRepository>());
    });

    test('parses Azure DevOps repository spec', () {
      final repo = parseHostedGitRepositorySpec(
        'azuredevops',
        'https://dev.azure.com/a',
        'b',
        'c',
      );

      expect(repo, isA<AzureDevOpsRepository>());
    });

    test('parses Azure DevOps repository spec (old URL format)', () {
      final repo = parseHostedGitRepositorySpec(
        'azuredevops',
        'https://a.visualstudio.com/',
        'b',
        'c',
      );

      expect(repo, isA<AzureDevOpsRepository>());
    });

    test('throws if URL cannot be parsed as URL to one of known hosts', () {
      expect(
        () => parseHostedGitRepositorySpec(
          'example',
          'https://example.com',
          'a',
          'b',
        ),
        throwsFormatException,
      );
    });
  });
}
