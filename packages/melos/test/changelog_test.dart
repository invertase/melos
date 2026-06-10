import 'package:melos/melos.dart';
import 'package:melos/src/common/changelog.dart';
import 'package:melos/src/common/git_commit.dart';
import 'package:melos/src/common/pending_package_update.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('conventional commit', () {
    test('write scopes', () {
      final workspace = buildWorkspaceWithRepository(includeScopes: true);
      final package = workspace.allPackages['test_pkg']!;

      // No scope
      expect(
        renderCommitPackageUpdate(
          workspace,
          package,
          testCommit(message: 'feat: a'),
        ),
        contains('**FEAT**: a.'),
      );

      // One scope
      expect(
        renderCommitPackageUpdate(
          workspace,
          package,
          testCommit(message: 'feat(a): b'),
        ),
        contains('**FEAT**(a): b.'),
      );

      // Multiple scopes
      expect(
        renderCommitPackageUpdate(
          workspace,
          package,
          testCommit(message: 'feat(a,b): c'),
        ),
        contains('**FEAT**(a,b): c.'),
      );
    });

    test('merge commit without conventional commit', () {
      final workspace = buildWorkspaceWithRepository();
      final package = workspace.allPackages['test_pkg']!;

      expect(
        renderCommitPackageUpdate(
          workspace,
          package,
          testCommit(message: 'Merge foo into bar'),
        ),
        '## 0.0.1\n\n',
      );
    });

    test('merge commit with conventional commit', () {
      final workspace = buildWorkspaceWithRepository();
      final package = workspace.allPackages['test_pkg']!;

      expect(
        renderCommitPackageUpdate(
          workspace,
          package,
          testCommit(message: 'Merge PR #1: feat: a'),
        ),
        contains('**FEAT**: a.'),
      );
    });
  });

  group('linkToCommits', () {
    test('when enabled, adds link to commit behind each one', () {
      final workspace = buildWorkspaceWithRepository(linkToCommits: true);
      final package = workspace.allPackages['test_pkg']!;
      final commit = testCommit(message: 'feat: a');
      final commitUrl = workspace.config.repository!.commitUrl(commit.id);

      expect(
        renderCommitPackageUpdate(workspace, package, commit),
        contains('**FEAT**: a. ([${commit.id.substring(0, 8)}]($commitUrl))'),
      );
    });
  });

  group('includeCommitId', () {
    test('when enabled, adds commit id behind each one', () {
      final workspace = buildWorkspaceWithRepository(
        includeCommitId: true,
      );
      final package = workspace.allPackages['test_pkg']!;
      final commit = testCommit(message: 'feat: a');

      expect(
        renderCommitPackageUpdate(workspace, package, commit),
        contains('**FEAT**: a. (${commit.id.substring(0, 8)})'),
      );
    });

    test(
      'when enabled, and linkToCommits is also enabled adds link to commit '
      'behind each one',
      () {
        final workspace = buildWorkspaceWithRepository(
          includeCommitId: true,
          linkToCommits: true,
        );
        final package = workspace.allPackages['test_pkg']!;
        final commit = testCommit(message: 'feat: a');
        final commitUrl = workspace.config.repository!.commitUrl(commit.id);

        expect(
          renderCommitPackageUpdate(workspace, package, commit),
          contains('**FEAT**: a. ([${commit.id.substring(0, 8)}]($commitUrl))'),
        );
      },
    );
  });

  group('includeDateInChangelogEntry', () {
    test('should not include date by default', () {
      final changelogEntryDate = DateTime.now().toFormattedString();

      final workspace = buildWorkspaceWithRepository();
      final package = workspace.allPackages['test_pkg']!;
      final commit = testCommit(message: 'feat: a');

      expect(
        renderCommitPackageUpdate(workspace, package, commit),
        isNot(contains(changelogEntryDate)),
      );
    });

    test('should include date when enabled', () {
      final changelogEntryDate = DateTime.now().toFormattedString();

      final workspace = buildWorkspaceWithRepository(
        includeDateInChangelogEntry: true,
      );
      final package = workspace.allPackages['test_pkg']!;
      final commit = testCommit(message: 'feat: a');

      expect(
        renderCommitPackageUpdate(workspace, package, commit),
        contains(changelogEntryDate),
      );
    });
  });

  test('when repository is specified, adds links to referenced issues/PRs', () {
    final workspace = buildWorkspaceWithRepository();
    final package = workspace.allPackages['test_pkg']!;
    final commit = testCommit(message: 'feat: a (#123)');
    final issueUrl = workspace.config.repository!.issueUrl('123');

    expect(
      renderCommitPackageUpdate(workspace, package, commit),
      contains('**FEAT**: a ([#123]($issueUrl)).'),
    );
  });

  group('graduate', () {
    // Regression test for: https://github.com/invertase/melos/issues/782
    test('includes commits made since the pre-release in the changelog', () {
      final workspace = buildWorkspaceWithRepository();
      final package = workspace.allPackages['test_pkg']!;

      final markdown = renderGraduatePackageUpdate(workspace, package, [
        testCommit(message: 'feat: a new feature'),
        testCommit(message: 'fix: a bug fix'),
      ]);

      expect(markdown, contains('**FEAT**: a new feature.'));
      expect(markdown, contains('**FIX**: a bug fix.'));
      expect(
        markdown,
        isNot(contains('Graduate package to a stable release')),
      );
    });

    test('falls back to the pre-release note when there are no commits', () {
      final workspace = buildWorkspaceWithRepository();
      final package = workspace.allPackages['test_pkg']!;

      final markdown = renderGraduatePackageUpdate(workspace, package, []);

      expect(
        markdown,
        contains(
          'Graduate package to a stable release. See pre-releases prior to '
          'this version for changelog entries.',
        ),
      );
    });

    test('ignores non-versionable commits and shows the pre-release note', () {
      final workspace = buildWorkspaceWithRepository();
      final package = workspace.allPackages['test_pkg']!;

      final markdown = renderGraduatePackageUpdate(workspace, package, [
        testCommit(message: 'chore: not versionable'),
      ]);

      expect(
        markdown,
        contains('Graduate package to a stable release'),
      );
    });
  });
}

MelosWorkspace buildWorkspaceWithRepository({
  bool includeScopes = false,
  bool linkToCommits = false,
  bool includeCommitId = false,
  bool includeDateInChangelogEntry = false,
}) {
  final workspaceBuilder =
      VirtualWorkspaceBuilder(
        '''
    repository: https://github.com/a/b
    command:
      version:
        includeScopes: $includeScopes
        includeCommitId: $includeCommitId
        linkToCommits: $linkToCommits
        changelogFormat:
          includeDate: $includeDateInChangelogEntry
    ''',
      )..addPackage(
        '''
      name: test_pkg
      ''',
      );
  return workspaceBuilder.build();
}

RichGitCommit testCommit({required String message}) => RichGitCommit.tryParse(
  GitCommit(
    author: 'a',
    id: 'b2841394a48cd7d84a4966a788842690e543b2ef',
    date: DateTime.now(),
    message: message,
  ),
)!;

String renderCommitPackageUpdate(
  MelosWorkspace workspace,
  Package package,
  RichGitCommit commit,
) {
  final update = MelosPendingPackageUpdate(
    workspace,
    package,
    [commit],
    PackageUpdateReason.commit,
    logger: workspace.logger,
  );
  final changelog = MelosChangelog(update, workspace.logger);
  return changelog.markdown;
}

String renderGraduatePackageUpdate(
  MelosWorkspace workspace,
  Package package,
  List<RichGitCommit> commits,
) {
  final update = MelosPendingPackageUpdate(
    workspace,
    package,
    commits,
    PackageUpdateReason.graduate,
    graduate: true,
    logger: workspace.logger,
  );
  final changelog = MelosChangelog(update, workspace.logger);
  return changelog.markdown;
}
