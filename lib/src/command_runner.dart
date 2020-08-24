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

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:melos/src/command/unpublished.dart';

import 'command/bootstrap.dart';
import 'command/clean.dart';
import 'command/exec.dart';
import 'command/run.dart';
import 'common/logger.dart';
import 'common/workspace.dart';

final lineLength = stdout.hasTerminal ? stdout.terminalColumns : 80;

class MelosCommandRunner extends CommandRunner {
  static MelosCommandRunner instance = MelosCommandRunner();

  MelosCommandRunner()
      : super('melos', 'A CLI for package development in monorepos.',
            usageLineLength: lineLength) {
    argParser.addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Enable verbose logging.');

    argParser.addFlag('no-private',
        negatable: false,
        help:
            'Exclude private packages (`publish_to: none`). They are included by default.');

    argParser.addFlag('published',
        negatable: true,
        defaultsTo: null,
        help:
            'Filter packages where the current local package version exists on pub.dev. Or "-no-published" to filter packages that have not had their current version published yet.');

    argParser.addMultiOption('scope',
        help: 'Include only packages with names matching the given glob.');

    argParser.addMultiOption('ignore',
        help: 'Exclude packages with names matching the given glob.');

    argParser.addMultiOption('dir-exists',
        help:
            'Include only packages where a specific directory exists inside the package.');

    argParser.addMultiOption('file-exists',
        help:
            'Include only packages where a specific file exists in the package.');

    addCommand(ExecCommand());
    addCommand(BootstrapCommand());
    addCommand(CleanCommand());
    addCommand(RunCommand());
    addCommand(UnpublishedCommand());
  }

  @override
  Future runCommand(ArgResults argResults) async {
    if (argResults['verbose'] == true) {
      logger = Logger.verbose();
    }

    currentWorkspace = await MelosWorkspace.fromDirectory(Directory.current,
        arguments: argResults);

    if (currentWorkspace == null) {
      // TODO(salakar): log init help once init command complete
      logger.stderr(
          'Your current directory does not appear to be a valid workspace.');
      logger.stderr('Does the "melos.yaml" file exist in the root?');
      exitCode = 1;
      return;
    }

    // TODO(Salakar): Optimise this, this causes the greatest startup delay currently.
    await currentWorkspace.loadPackages(
      scope: argResults['scope'] as List<String>,
      skipPrivate: argResults['no-private'] as bool,
      published: argResults['published'] as bool,
      ignore: argResults['ignore'] as List<String>,
      dirExists: argResults['dir-exists'] as List<String>,
      fileExists: argResults['file-exists'] as List<String>,
    );

    await super.runCommand(argResults);
  }
}
