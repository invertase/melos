import 'package:ansi_styles/ansi_styles.dart';
import 'package:cli_util/cli_logging.dart';

final _successColor = AnsiStyles.green;
final _warningColor = AnsiStyles.yellow;
final _errorColor = AnsiStyles.red;

final _labelStyle = AnsiStyles.bold;

final successLabel = _successColor(_labelStyle('SUCCESS'));
final warningLabel = _warningColor(_labelStyle('WARNING'));
final failedLabel = _errorColor(_labelStyle('FAILED'));
final checkLabel = AnsiStyles.greenBright('✓');

class MelosLogger with _DelegateLogger {
  MelosLogger(this._logger);

  @override
  final Logger _logger;

  void warning(String message, {bool label = true}) {
    if (label) {
      stderr('$warningLabel: $message');
    } else {
      stderr(_warningColor(message));
    }
  }
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
