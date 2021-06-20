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

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';

import 'command_runner/bootstrap.dart';
import 'command_runner/clean.dart';
import 'command_runner/exec.dart';
import 'command_runner/list.dart';
import 'command_runner/publish.dart';
import 'command_runner/run.dart';
import 'command_runner/version.dart';
import 'common/logger.dart';
import 'common/utils.dart';

/// A class that can run Melos commands.
///
/// To run a command, do:
///
/// ```dart
/// final melos = MelosCommandRunner();
///
/// await melos.run(['boostrap']);
/// ```
class MelosCommandRunner extends CommandRunner<void> {
  MelosCommandRunner()
      : super(
          'melos',
          'A CLI tool for managing Dart & Flutter projects with multiple packages.',
          usageLineLength: terminalWidth,
        ) {
    argParser.addFlag(
      'verbose',
      callback: (bool enabled) {
        if (enabled) {
          logger = Logger.verbose();
        }
      },
      negatable: false,
      help: 'Enable verbose logging.',
    );

    addCommand(ExecCommand());
    addCommand(BootstrapCommand());
    addCommand(CleanCommand());
    addCommand(RunCommand());
    addCommand(ListCommand());
    addCommand(PublishCommand());
    addCommand(VersionCommand());
  }
}
