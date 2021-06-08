import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../common/utils.dart';

abstract class MelosCommand extends Command<void> {
  /// Overridden to support line wrapping when printing usage.
  @override
  late final ArgParser argParser = ArgParser(usageLineLength: terminalWidth);
}
