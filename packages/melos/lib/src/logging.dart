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

  void log(String message) => stdout(message);

  void command(String command, {bool withDollarSign = false}) {
    if (withDollarSign) {
      stdout('${commandColor(r'$')} ${commandStyle(command)}');
    } else {
      stdout(commandColor(commandStyle(command)));
    }
  }

  void success(String message, {bool dryRun = false}) {
    if (dryRun) {
      stdout(successMessageColor(message));
    } else {
      stdout(successMessageColor(successStyle(message)));
    }
  }

  void warning(String message, {bool label = true, bool dryRun = false}) {
    final labelColor =
        dryRun ? dryRunWarningLabelColor : dryRunWarningMessageColor;
    final messageColor =
        dryRun ? dryRunWarningMessageColor : warningMessageColor;
    if (label) {
      stdout('$warningLabel${labelColor(':')} $message');
    } else {
      stdout(messageColor(message));
    }
  }

  void error(String message, {bool label = true}) {
    if (label) {
      stderr('$errorLabel${errorLabelColor(':')} $message');
    } else {
      stderr(errorMessageColor(message));
    }
  }

  void hint(String message, {bool label = true}) {
    if (label) {
      stdout(hintMessageColor('$hintLabel: $message'));
    } else {
      stdout(hintMessageColor(message));
    }
  }

  void newLine() => _logger.write('\n');

  void horizontalLine() => _logger.stdout('-' * terminalWidth);

  MelosLogger child(
    String message, {
    String prefix = '└> ',
    bool stderr = false,
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
        logger.stderr(prefixedLine);
      } else {
        logger.stdout(prefixedLine);
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
