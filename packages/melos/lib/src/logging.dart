import 'dart:async';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:cli_util/cli_logging.dart';

import 'common/utils.dart';

final commandColor = AnsiStyles.yellow;
final commandLabelColor = AnsiStyles.yellowBright;
final successMessageColor = AnsiStyles.green;
final successLableColor = AnsiStyles.greenBright;
final warningMessageColor = AnsiStyles.yellow;
final warningLabelColor = AnsiStyles.yellowBright;
final errorMessageColor = AnsiStyles.red;
final errorLabelColor = AnsiStyles.redBright;
final hintMessageColor = AnsiStyles.gray;
final hintLabelColor = AnsiStyles.gray;
final dryRunWarningMessageColor = AnsiStyles.magenta;
final dryRunWarningLabelColor = AnsiStyles.magentaBright;

final commandStyle = AnsiStyles.bold;
final successStyle = AnsiStyles.bold;
final labelStyle = AnsiStyles.bold;

final successLabel = successLableColor(labelStyle('SUCCESS'));
final warningLabel = warningLabelColor(labelStyle('WARNING'));
final errorLabel = errorLabelColor(labelStyle('ERROR'));
final failedLabel = errorLabelColor(labelStyle('FAILED'));
final canceledLabel = errorLabelColor(labelStyle('CANCELED'));
final hintLabel = hintLabelColor(labelStyle('HINT'));
final runningLabel = commandLabelColor(labelStyle('RUNNING'));
final checkLabel = AnsiStyles.greenBright('✓');

final targetStyle = AnsiStyles.cyan.bold;
final packagePathStyle = AnsiStyles.blue;
final packageNameStyle = AnsiStyles.bold;
final errorPackageNameStyle = AnsiStyles.yellow.bold;

/// CLI logger that encapsulates Melos log formatting conventions.
class MelosLogger with _DelegateLogger {
  MelosLogger(
    Logger logger, {
    String indentation = '',
    String childIndentation = '  ',
  })  : _logger = logger,
        _indentation = indentation,
        _childIndentation = childIndentation;

  @override
  final Logger _logger;
  final String _indentation;
  final String _childIndentation;

  void log(String message, {String? group}) {
    if (group != null) {
      _stdoutGroup(message, group);
      return;
    }

    stdout(message);
  }

  void logWithoutNewLine(String message, {String? group}) {
    if (group != null) {
      _writeGroup(message, group);
      return;
    }

    write(message);
  }

  void logAndCompleteBasedOnMarkers(
    String message,
    String successMarker,
    String failureMarker,
    Completer<void>? completer, {
    bool isError = false,
  }) {
    final modifiedMessage = _processMessageBasedOnMarkers(
      message,
      successMarker,
      failureMarker,
      completer,
    );
    _logMessage(modifiedMessage, isError);
  }

  String _processMessageBasedOnMarkers(
    String message,
    String successMarker,
    String failureMarker,
    Completer<void>? completer,
  ) {
    if (message.contains(successMarker)) {
      completer?.complete();
      return message.replaceAll(successMarker, '');
    }

    if (message.contains(failureMarker)) {
      completer?.complete();
      return message.replaceAll(failureMarker, '');
    }

    return message;
  }

  void _logMessage(String message, bool isError) {
    if (isError) {
      error(message);
    }
    write(message);
  }

  void command(String command, {bool withDollarSign = false}) {
    if (withDollarSign) {
      stdout('${commandColor(r'$')} ${commandStyle(command)}');
    } else {
      stdout(commandColor(commandStyle(command)));
    }
  }

  void success(String message, {String? group, bool dryRun = false}) {
    if (group != null) {
      if (dryRun) {
        _stdoutGroup(successMessageColor(message), group);
      } else {
        _stdoutGroup(successMessageColor(successStyle(message)), group);
      }

      return;
    }

    if (dryRun) {
      stdout(successMessageColor(message));
    } else {
      stdout(successMessageColor(successStyle(message)));
    }
  }

  void warning(
    String message, {
    String? group,
    bool label = true,
    bool dryRun = false,
  }) {
    final labelColor =
        dryRun ? dryRunWarningLabelColor : dryRunWarningMessageColor;
    final messageColor =
        dryRun ? dryRunWarningMessageColor : warningMessageColor;

    if (group != null) {
      if (label) {
        _stdoutGroup('$warningLabel${labelColor(':')} $message', group);
      } else {
        _stdoutGroup(messageColor(message), group);
      }

      return;
    }

    if (label) {
      stdout('$warningLabel${labelColor(':')} $message');
    } else {
      stdout(messageColor(message));
    }
  }

  void error(String message, {String? group, bool label = true}) {
    if (group != null) {
      if (label) {
        _stderrGroup('$errorLabel${errorLabelColor(':')} $message', group);
      } else {
        _stderrGroup(errorMessageColor(message), group);
      }

      return;
    }

    if (label) {
      stderr('$errorLabel${errorLabelColor(':')} $message');
    } else {
      stderr(errorMessageColor(message));
    }
  }

  void hint(String message, {String? group, bool label = true}) {
    if (group != null) {
      if (label) {
        _stdoutGroup('$hintLabel${hintLabelColor(':')} $message', group);
      } else {
        _stdoutGroup(hintMessageColor(message), group);
      }

      return;
    }

    if (label) {
      stdout(hintMessageColor('$hintLabel: $message'));
    } else {
      stdout(hintMessageColor(message));
    }
  }

  void newLine({String? group}) {
    if (group != null) {
      _stdoutGroup('', group);
      return;
    }

    _logger.stdout('');
  }

  void horizontalLine({String? group}) {
    if (group != null) {
      _stdoutGroup('-' * terminalWidth, group);
      return;
    }

    _logger.stdout('-' * terminalWidth);
  }

  MelosLogger child(
    String message, {
    String prefix = '└> ',
    bool stderr = false,
    String? group,
  }) {
    final childIndentation = ' ' * AnsiStyles.strip(prefix).length;
    final logger = MelosLogger(
      _logger,
      indentation: '$_indentation$_childIndentation',
      childIndentation: childIndentation,
    );

    final lines = message.split('\n');
    var isFirstLine = true;
    for (final line in lines) {
      final prefixedLine = '${isFirstLine ? prefix : childIndentation}$line';
      if (stderr) {
        logger.error(prefixedLine, group: group, label: false);
      } else {
        logger.log(prefixedLine, group: group);
      }
      isFirstLine = false;
    }

    return logger;
  }

  MelosLogger childWithoutMessage({String childIndentation = '  '}) =>
      MelosLogger(
        _logger,
        indentation: '$_indentation$_childIndentation',
        childIndentation: childIndentation,
      );

  @override
  void stdout(String message) => _logger.stdout('$_indentation$message');

  @override
  void stderr(String message) => _logger.stderr('$_indentation$message');

  @override
  void trace(String message) => _logger.trace('$_indentation$message');

  final _groupBuffer = <String, List<_GroupBufferMessage>>{};

  void _stdoutGroup(String message, String group) {
    final previous = _groupBuffer[group] ?? const [];
    _groupBuffer[group] = [...previous, _GroupBufferStdoutMessage(message)];
  }

  void _stderrGroup(String message, String group) {
    final previous = _groupBuffer[group] ?? const [];
    _groupBuffer[group] = [...previous, _GroupBufferStderrMessage(message)];
  }

  void _writeGroup(String message, String group) {
    final previous = _groupBuffer[group] ?? const [];
    _groupBuffer[group] = [...previous, _GroupBufferWriteMessage(message)];
  }

  void flushGroupBufferIfNeed() {
    for (final entry in _groupBuffer.entries) {
      for (final value in entry.value) {
        switch (value) {
          case _GroupBufferStdoutMessage(:final message):
            stdout(message);
          case _GroupBufferStderrMessage(:final message):
            stderr(message);
          case _GroupBufferWriteMessage(:final message):
            write(message);
        }
      }
    }

    _groupBuffer.clear();
  }
}

sealed class _GroupBufferMessage {
  const _GroupBufferMessage(this.message);

  final String message;
}

class _GroupBufferStdoutMessage extends _GroupBufferMessage {
  const _GroupBufferStdoutMessage(super.message);
}

class _GroupBufferStderrMessage extends _GroupBufferMessage {
  const _GroupBufferStderrMessage(super.message);
}

class _GroupBufferWriteMessage extends _GroupBufferMessage {
  const _GroupBufferWriteMessage(super.message);
}

mixin _DelegateLogger implements Logger {
  Logger get _logger;

  @override
  Ansi get ansi => _logger.ansi;

  @override
  bool get isVerbose => _logger.isVerbose;

  @override
  void stdout(String message) => _logger.stdout(message);

  @override
  void stderr(String message) => _logger.stderr(message);

  @override
  void trace(String message) => _logger.trace(message);

  @override
  Progress progress(String message) => _logger.progress(message);

  @override
  void write(String message) => _logger.write(message);

  @override
  void writeCharCode(int charCode) => _logger.writeCharCode(charCode);

  @override
  // ignore: deprecated_member_use
  void flush() => _logger.flush();
}

extension ToMelosLoggerExtension on Logger {
  MelosLogger toMelosLogger() {
    final self = this;
    if (self is MelosLogger) {
      return self;
    }
    return MelosLogger(this);
  }
}
