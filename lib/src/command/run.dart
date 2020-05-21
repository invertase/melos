import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart' show Command;

import '../common/logger.dart';
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
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos run ${argResults.arguments[0]}")}');

    if (argResults.arguments == null) {
      logger.stderr('Invalid run script name specified.\n');
      logger.stdout(usage);
      exit(1);
    }

    if (currentWorkspace.config.scripts.isEmpty) {
      logger.stderr('You have no scripts defined in your melos.yaml file.\n');
      logger.stdout(usage);
      exit(1);
    }

    var scriptName = argResults.arguments[0];
    if (!currentWorkspace.config.scripts.containsKey(scriptName)) {
      logger.stderr('Invalid run script name specified.\n');
      logger.stdout(usage);
      exit(1);
    }

    var scriptSource = currentWorkspace.config.scripts[scriptName] as String;
    var scriptParts = scriptSource.split(' ');

    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(scriptSource)}${logger.ansi.noColor}\n');

    final execProcess = await Process.start(
        scriptParts[0], scriptParts.sublist(1),
        workingDirectory: currentWorkspace.path,
        runInShell: true,
        includeParentEnvironment: true,
        environment: {
          'MELOS_ROOT_PATH': currentWorkspace.path,
        });

    var stdoutSub;
    var stderrSub;

    var stdoutCompleteFuture = Completer();
    var stderrCompleteFuture = Completer();
    stdoutSub = execProcess.stdout
        .listen(stdout.add, onDone: stdoutCompleteFuture.complete);
    stderrSub = execProcess.stderr
        .listen(stderr.add, onDone: stderrCompleteFuture.complete);

    await stdoutCompleteFuture.future;
    await stderrCompleteFuture.future;

    await stdoutSub.cancel();
    await stderrSub.cancel();
  }
}
