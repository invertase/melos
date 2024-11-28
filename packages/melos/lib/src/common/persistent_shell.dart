import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../logging.dart';
import 'environment_variable_key.dart';
import 'platform.dart';
import 'utils.dart';

class PersistentShell {
  PersistentShell({
    required this.logger,
    required this.environment,
    this.workingDirectory,
  });

  final _isWindows = currentPlatform.isWindows;
  final MelosLogger logger;
  final Map<String, String> environment;
  final String? workingDirectory;
  late final Process _process;
  Completer<void>? _commandCompleter;
  final String _successEndMarker = '__SUCCESS_COMMAND_END__';
  final String _failureEndMarker = '__FAILURE_COMMAND_END__';

  Future<void> startShell() async {
    final executable = _isWindows ? 'cmd.exe' : '/bin/sh';

    _process = await Process.start(
      executable,
      [],
      workingDirectory: workingDirectory,
      environment: {
        ...environment,
        EnvironmentVariableKey.melosTerminalWidth: terminalWidth.toString(),
      },
    );

    _listenToProcessStream(_process.stdout);
    _listenToProcessStream(_process.stderr, isError: true);
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

  void _listenToProcessStream(
    Stream<List<int>> stream, {
    bool isError = false,
  }) {
    stream.listen((event) {
      final output = utf8.decode(event, allowMalformed: true);
      logger.logAndCompleteBasedOnMarkers(
        output,
        _successEndMarker,
        _failureEndMarker,
        _commandCompleter,
        isError: isError,
      );
    });
  }

  String _buildFullCommand(String command) {
    final formattedScriptStep =
        targetStyle(command.addStepPrefixEmoji().withoutTrailing('\n'));
    final echoCommand = 'echo "$formattedScriptStep"';
    final echoSuccess = 'echo $_successEndMarker';
    final echoFailure = 'echo $_failureEndMarker';

    if (_isWindows) {
      return '''
      $echoCommand && $command || VER>NUL && if %ERRORLEVEL% NEQ 0 ($echoFailure) else ($echoSuccess)
    ''';
    }

    return '''
   $echoCommand && $command || true && if [ \$? -ne 0 ]; 
    then $echoFailure; else $echoSuccess; fi
  ''';
  }
}
