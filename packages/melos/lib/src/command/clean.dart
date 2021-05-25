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

import '../common/intellij_project.dart';
import '../common/logger.dart';
import '../common/workspace.dart';
import 'base.dart';

class CleanCommand extends MelosCommand {
  @override
  final String name = 'clean';

  @override
  final String description = 'Clean this workspace and all packages. '
      'This deletes the temporary pub & ide files such as ".packages" & ".flutter-plugins". '
      'Supports all package filtering options.';

  @override
  Future<void> run() async {
    logger.stdout('Cleaning workspace...');

    currentWorkspace.clean();
    await IntellijProject.fromWorkspace(currentWorkspace).clean();

    if (currentWorkspace.config.scripts.exists('postclean')) {
      logger.stdout('Running postclean script...\n');

      await runner.run(['run', 'postclean']);
    }

    logger.stdout(
      '\nWorkspace cleaned. '
      'You will need to run the bootstrap command again to use this workspace.',
    );
  }
}
