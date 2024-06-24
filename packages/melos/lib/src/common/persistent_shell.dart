import 'dart:async';
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
  Completer<void>? _commandCompleter;

  Future<void> startShell() async {
    final executable = _isWindows ? 'cmd.exe' : '/bin/sh';

    _process = await Process.start(
      executable,
      _isWindows ? ['/C'] : [],
      workingDirectory: workingDirectory,
    );

    _process.stdout.listen((event) {
      final output = utf8.decode(event, allowMalformed: true);
      logger.logWithoutNewLine(output);
      _commandCompleter?.complete();
    });
    _process.stderr.listen((event) {
      logger.error(utf8.decode(event, allowMalformed: true));
      _commandCompleter?.completeError('Command failed');
    });
  }

  Future<bool> sendCommand(String command) async {
    assert(_commandCompleter == null, 'A command is already in progress.');
    _commandCompleter = Completer<void>();

    final fullCommand = _buildFullCommand(command);
    _process.stdin.writeln(fullCommand);

    return _awaitCommandCompletion();
  }

  Future<void> stopShell() async {
    await _process.stdin.close();
    final exitCode = await _process.exitCode;
    if (exitCode == 0) {
      logger.log(successLabel);
      return;
    }
    logger.log(failedLabel);
  }

  Future<bool> _awaitCommandCompletion() async {
    try {
      await _commandCompleter!.future;
      return true;
    } catch (e) {
      return false;
    } finally {
      _commandCompleter = null;
    }
  }

  String _buildFullCommand(String command) {
    final formattedScriptStep =
        targetStyle(command.addStepPrefixEmoji().withoutTrailing('\n'));

    final echoCommand = 'echo "$formattedScriptStep"';

    if (_isWindows) {
      return '$echoCommand && $command';
    }

    return 'eval "$echoCommand && $command"';
  }
}
