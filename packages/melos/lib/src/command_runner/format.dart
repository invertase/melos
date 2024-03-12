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
import 'base.dart';

class FormatCommand extends MelosCommand {
  FormatCommand(super.config) {
    setupPackageFilterParser();
    argParser.addOption('concurrency', defaultsTo: '1', abbr: 'c');
    argParser.addFlag(
      'set-exit-if-changed',
      negatable: false,
      help: 'Return exit code 1 if there are any formatting changes.',
    );
    argParser.addOption(
      'output',
      help: 'Set where to write formatted output.\n'
          '[json]               Print code and selection as JSON.\n'
          '[none]               Discard output.\n'
          '[show]               Print code to terminal.\n'
          '[write]              Overwrite formatted files on disk.\n',
      abbr: 'o',
    );
  }

  @override
  final String name = 'format';

  @override
  final String description = 'Idiomatically format Dart source code.';

  @override
  Future<void> run() async {
    final setExitIfChanged = argResults?['set-exit-if-changed'] as bool;
    final output = argResults?['output'] as String?;
    final concurrency = int.parse(argResults!['concurrency'] as String);

    final melos = Melos(logger: logger, config: config);

    return melos.format(
      global: global,
      packageFilters: parsePackageFilters(config.path),
      concurrency: concurrency,
      setExitIfChanged: setExitIfChanged,
      output: output,
    );
  }
}
