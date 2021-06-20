import 'package:cli_util/cli_logging.dart';

class TestLogger extends StandardLogger {
  final List<String> errs = [];
  final List<String> logs = [];
  final List<String> traces = [];

  @override
  void stderr(String message) {
    errs.add(message);
  }

  @override
  void stdout(String message) {
    logs.add('$message\n');
  }

  @override
  void trace(String message) {
    traces.add(message);
  }

  @override
  void write(String message) {
    logs.add(message);
  }

  @override
  void writeCharCode(int charCode) {
    throw UnimplementedError();
  }
}
