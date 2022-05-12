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
  group('linkToCommits', () {
    test('when enabled, adds link to commit behind each one', () {
      final workspace = buildWorkspaceWithRepository();
      final package = workspace.allPackages['test_pkg']!;
      final commit = testCommit(message: 'feat(a): b');
      final commitUrl = workspace.config.repository!.commitUrl(commit.id);

      expect(
        renderCommitPackageUpdate(workspace, package, commit),
        contains('**FEAT**: b. ([${commit.id.substring(0, 8)}]($commitUrl))'),
      );
    });
  });

  test('when repository is specified, adds links to referenced issues/PRs', () {
    final workspace = buildWorkspaceWithRepository(linkToCommits: false);
    final package = workspace.allPackages['test_pkg']!;
    final commit = testCommit(message: 'feat(a): b (#123)');
    final issueUrl = workspace.config.repository!.issueUrl('123');

    expect(
      renderCommitPackageUpdate(workspace, package, commit),
      contains('**FEAT**: b ([#123]($issueUrl)).'),
    );
  });
}

MelosWorkspace buildWorkspaceWithRepository({bool linkToCommits = true}) {
  final workspaceBuilder = VirtualWorkspaceBuilder(
    '''
    repository: https://github.com/a/b
    command:
      version:
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
