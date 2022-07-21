// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/command_runner.dart';
import 'package:melos/src/common/utils.dart' as utils;
import 'package:melos/version.g.dart';
import 'package:path/path.dart' as p;
import 'package:pub_updater/pub_updater.dart';
import 'package:pubspec/pubspec.dart';
import 'package:yaml/yaml.dart';

Future<void> main(List<String> arguments) async {
  try {
    await _invokeMelos(arguments);
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

Future<void> _invokeMelos(List<String> arguments) async {
  final logger = arguments.contains('--verbose')
      ? VerboseLogger(logTime: true)
      : StandardLogger();
  final melosLogger = MelosLogger(logger);

  if (!_isInvokedByInvoker) {
    final package = _findMelosWorkspacePackage();
    if (package != null) {
      melosLogger.trace('Found melos workspace package: ${package.path}');

      if (!await _ensurePubDependenciesAreUpToDate(package, melosLogger)) {
        // Failed to update pub dependencies.
        return;
      }

      final installedMelosVersion = _installedMelosVersion(package);
      if (installedMelosVersion != melosVersion) {
        // Installed version is not the current version, so we invoke it with
        // 'dart run melos:melos'.
        //
        // This is a slow path, since a new process is spawned and
        // `dart run melos:melos` currently does not cache the executable, like
        // for globally activated packages. The new Resident Frontend Compiler
        // flag (`--resident`) will make this faster, eventually.
        //
        // Likely, the globally installed version of Melos will be the same as
        // the locally installed version most of the time and this path will
        // not be taken. To nudge users to update local versions of Melos, we
        // print a message.

        melosLogger.hint(
          'Using locally installed version of melos ($installedMelosVersion) '
          'which is different from the current version ($melosVersion).',
        );

        final workspace = await MelosWorkspace.fromConfig(
          await MelosWorkspaceConfig.fromDirectory(package),
          logger: melosLogger,
        );

        final process = await Process.start(
          workspace.sdkTool('dart'),
          [
            'run',
            'melos:melos',
            ...arguments,
          ],
          runInShell: true,
          mode: ProcessStartMode.inheritStdio,
          environment: {_invokerEnvVar: 'true'},
          workingDirectory: package.path,
        );

        exitCode = await process.exitCode;
        return;
      }
    }
  }

  return _runMelos(arguments);
}

const _invokerEnvVar = 'MELOS_INVOKER';

final _isInvokedByInvoker = Platform.environment[_invokerEnvVar] == 'true';

/// Finds the nearest Melos workspace where a specific version of Melos is
/// specified in a `pubspec.yaml` file.
///
/// Returns `null` if no such directory is found.
///
/// Steps to find the install directory:
///
/// 1. Find a `melos.yaml` file by searching upwards from the current directory.
/// 2. Find a `pubspec.yaml` file next to the `melos.yaml` file.
/// 3. Find `melos` in `dependencies` or `dev_dependencies` in the
///    `pubspec.yaml` file.
Directory? _findMelosWorkspacePackage() {
  // ignore: literal_only_boolean_expressions
  for (var current = Directory.current; true; current = current.parent) {
    final melosYamlFile = File(p.join(current.path, 'melos.yaml'));
    if (melosYamlFile.existsSync()) {
      final pubspecFile = File(p.join(current.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        try {
          final pubspec =
              PubSpec.fromYamlString(pubspecFile.readAsStringSync());

          if (pubspec.dependencies.containsKey('melos') ||
              pubspec.devDependencies.containsKey('melos')) {
            return current;
          }
        } catch (e) {
          // Ignore invalid pubspec.yaml files.
        }
      }
    }

    if (current.path == current.parent.path) {
      // We have reached the root.
      break;
    }
  }

  return null;
}

/// Ensures that the pub dependencies in [package] are up to date, by running
/// `pub get` if they are outdated.
///
/// Returns `false` if the pub dependencies are outdated and the update failed.
Future<bool> _ensurePubDependenciesAreUpToDate(
  Directory package,
  MelosLogger melosLogger,
) async {
  if (!_pubDependenciesAreUpToDate(package)) {
    melosLogger.warning(
      'pub dependencies in ${p.canonicalize(package.path)} are out of date. '
      'Running pub get...',
    );

    final workspace = await MelosWorkspace.fromConfig(
      await MelosWorkspaceConfig.fromDirectory(package),
      logger: melosLogger,
    );

    final process = await Process.start(
      workspace.sdkTool('dart'),
      [
        'pub',
        'get',
      ],
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
      workingDirectory: package.path,
    );

    final pubGetExistCode = await process.exitCode;
    if (pubGetExistCode != 0) {
      exitCode = pubGetExistCode;
      return false;
    }
  }

  return true;
}

/// Returns whether the pub dependencies in [package] are up to date.
bool _pubDependenciesAreUpToDate(Directory package) {
  final pubspecFile = File(p.join(package.path, 'pubspec.yaml'));
  final pubspecLockFile = File(p.join(package.path, 'pubspec.lock'));
  final packageConfigFile =
      File(p.join(package.path, '.dart_tool', 'package_config.json'));

  if (!pubspecLockFile.existsSync() || !packageConfigFile.existsSync()) {
    return false;
  }

  if (pubspecFile.lastModifiedSync().microsecondsSinceEpoch >
      pubspecLockFile.lastModifiedSync().microsecondsSinceEpoch) {
    return false;
  }

  return pubspecLockFile.lastModifiedSync().microsecondsSinceEpoch <=
      packageConfigFile.lastModifiedSync().microsecondsSinceEpoch;
}

/// Returns the version of Melos installed in [package].
String _installedMelosVersion(Directory package) {
  final pubspecLock =
      utils.loadYamlFileSync(p.join(package.path, 'pubspec.lock'))!;
  return ((pubspecLock['packages'] as YamlMap?)?['melos']
      as YamlMap?)?['version']! as String;
}

Future<void> _runMelos(List<String> arguments) async {
  if (arguments.contains('--version') || arguments.contains('-v')) {
    print(melosVersion);
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
      final shouldUpdate = utils.promptBool(
        message: 'There is a new version of $packageName available '
            '($latestVersion). Would you like to update?',
        defaultsTo: true,
      );
      if (shouldUpdate) {
        await pubUpdater.update(packageName: packageName);
        print('$packageName has been updated to version $latestVersion.');
      }
    }

    return;
  }

  final config = await MelosWorkspaceConfig.fromDirectory(Directory.current);
  await MelosCommandRunner(config).run(arguments);
}
