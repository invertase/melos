import 'dart:io';

import 'package:args/command_runner.dart' show Command;
import 'package:melos_cli/src/common/workspace.dart';
import 'package:pool/pool.dart' show Pool;

import '../common/package.dart';

class ExecCommand extends Command {
  @override
  final String name = 'exec';

  @override
  final List<String> aliases = ['e'];

  @override
  final String description = 'Execute an arbitrary command in each package.';

  ExecCommand() {
    argParser.addOption('concurrency', defaultsTo: '5', abbr: 'c');
    argParser.addFlag('stream',
        abbr: 's',
        defaultsTo: false,
        negatable: false,
        help:
            'Stream output from child processes immediately, prefixed with the originating package name. This allows output from different packages to be interleaved.');
  }

  @override
  void run() async {
    final execArgs = argResults.rest;

    if (execArgs.isEmpty) {
      print(description);
      print(argParser.usage);
      exit(1);
    }

    final pool = Pool(int.parse(argResults['concurrency'] as String));

    await pool
        .forEach<MelosPackage, void>(currentWorkspace.packages,
            (package) => package.exec(execArgs, stream: argResults['stream']))
        .drain();
  }
}
