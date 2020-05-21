import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';

import 'command/bootstrap.dart';
import 'command/clean.dart';
import 'command/exec.dart';
import 'common/logger.dart';
import 'common/workspace.dart';

final lineLength = stdout.hasTerminal ? stdout.terminalColumns : 80;

class MelosCommandRunner extends CommandRunner {
  MelosCommandRunner()
      : super('melos', 'A CLI for package development in monorepos.',
            usageLineLength: lineLength) {
    argParser.addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Enable verbose logging.');

    argParser.addFlag('no-private',
        negatable: false,
        help:
            'Exclude private packages (`publish_to: none`). They are included by default.');

    argParser.addMultiOption('scope',
        help: 'Include only packages with names matching the given glob.');

    argParser.addMultiOption('ignore',
        help: 'Exclude packages with names matching the given glob.');

    addCommand(ExecCommand());
    addCommand(BootstrapCommand());
    addCommand(CleanCommand());
  }

  @override
  Future runCommand(ArgResults argResults) async {
    if (argResults['verbose'] != null) {
      logger = Logger.verbose();
    }

    currentWorkspace = await MelosWorkspace.fromDirectory(Directory.current,
        arguments: argResults);

    if (currentWorkspace == null) {
      // TODO log init help?
      logger.stderr(
          'Your current directory does not appear to be a valid workspace.');
      exit(1);
    }

    await currentWorkspace.loadPackages(
        scope: argResults['scope'] as List<String>,
        ignore: argResults['ignore'] as List<String>);

    await super.runCommand(argResults);
  }
}
