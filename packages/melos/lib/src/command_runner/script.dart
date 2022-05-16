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

class ScriptCommand extends MelosCommand {
  ScriptCommand._(
    MelosWorkspaceConfig config, {
    required this.scripts,
  })  : assert(scripts.isNotEmpty),
        super(config) {
    argParser.addFlag(
      'no-select',
      negatable: false,
      help:
          'Skips the prompt to select a package (if defined in the script configuration). Filters defined in the scripts "select-package" options will however still be applied.',
    );
  }

  static ScriptCommand? fromConfig(
    MelosWorkspaceConfig config, {
    Iterable<String> exclude = const <String>[],
  }) {
    final scripts = config.scripts.keys.toSet();
    scripts.removeAll(exclude);
    if (scripts.isEmpty) {
      return null;
    }
    return ScriptCommand._(config, scripts: scripts);
  }

  final Set<String> scripts;

  @override
  String get name => scripts.first;

  @override
  List<String> get aliases => scripts.skip(1).toList();

  @override
  String get description =>
      'Run scripts by name defined in the workspace melos.yaml config file.';

  @override
  final String invocation = 'melos <script>';

  @override
  bool get hidden => true;

  @override
  Future<void> run() async {
    final melos = Melos(logger: logger, config: config);

    final scriptName = argResults!.name;
    final noSelect = argResults!['no-select'] as bool;

    try {
      return await melos.run(
        global: global,
        scriptName: scriptName,
        noSelect: noSelect,
      );
    } on NoPackageFoundScriptException catch (err) {
      logger?.stderr(AnsiStyles.yellow(err.toString()));
      logger?.stdout(usage);
    }
  }
}
