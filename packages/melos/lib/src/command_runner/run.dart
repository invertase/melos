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

import 'package:ansi_styles/ansi_styles.dart';

import '../commands/runner.dart';
import '../workspace_configs.dart';
import 'base.dart';

class RunCommand extends MelosCommand {
  RunCommand(MelosWorkspaceConfig config) : super(config) {
    argParser.addFlag(
      'no-select',
      negatable: false,
      help:
          'Skips the prompt to select a package (if defined in the script configuration). Filters defined in the scripts "select-package" options will however still be applied.',
    );
  }

  @override
  final String name = 'run';

  @override
  final String description =
      'Run a script by name defined in the workspace melos.yaml config file.';

  @override
  final String invocation = 'melos run <name>';

  @override
  Future<void> run() async {
    final melos = Melos(logger: logger, config: config);

    final noSelect = argResults!['no-select'] as bool;
    final scriptName = argResults!.rest.isEmpty ? null : argResults!.rest.first;
    final extraArgs =
        scriptName != null ? argResults!.rest.skip(1).toList() : <String>[];

    try {
      return await melos.run(
        global: global,
        scriptName: scriptName,
        noSelect: noSelect,
        extraArgs: extraArgs,
      );
    } on NoPackageFoundScriptException catch (err) {
      logger?.stderr(AnsiStyles.yellow(err.toString()));
      logger?.stdout(usage);
    }
  }
}
