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

import 'package:args/command_runner.dart' show Command;

import '../common/logger.dart';

class AuditCommand extends Command {
  @override
  final String name = 'audit';

  @override
  final String description =
      'Audit the packages in this workspace. Provides information on general upkeep of the workspace such dependency versions.';

  @override
  void run() async {
    logger.stdout('Auditing workspace...');
    // Ideas:
    //  - Possible version issues of dependencies across all packages in the workspace,
    //     e.g. package_1 depends on "provider" >=v1.0.0 but package_2 depends on >=v1.1.0 of "provider".
    //  - Show platforms that each Flutter plugin in the workspace supports.
    //  - SDK constraints across all workspace packages.
    //  - Outdated dependencies.
    //  - Federated or not federated flutter plugins.
    //  - Android - minSDK/targetSDK variations.
    //  - Android - gradle wrapper version.
    // ... anything else?
  }
}
