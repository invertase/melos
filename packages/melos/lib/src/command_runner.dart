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

import 'package:ansi_styles/ansi_styles.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';

import 'command/bootstrap.dart';
import 'command/clean.dart';
import 'command/exec.dart';
import 'command/list.dart';
import 'command/publish.dart';
import 'command/run.dart';
import 'command/version.dart';
import 'common/logger.dart';
import 'common/utils.dart';
import 'common/workspace.dart';

final lineLength = stdout.hasTerminal ? stdout.terminalColumns : 80;

class MelosCommandRunner extends CommandRunner {
  static MelosCommandRunner instance = MelosCommandRunner();

  MelosCommandRunner()
      : super('melos', 'A CLI for Dart package development in monorepos.',
            usageLineLength: lineLength) {
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

    argParser.addFlag(
      filterOptionNoPrivate,
      negatable: false,
      help:
          'Exclude private packages (`publish_to: none`). They are included by default.',
    );

    argParser.addFlag(
      filterOptionPublished,
      negatable: true,
      defaultsTo: null,
      help:
          'Filter packages where the current local package version exists on pub.dev. Or "-no-published" to filter packages that have not had their current version published yet.',
    );

    argParser.addMultiOption(
      filterOptionScope,
      valueHelp: 'glob',
      help:
          'Include only packages with names matching the given glob. This option can be repeated.',
    );

    argParser.addMultiOption(
      filterOptionIgnore,
      valueHelp: 'glob',
      help:
          'Exclude packages with names matching the given glob. This option can be repeated.',
    );

    argParser.addOption(
      filterOptionSince,
      valueHelp: 'ref',
      help:
          'Only include packages that have been changed since the specified `ref`, e.g. a commit sha or git tag.',
    );

    argParser.addMultiOption(
      filterOptionDirExists,
      valueHelp: 'dirRelativeToPackageRoot',
      help:
          'Include only packages where a specific directory exists inside the package.',
    );

    argParser.addMultiOption(
      filterOptionFileExists,
      valueHelp: 'fileRelativeToPackageRoot',
      help:
          'Include only packages where a specific file exists in the package.',
    );

    addCommand(ExecCommand());
    addCommand(BootstrapCommand());
    addCommand(CleanCommand());
    addCommand(RunCommand());
    addCommand(ListCommand());
    addCommand(PublishCommand());
    addCommand(VersionCommand());
  }

  @override
  Future runCommand(ArgResults argResults) async {
    currentWorkspace = await MelosWorkspace.fromDirectory(Directory.current);

    if (currentWorkspace == null) {
      logger.stderr(AnsiStyles.red(
          'Your current directory does not appear to be a valid Melos workspace.'));
      logger.stderr(
          '\nYou must have one of the following to be a valid Melos workspace:');
      logger.stderr(
          '   - a "melos.yaml" file in the root with a "packages" option defined');
      logger.stderr('   - a "packages" directory');
      exitCode = 1;
      return;
    }

    String since = argResults[filterOptionSince] as String;
    // We ignore since package list filtering on the 'version' command as it
    // already filters it itself, filtering here would map dependant version fail
    // as it won't be aware of any packages that have been filtered out here
    // because of the 'since' filter.
    if (argResults != null &&
        argResults.command != null &&
        argResults.command.name == 'version') {
      since = null;
    }

    // Run command does not need to load workspace packages.
    // It can optionally self load with filters.
    if (argResults != null &&
        argResults.command != null &&
        argResults.command.name == 'run') {
      await super.runCommand(argResults);
      return;
    }

    if (Platform.environment.containsKey(envKeyMelosPackages)) {
      // MELOS_PACKAGES environment variable is a comma delimited list of
      // package names - used instead of filters if it is present.
      // This can be user defined or can come from package selection in `melos run`.
      await currentWorkspace.loadPackagesWithNames(
        Platform.environment[envKeyMelosPackages].split(','),
      );
    } else {
      await currentWorkspace.loadPackagesWithFilters(
        scope: argResults[filterOptionScope] as List<String>,
        since: since,
        skipPrivate: argResults[filterOptionNoPrivate] as bool,
        published: argResults[filterOptionPublished] as bool,
        ignore: (argResults[filterOptionIgnore] as List<String>)
          ..addAll(currentWorkspace.config.ignore),
        dirExists: argResults[filterOptionDirExists] as List<String>,
        fileExists: argResults[filterOptionFileExists] as List<String>,
      );
    }

    await super.runCommand(argResults);
  }
}
