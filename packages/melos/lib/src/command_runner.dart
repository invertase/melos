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

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'command_runner/bootstrap.dart';
import 'command_runner/clean.dart';
import 'command_runner/exec.dart';
import 'command_runner/list.dart';
import 'command_runner/publish.dart';
import 'command_runner/run.dart';
import 'command_runner/script.dart';
import 'command_runner/version.dart';
import 'common/utils.dart';
import 'workspace_configs.dart';

/// A class that can run Melos commands.
///
/// To run a command, do:
///
/// ```dart
/// final melos = MelosCommandRunner();
///
/// await melos.run(['bootstrap']);
/// ```
class MelosCommandRunner extends CommandRunner<void> {
  MelosCommandRunner(MelosWorkspaceConfig config)
      : super(
          'melos',
          'A CLI tool for managing Dart & Flutter projects with multiple packages.',
          usageLineLength: terminalWidth,
        ) {
    argParser.addFlag(
      globalOptionVerbose,
      negatable: false,
      help: 'Enable verbose logging.',
    );
    argParser.addOption(
      globalOptionSdkPath,
      help: 'Path to the Dart/Flutter SDK that should be used. This command '
          'line option has precedence over the `sdkPath` option in the '
          '`melos.yaml` configuration file and the `MELOS_SDK_PATH` '
          'environment variable. To use the system-wide SDK, provide '
          'the special value "auto".',
    );

    addCommand(ExecCommand(config));
    addCommand(BootstrapCommand(config));
    addCommand(CleanCommand(config));
    addCommand(RunCommand(config));
    addCommand(ListCommand(config));
    addCommand(PublishCommand(config));
    addCommand(VersionCommand(config));

    // Keep this last to exclude all built-in commands listed above
    final script = ScriptCommand.fromConfig(config, exclude: commands.keys);
    if (script != null) {
      addCommand(script);
    }
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    await super.runCommand(topLevelResults);
  }
}
