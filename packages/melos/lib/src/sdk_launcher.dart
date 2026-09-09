import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'common/environment_variable_key.dart';
import 'common/io.dart';
import 'common/platform.dart';
import 'common/utils.dart';
import 'workspace.dart';

/// Relaunches Melos with the configured Dart/Flutter SDK first on the `PATH`
/// when Melos was not started with that SDK.
///
/// Before Melos reads the workspace configuration, `cli_launcher` resolves the
/// local installation of Melos by running `dart`/`flutter` from the `PATH`.
/// Without this relaunch, the `sdkPath` option is ignored for those
/// invocations, which fail when no system-wide SDK is installed.
///
/// Returns `true` when Melos was relaunched, in which case [exitCode] has
/// already been set from the relaunched process.
Future<bool> relaunchWithConfiguredSdk(List<String> arguments) async {
  final SdkRelaunch? relaunch;
  try {
    final sdkPath = await resolveLaunchSdkPath(arguments);
    relaunch = sdkPath == null
        ? null
        : planSdkRelaunch(arguments, sdkPath: sdkPath);
  } on Exception {
    // Problems with the configuration are reported by Melos once it runs.
    return false;
  }
  if (relaunch == null) {
    return false;
  }

  final process = await Process.start(
    relaunch.executable,
    relaunch.arguments,
    environment: relaunch.environment,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
  return true;
}

/// Resolves the SDK path that Melos should be launched with, using the same
/// precedence as [resolveSdkPath].
///
/// Returns `null` when no SDK path is configured, when the special value
/// [autoSdkPathOptionValue] is used, or when [current] is not inside a
/// workspace.
@visibleForTesting
Future<String?> resolveLaunchSdkPath(
  List<String> arguments, {
  Directory? current,
}) async {
  final workspaceRoot = _findWorkspaceRoot(current ?? Directory.current);
  if (workspaceRoot == null) {
    return null;
  }
  return resolveSdkPath(
    configSdkPath: _configSdkPath(workspaceRoot),
    envSdkPath:
        currentPlatform.environment[EnvironmentVariableKey.melosSdkPath],
    commandSdkPath: _commandLineSdkPath(arguments),
    workspacePath: workspaceRoot.path,
  );
}

/// Plans how to relaunch Melos with the SDK at [sdkPath] first on the `PATH`.
///
/// Returns `null` when no relaunch is needed because the SDK is already first
/// on the `PATH`, or when a relaunch is not possible because the SDK has no
/// `bin` directory or the running script cannot be located.
@visibleForTesting
SdkRelaunch? planSdkRelaunch(
  List<String> arguments, {
  required String sdkPath,
}) {
  final sdkBinPath = p.join(sdkPath, 'bin');
  if (!dirExists(sdkBinPath)) {
    return null;
  }

  final platform = currentPlatform;
  final pathKey = platform.environment.keys.firstWhere(
    (key) => key.toUpperCase() == EnvironmentVariableKey.path,
    orElse: () => EnvironmentVariableKey.path,
  );
  final currentPath = platform.environment[pathKey] ?? '';
  final firstPathEntry = currentPath.split(pathEnvVarSeparator).firstOrNull;
  if (firstPathEntry != null && p.equals(firstPathEntry, sdkBinPath)) {
    return null;
  }

  final script = platform.script;
  if (script.scheme != 'file') {
    return null;
  }
  final scriptPath = script.toFilePath();
  final executable = platform.resolvedExecutable;
  final isStandaloneExecutable = p.equals(scriptPath, executable);

  return SdkRelaunch(
    executable: executable,
    arguments: [
      if (!isStandaloneExecutable) ...[
        ...platform.executableArguments.whereNot(_isInternalVmArgument),
        scriptPath,
      ],
      ...arguments,
    ],
    environment: {
      pathKey: addToPathEnvVar(
        directory: sdkBinPath,
        currentPath: currentPath,
        prepend: true,
      ),
    },
  );
}

/// The process invocation used to relaunch Melos with a configured SDK.
@immutable
class SdkRelaunch {
  const SdkRelaunch({
    required this.executable,
    required this.arguments,
    required this.environment,
  });

  final String executable;
  final List<String> arguments;
  final Map<String, String> environment;
}

/// The `dart` executable passes these arguments to the VM to describe itself.
/// They must not be forwarded, since they would describe the wrong process.
bool _isInternalVmArgument(String argument) =>
    argument.startsWith('--resolved_executable_name=') ||
    argument.startsWith('--executable_name=');

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
  final melosSection = _loadPubspec(workspaceRoot)?['melos'];
  if (melosSection is! Map) {
    return null;
  }
  final sdkPath = melosSection['sdkPath'];
  return sdkPath is String ? sdkPath : null;
}

/// Finds the root of the workspace that [start] is part of, mirroring how
/// `cli_launcher` finds the local installation of Melos.
///
/// The root is the closest ancestor whose `pubspec.yaml` depends on `melos`.
/// If that package is a workspace member, the root is the closest ancestor
/// with a `workspace` section instead.
Directory? _findWorkspaceRoot(Directory start) {
  for (final directory in _ancestors(start)) {
    final pubspec = _loadPubspec(directory);
    if (pubspec == null || !_dependsOnMelos(pubspec)) {
      continue;
    }
    if (pubspec['resolution'] != 'workspace') {
      return directory;
    }
    return _ancestors(directory.parent).firstWhereOrNull(
      (ancestor) => _loadPubspec(ancestor)?['workspace'] is List,
    );
  }
  return null;
}

Iterable<Directory> _ancestors(Directory start) sync* {
  var current = start;
  while (true) {
    yield current;
    final parent = current.parent;
    if (parent.path == current.path) {
      return;
    }
    current = parent;
  }
}

bool _dependsOnMelos(Map<Object?, Object?> pubspec) {
  return [pubspec['dependencies'], pubspec['dev_dependencies']].any(
    (dependencies) => dependencies is Map && dependencies.containsKey('melos'),
  );
}

Map<Object?, Object?>? _loadPubspec(Directory directory) {
  final pubspecFile = File(pubspecPathForDirectory(directory.path));
  if (!pubspecFile.existsSync()) {
    return null;
  }
  final pubspec = loadYaml(
    pubspecFile.readAsStringSync(),
    sourceUrl: pubspecFile.uri,
  );
  return pubspec is Map ? pubspec : null;
}
