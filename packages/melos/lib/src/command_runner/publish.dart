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

import '../commands/runner.dart';
import '../workspace_configs.dart';
import 'base.dart';

class PublishCommand extends MelosCommand {
  PublishCommand(MelosWorkspaceConfig config) : super(config) {
    setupPackageFilterParser();
    argParser.addFlag(
      'dry-run',
      abbr: 'n',
      defaultsTo: true,
      help: 'Validate but do not publish the package.',
    );
    argParser.addFlag(
      'git-tag-version',
      abbr: 't',
      negatable: false,
      help: 'Add any missing git tags for release. '
          'Note tags are only created if --no-dry-run is also set.',
    );
    argParser.addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Skip the Y/n confirmation prompt when using --no-dry-run.',
    );
  }

  @override
  final String name = 'publish';

  @override
  final String description =
      'Publish any unpublished packages or package versions in your repository to pub.dev. '
      'Dry run is on by default.';

  @override
  Future<void> run() async {
    final dryRun = argResults!['dry-run'] as bool;
    final gitTagVersion = argResults!['git-tag-version'] as bool;
    final yes = argResults!['yes'] as bool || false;

    final melos = Melos(logger: logger, config: config);
    final filter = parsePackageFilter(config.path);

    return melos.publish(
      global: global,
      filter: filter,
      dryRun: dryRun,
      force: yes,
      gitTagVersion: gitTagVersion,
    );
  }
}
