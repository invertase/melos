import 'dart:convert';
import 'dart:io';

import '../logging.dart';
import 'platform.dart';
import 'utils.dart';

class PersistentShell {
  PersistentShell({
    required this.logger,
    this.workingDirectory,
  });

  final _isWindows = currentPlatform.isWindows;
  final MelosLogger logger;
  final String? workingDirectory;
  late final Process _process;

  /// This list is intended to store the commands that are sent to the shell.
  /// Currently, it is not being utilized in the code,
  ///TODO: remove this or actually use it
  final List<String> _commands = [];

  Future<void> startShell() async {
    final executable = _isWindows ? 'cmd.exe' : '/bin/sh';

    _process = await Process.start(
      executable,
      _isWindows ? ['/C'] : [],
      workingDirectory: workingDirectory,
    );

    _process.stdout.listen(
      (event) {
        logger.logWithoutNewLine(utf8.decode(event, allowMalformed: true));
      },
      onDone: () {
        /// TODO: Identify and log the specific steps that have been completed
        /// successfully.
        logger.success('Shell process completed some steps successfully.');
      },
    );
    _process.stderr.listen(
      (event) {
        logger.error(utf8.decode(event, allowMalformed: true));
      },
      onDone: () {
        /// TODO: Identify and log the specific steps that have completed
        /// with errors.
        logger.error('Shell process completed with errors.');
      },
    );
  }

  void sendCommand(String command) {
    _commands.add(command);

    final formattedScriptStep = targetStyle(
      command.addStepPrefixEmoji().withoutTrailing('\n'),
    );

    final echoCommand = 'echo "$formattedScriptStep"';

    final fullCommand = _isWindows
        ? '$echoCommand && $command'
        : 'eval "$echoCommand && $command"';

    _process.stdin.writeln(fullCommand);
  }

  Future<void> stopShell() async {
    await _process.stdin.close();
    await _process.exitCode;
  }
}
