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
    // /Q: quiet (suppress banner and command echoing)
    // /V:ON: enable delayed expansion so !ERRORLEVEL! reflects the actual
    // exit code of the previous command rather than being expanded at parse
    // time (a CMD gotcha when multiple commands are chained with &).
    final args = _isWindows ? ['/Q', '/V:ON'] : const <String>[];

    _process = await Process.start(
      executable,
      args,
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
      var output = utf8.decode(event, allowMalformed: true);
      if (_isWindows) {
        output = _cleanWindowsOutput(output);
        if (output.isEmpty) return;
      }
      logger.logAndCompleteBasedOnMarkers(
        output,
        _successEndMarker,
        _failureEndMarker,
        _commandCompleter,
        asError: isErrorStream,
      );
    });
  }

  // Strip CMD artifacts from output chunks on Windows:
  // - Normalize CRLF (\r\n) and lone CR (\r) to LF so that CRLF sequences
  //   split across stream chunks do not leave stray \r in logged output.
  // - Remove the Windows version banner lines that cmd.exe prints at startup.
  // - Strip the CMD prompt prefix (e.g. "C:\path>") that appears before each
  //   command's output because the prompt is written to stdout without a
  //   trailing newline.
  static String _cleanWindowsOutput(String output) {
    final normalized =
        output.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return normalized
        .split('\n')
        .where(
          (line) =>
              !line.startsWith('Microsoft Windows [Version') &&
              !line.startsWith('(c) Microsoft Corporation'),
        )
        .map((line) => line.replaceFirst(RegExp(r'^[A-Za-z]:\\[^>]*>'), ''))
        .join('\n');
  }

  String _buildFullCommand(String command) {
    final formattedScriptStep = targetStyle(
      command.addStepPrefixEmoji().withoutTrailing('\n'),
    );
    final echoSuccess = 'echo $_successEndMarker';
    final echoFailure = 'echo $_failureEndMarker';

    if (_isWindows) {
      // CMD includes outer quotes in echo output, so omit them here.
      // No space before the first & prevents a trailing space on the echo line.
      // !ERRORLEVEL! (delayed expansion) reads the exit code after $command
      // runs, not when the whole line is parsed by CMD.
      final echoCommand = 'echo $formattedScriptStep';
      // No space before & prevents trailing space in the command's echo output.
      return '$echoCommand&$command& '
          'if !ERRORLEVEL!==0 ($echoSuccess) else ($echoFailure)';
    }

    final echoCommand = 'echo "$formattedScriptStep"';
    return '$echoCommand && $command && $echoSuccess || $echoFailure';
  }
}
