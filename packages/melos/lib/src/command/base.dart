import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../common/utils.dart';
import '../common/workspace.dart';
import '../common/workspace_command_config.dart';

abstract class MelosCommand extends Command {
  /// The `melos.yaml` configuration for this command.
  ///
  /// This is the configuration under the `melos.yaml`'s `command.{name}` field.
  /// If none exists, a configuration object with no contents is returned.
  MelosCommandConfig get commandConfig =>
      currentWorkspace.config.commands.configForCommandNamed(name);

  /// Overridden to support line wrapping when printing usage.
  @override
  ArgParser get argParser =>
      _argParser ??= ArgParser(usageLineLength: terminalWidth);
  ArgParser _argParser;
}
