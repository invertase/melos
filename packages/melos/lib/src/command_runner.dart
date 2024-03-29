import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_launcher/cli_launcher.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:pub_updater/pub_updater.dart';

import '../version.g.dart';
import 'command_runner/analyze.dart';
import 'command_runner/bootstrap.dart';
import 'command_runner/clean.dart';
import 'command_runner/exec.dart';
import 'command_runner/format.dart';
import 'command_runner/list.dart';
import 'command_runner/publish.dart';
import 'command_runner/run.dart';
import 'command_runner/script.dart';
import 'command_runner/version.dart';
import 'common/exception.dart';
import 'common/utils.dart' as utils;
import 'common/utils.dart';
import 'logging.dart';
import 'workspace_configs.dart';

/// A class that can run Melos commands.
///
/// To run a command, do:
///
/// ```dart
/// final melos = MelosCommandRunner();
///
/// await melos.run(['bootstrap']);
/// ```
class MelosCommandRunner extends CommandRunner<void> {
  MelosCommandRunner(MelosWorkspaceConfig config)
      : super(
          'melos',
          'A CLI tool for managing Dart & Flutter projects with multiple '
              'packages.',
          usageLineLength: terminalWidth,
        ) {
    argParser.addFlag(
      globalOptionVerbose,
      negatable: false,
      help: 'Enable verbose logging.',
    );
    argParser.addOption(
      globalOptionSdkPath,
      help: 'Path to the Dart/Flutter SDK that should be used. This command '
          'line option has precedence over the `sdkPath` option in the '
          '`melos.yaml` configuration file and the `MELOS_SDK_PATH` '
          'environment variable. To use the system-wide SDK, provide '
          'the special value "auto".',
    );

    addCommand(ExecCommand(config));
    addCommand(BootstrapCommand(config));
    addCommand(CleanCommand(config));
    addCommand(RunCommand(config));
    addCommand(ListCommand(config));
    addCommand(PublishCommand(config));
    addCommand(VersionCommand(config));
    addCommand(AnalyzeCommand(config));
    addCommand(FormatCommand(config));

    // Keep this last to exclude all built-in commands listed above
    final script = ScriptCommand.fromConfig(config, exclude: commands.keys);
    if (script != null) {
      addCommand(script);
    }
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    await super.runCommand(topLevelResults);
  }
}

@override
FutureOr<void> melosEntryPoint(
  List<String> arguments,
  LaunchContext context,
) async {
  if (arguments.contains('--version') || arguments.contains('-v')) {
    final logger = MelosLogger(Logger.standard());

    logger.log(melosVersion);

    // No version checks on CIs.
    if (utils.isCI) return;

    // Check for updates.
    final pubUpdater = PubUpdater();
    const packageName = 'melos';
    final isUpToDate = await pubUpdater.isUpToDate(
      packageName: packageName,
      currentVersion: melosVersion,
    );
    if (!isUpToDate) {
      final latestVersion = await pubUpdater.getLatestVersion(packageName);
      final isGlobal = context.localInstallation == null;

      if (isGlobal) {
        final shouldUpdate = utils.promptBool(
          message: 'There is a new version of $packageName available '
              '($latestVersion). Would you like to update?',
          defaultsTo: true,
          defaultsToWithoutPrompt: false,
        );
        if (shouldUpdate) {
          await pubUpdater.update(packageName: packageName);
          logger.log(
            '$packageName has been updated to version $latestVersion.',
          );
        }
      } else {
        logger.log(
          'There is a new version of $packageName available '
          '($latestVersion).',
        );
      }
    }
    return;
  }
  try {
    final config =
        await _resolveConfig(arguments, context.localInstallation?.packageRoot);
    await MelosCommandRunner(config).run(arguments);
  } on MelosException catch (err) {
    stderr.writeln(err.toString());
    exitCode = 1;
  } on UsageException catch (err) {
    stderr.writeln(err.toString());
    exitCode = 1;
  } catch (err) {
    exitCode = 1;
    rethrow;
  }
}

Future<MelosWorkspaceConfig> _resolveConfig(
  List<String> arguments,
  Directory? workspaceRoot,
) async {
  if (_shouldUseEmptyConfig(arguments)) {
    return MelosWorkspaceConfig.empty();
  }
  if (workspaceRoot == null) {
    return MelosWorkspaceConfig.handleWorkspaceNotFound(Directory.current);
  }
  return MelosWorkspaceConfig.fromWorkspaceRoot(workspaceRoot);
}

bool _shouldUseEmptyConfig(List<String> arguments) {
  final willShowHelp = arguments.isEmpty ||
      arguments.contains('--help') ||
      arguments.contains('-h');
  return willShowHelp;
}
