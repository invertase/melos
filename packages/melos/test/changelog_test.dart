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
      'when enabled, and linkToCommits is also enabled adds link to commit'
      ' behind each one',
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
}

MelosWorkspace buildWorkspaceWithRepository({
  bool includeScopes = false,
  bool linkToCommits = false,
  bool includeCommitId = false,
}) {
  final workspaceBuilder = VirtualWorkspaceBuilder(
    '''
    repository: https://github.com/a/b
    command:
      version:
        includeScopes: $includeScopes
        includeCommitId: $includeCommitId
        linkToCommits: $linkToCommits
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
