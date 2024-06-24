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

    _process.stdout.listen(
      (event) {
        final output = utf8.decode(event, allowMalformed: true);
        _handleCommandCompletion(output);
        logger.logWithoutNewLine(output);
      },
    );
    _process.stderr.listen(
      (event) {
        logger.error(utf8.decode(event, allowMalformed: true));
      },
    );
  }

  Future<void> sendCommand(String command) async {
    assert(_commandCompleter == null, 'A command is already in progress.');
    _commandCompleter = Completer<void>();

    final fullCommand = _buildFullCommand(command);
    _process.stdin.writeln(fullCommand);

    await _commandCompleter!.future;
    _commandCompleter = null;
  }

  Future<void> stopShell() async {
    await _process.stdin.close();
    await _process.exitCode;
  }

  String _buildFullCommand(String command) {
    final formattedScriptStep =
        targetStyle(command.addStepPrefixEmoji().withoutTrailing('\n'));

    final echoCommand = 'echo "$formattedScriptStep"';
    final echoRunning = 'echo $runningLabel';
    final echoSuccess = 'echo $successLabel';
    final echoFailure = 'echo $failedLabel';

    if (_isWindows) {
      return '''
        $echoCommand && $echoRunning && $command && if %ERRORLEVEL%==0 
            ($echoSuccess) else ($echoFailure || true)
      ''';
    }

    return '''
      eval "$echoCommand && $echoRunning && $command && if [ \$? -eq 0 ]; 
      then $echoSuccess; else $echoFailure; fi || true"
    ''';
  }

  void _handleCommandCompletion(String output) {
    if (output.contains(successLabel)) {
      _commandCompleter?.complete();
    } else if (output.contains(failedLabel)) {
      _commandCompleter?.completeError('Command failed');
    }
  }
}
