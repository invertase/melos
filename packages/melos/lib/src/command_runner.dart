import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_launcher/cli_launcher.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pub_updater/pub_updater.dart';

import '../version.g.dart';
import 'command_runner/analyze.dart';
import 'command_runner/bootstrap.dart';
import 'command_runner/clean.dart';
import 'command_runner/exec.dart';
import 'command_runner/format.dart';
import 'command_runner/init.dart';
import 'command_runner/list.dart';
import 'command_runner/publish.dart';
import 'command_runner/run.dart';
import 'command_runner/script.dart';
import 'command_runner/test.dart';
import 'command_runner/version.dart';
import 'common/exception.dart';
import 'common/pub_hosted.dart';
import 'common/pub_hosted_package.dart';
import 'common/utils.dart' as utils;
import 'common/utils.dart';
import 'logging.dart';
import 'workspace_config.dart';

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
            'packages.\n\n'
            'To get started with Melos, run "melos init".',
        usageLineLength: terminalWidth,
      ) {
    argParser.addFlag(
      globalOptionVerbose,
      negatable: false,
      help: 'Enable verbose logging.',
    );
    argParser.addOption(
      globalOptionSdkPath,
      help:
          'Path to the Dart/Flutter SDK that should be used. This command '
          'line option has precedence over the `sdkPath` option in the '
          '`pubspec.yaml` configuration file and the `MELOS_SDK_PATH` '
          'environment variable. To use the system-wide SDK, provide '
          'the special value "auto".',
    );

    // Register custom scripts first so they can override built-in commands
    final script = ScriptCommand.fromConfig(config);
    final scriptNames = script?.scripts ?? <String>{};
    if (script != null) {
      addCommand(script);
    }

    // Create built-in commands
    final builtInCommands = [
      AnalyzeCommand(config),
      InitCommand(config),
      ExecCommand(config),
      BootstrapCommand(config),
      CleanCommand(config),
      RunCommand(config),
      ListCommand(config),
      PublishCommand(config),
      VersionCommand(config),
      FormatCommand(config),
      TestCommand(config),
    ];

    // Add built-in commands only if they don't conflict with custom scripts
    for (final command in builtInCommands) {
      if (!scriptNames.contains(command.name)) {
        addCommand(command);
      }
    }
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    await super.runCommand(topLevelResults);
  }
}

FutureOr<void> melosEntryPoint(
  List<String> arguments,
  LaunchContext context,
) async {
  if (arguments.contains('--version') || arguments.contains('-v')) {
    final logger = MelosLogger(Logger.standard());

    logger.log(melosVersion);

    // No version checks on CIs.
    if (utils.isCI) {
      return;
    }

    // Check for updates.
    const packageName = 'melos';
    final client = PubHostedClient.fromUri(pubHosted: null);
    PubHostedPackage? package;
    try {
      package = await client.fetchPackage(packageName, logger: logger);
    } finally {
      client.close();
    }

    final update = package?.newestCompatibleUpdate(
      currentVersion: Version.parse(melosVersion),
      dartSdkVersion: Version.parse(Platform.version.split(' ').first),
    );

    if (update != null) {
      final latestVersion = update.version;
      final isGlobal = context.localInstallation == null;

      if (isGlobal) {
        final shouldUpdate = utils.promptBool(
          message:
              'There is a new version of $packageName available '
              '($latestVersion). Would you like to update?',
          defaultsTo: true,
          defaultsToWithoutPrompt: false,
        );
        if (shouldUpdate) {
          await PubUpdater().update(
            packageName: packageName,
            versionConstraint: latestVersion.toString(),
          );
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
    final config = await _resolveConfig(
      arguments,
      context.localInstallation?.lockFileRoot,
      melosCommand: _resolveMelosCommand(context),
    );
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

/// Resolves the command used to invoke Melos itself for nested `melos`
/// invocations from scripts (e.g. `melos exec`).
///
/// When Melos is run from a local installation (e.g. as a `dev_dependency`) it
/// is not available on the `PATH`, so scripts that run nested Melos commands
/// would fail with "melos: command not found". In that case Melos is invoked
/// through the Dart SDK instead, mirroring how `cli_launcher` relaunches the
/// local installation. See https://github.com/invertase/melos/issues/511.
List<String> _resolveMelosCommand(LaunchContext context) {
  if (context.localInstallation == null) {
    return defaultMelosCommand;
  }
  return ['dart', 'run', 'melos:melos'];
}

Future<MelosWorkspaceConfig> _resolveConfig(
  List<String> arguments,
  Directory? workspaceRoot, {
  List<String> melosCommand = defaultMelosCommand,
}) async {
  if (_shouldUseEmptyConfig(arguments)) {
    return MelosWorkspaceConfig.empty();
  }
  if (workspaceRoot == null) {
    return MelosWorkspaceConfig.handleWorkspaceNotFound(Directory.current);
  }
  return MelosWorkspaceConfig.fromWorkspaceRoot(
    workspaceRoot,
    melosCommand: melosCommand,
  );
}

bool _shouldUseEmptyConfig(List<String> arguments) {
  if (arguments.firstOrNull == 'init') {
    return true;
  }
  final willShowHelp =
      arguments.isEmpty ||
      arguments.contains('--help') ||
      arguments.contains('-h');
  return willShowHelp;
}
