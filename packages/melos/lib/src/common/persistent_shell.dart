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
  Completer<int>? _commandCompleter;
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
    _listenToProcessStream(_process.stderr, isErrorStream: true);
  }

  Future<int> sendCommand(String command) {
    assert(_commandCompleter == null, 'A command is already in progress.');
    _commandCompleter = Completer<int>();

    final fullCommand = _buildFullCommand(command);
    _process.stdin.writeln(fullCommand);

    return _awaitCommandCompletion();
  }

  Future<void> stopShell() async {
    await _process.stdin.flush();
    return _process.stdin.close();
  }

  Future<int> _awaitCommandCompletion() async {
    try {
      final exitCode = await _commandCompleter!.future;
      return exitCode;
    } catch (e) {
      return 1;
    } finally {
      _commandCompleter = null;
    }
  }

  void _listenToProcessStream(
    Stream<List<int>> stream, {
    bool isErrorStream = false,
  }) {
    stream.listen((event) {
      final output = utf8.decode(event, allowMalformed: true);
      logger.logAndCompleteBasedOnMarkers(
        output,
        _successEndMarker,
        _failureEndMarker,
        _commandCompleter,
        asError: isErrorStream,
      );
    });
  }

  String _buildFullCommand(String command) {
    final formattedScriptStep = targetStyle(
      command.addStepPrefixEmoji().withoutTrailing('\n'),
    );
    final echoCommand = 'echo "$formattedScriptStep"';
    final echoSuccess = 'echo $_successEndMarker';
    final echoFailure = 'echo $_failureEndMarker';

    if (_isWindows) {
      return '$echoCommand & $command & '
          'if %errorlevel%==0 ($echoSuccess) else ($echoFailure)';
    }

    return '$echoCommand && $command && $echoSuccess || $echoFailure';
  }
}
