import 'dart:io';

import 'package:args/command_runner.dart' show Command;
import 'package:prompts/prompts.dart' as prompts;

import '../common/logger.dart';
import '../common/utils.dart';
import '../common/workspace.dart';

class RunCommand extends Command {
  @override
  final String name = 'run';

  @override
  final List<String> aliases = ['r'];

  @override
  final String description =
      'Run a script by name defined in the workspace melos.yaml config file.';

  @override
  final String invocation = 'melos run <name>';

  RunCommand();

  @override
  void run() async {
    var scriptName;
    if (argResults.arguments.isEmpty) {
      logger.stderr('Invalid run script name specified.\n');
      if (currentWorkspace.config.scripts.isNotEmpty) {
        scriptName = prompts.choose(
            'Select a script to run:', currentWorkspace.config.scripts.keys,
            defaultsTo: currentWorkspace.config.scripts.keys.first);
        logger.stdout('');
      } else {
        logger.stderr('You have no scripts defined in your melos.yaml file.\n');
        logger.stdout(usage);
        exit(1);
      }
    }

    if (currentWorkspace.config.scripts.isEmpty) {
      logger.stderr('You have no scripts defined in your melos.yaml file.\n');
      logger.stdout(usage);
      exit(1);
    }

    scriptName ??= argResults.arguments[0];

    if (!currentWorkspace.config.scripts.containsKey(scriptName)) {
      logger.stderr('Invalid run script name specified.\n');
      if (currentWorkspace.config.scripts.isNotEmpty) {
        logger.stdout('Available scripts:');
        currentWorkspace.config.scripts.keys.forEach((key) {
          logger.stdout(' - ${logger.ansi.blue}$key${logger.ansi.noColor}');
        });
        logger.stdout('');
      }
      logger.stdout(usage);
      exit(1);
    }

    var scriptSource = currentWorkspace.config.scripts[scriptName] as String;
    var scriptParts = scriptSource.split(' ');

    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos run $scriptName")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(scriptSource.replaceAll('\n', ''))}${logger.ansi.noColor}');
    logger.stdout(
        '       └> ${logger.ansi.yellow}${logger.ansi.emphasized('RUNNING')}${logger.ansi.noColor}\n');

    var environment = {
      'MELOS_ROOT_PATH': currentWorkspace.path,
    };

    int exitCode = await startProcess(scriptParts,
        environment: environment, workingDirectory: currentWorkspace.path);

    logger.stdout('');
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos run $scriptName")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(scriptSource.replaceAll('\n', ''))}${logger.ansi.noColor}');

    if (exitCode > 0) {
      logger.stdout(
          '       └> ${logger.ansi.red}${logger.ansi.emphasized('FAILED')}${logger.ansi.noColor}');
      exit(exitCode);
    } else {
      logger.stdout(
          '       └> ${logger.ansi.green}${logger.ansi.emphasized('SUCCESS')}${logger.ansi.noColor}');
    }
  }
}
