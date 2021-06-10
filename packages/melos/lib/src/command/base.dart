import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../common/utils.dart';

abstract class MelosCommand extends Command<void> {
  /// The `melos.yaml` configuration for this command.
  /// see [ArgParser.allowTrailingOptions]
  bool get allowTrailingOptions => true;

  /// Overridden to support line wrapping when printing usage.
  @override
  late final ArgParser argParser = ArgParser(
    usageLineLength: terminalWidth,
    allowTrailingOptions: allowTrailingOptions,
  );
}
