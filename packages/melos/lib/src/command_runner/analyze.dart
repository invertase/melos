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
import '../common/utils.dart';
import 'base.dart';

class AnalyzeCommand extends MelosCommand {
  AnalyzeCommand(super.config) {
    setupPackageFilterParser();
    argParser.addOption('concurrency', defaultsTo: '1', abbr: 'c');
    argParser.addFlag(
      'fatal-infos',
      negatable: false,
      help: 'Enables treating info-lever issues as fatal errors, '
          'stopping the process if any are encountered.',
    );

    argParser.addFlag(
      'fatal-warnings',
      help: 'Enables or disables treating warnings as fatal errors. '
          'When enabled, any warning will cause the command to fail.',
    );
  }

  @override
  final String name = 'analyze';

  @override
  final String description =
      'Analyzes all packages in your project for potential issues '
      'in a single run. Optionally configure severity levels. '
      'Supports all package filtering options.';

  @override
  Future<void> run() async {
    final fatalInfos = argResults?['fatal-infos'] as bool;
    final fatalWarnings = argResults!.optional('fatal-warnings') as bool?;
    final concurrency = int.parse(argResults!['concurrency'] as String);

    final melos = Melos(logger: logger, config: config);

    return melos.analyze(
      global: global,
      packageFilters: parsePackageFilters(config.path),
      concurrency: concurrency,
      fatalInfos: fatalInfos,
      fatalWarnings: fatalWarnings,
    );
  }
}
