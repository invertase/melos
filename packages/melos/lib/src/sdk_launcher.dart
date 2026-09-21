import 'dart:io';

import 'package:args/args.dart';
import 'package:cli_launcher/cli_launcher.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'common/environment_variable_key.dart';
import 'common/io.dart';
import 'common/platform.dart';
import 'common/utils.dart';
import 'workspace.dart';

/// Resolves the [LocalLaunchConfig] that `cli_launcher` uses to resolve the
/// dependencies of, and launch, the local installation of Melos in the
/// workspace.
///
/// This happens before Melos reads the workspace configuration, so the SDK
/// path is resolved here separately. Without it, `cli_launcher` would use the
/// `dart`/`flutter` tools from the `PATH` regardless of the configured SDK,
/// which fails when no system-wide SDK is installed.
Future<LocalLaunchConfig> resolveLocalLaunchConfig(
  List<String> arguments,
  LaunchContext context,
) async {
  return LocalLaunchConfig(
    sdkPath: resolveLaunchSdkPath(
      arguments,
      workspaceRoot: context.localInstallation?.lockFileRoot,
    ),
  );
}

/// Resolves the SDK path that Melos should be launched with, using the same
/// precedence as [resolveSdkPath].
///
/// Returns `null` when no SDK path is configured, when the special value
/// [autoSdkPathOptionValue] is used, or when there is no [workspaceRoot].
///
/// Also returns `null` when the SDK has no `bin` directory, so that the
/// invalid path is reported by Melos instead of failing the launch.
@visibleForTesting
String? resolveLaunchSdkPath(
  List<String> arguments, {
  required Directory? workspaceRoot,
}) {
  if (workspaceRoot == null) {
    return null;
  }
  final sdkPath = resolveSdkPath(
    configSdkPath: _configSdkPath(workspaceRoot),
    envSdkPath:
        currentPlatform.environment[EnvironmentVariableKey.melosSdkPath],
    commandSdkPath: _commandLineSdkPath(arguments),
    workspacePath: workspaceRoot.path,
  );
  if (sdkPath == null || !dirExists(p.join(sdkPath, 'bin'))) {
    return null;
  }
  return sdkPath;
}

String? _commandLineSdkPath(List<String> arguments) {
  final parser = ArgParser(allowTrailingOptions: false)
    ..addFlag(globalOptionVerbose, negatable: false)
    ..addOption(globalOptionSdkPath);
  try {
    return parser.parse(arguments)[globalOptionSdkPath] as String?;
  } on FormatException {
    return null;
  }
}

String? _configSdkPath(Directory workspaceRoot) {
  final pubspecFile = File(pubspecPathForDirectory(workspaceRoot.path));
  if (!pubspecFile.existsSync()) {
    return null;
  }
  final pubspec = loadYaml(
    pubspecFile.readAsStringSync(),
    sourceUrl: pubspecFile.uri,
  );
  if (pubspec is! Map) {
    return null;
  }
  final melosSection = pubspec['melos'];
  if (melosSection is! Map) {
    return null;
  }
  final sdkPath = melosSection['sdkPath'];
  return sdkPath is String ? sdkPath : null;
}
