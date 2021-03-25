import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../common/utils.dart';

abstract class MelosCommand extends Command {
  /// Overridden to support line wrapping when printing usage.
  @override
  ArgParser get argParser =>
      _argParser ??= ArgParser(usageLineLength: terminalWidth);
  ArgParser _argParser;
}
