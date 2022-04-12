// ignore_for_file: avoid_print

import 'dart:io';

import 'package:melos/src/command_runner.dart';
import 'package:melos/src/common/exception.dart';
import 'package:melos/src/common/utils.dart' as utils;
import 'package:melos/src/workspace_configs.dart';
import 'package:melos/version.g.dart';
import 'package:pub_updater/pub_updater.dart';

Future<void> main(List<String> arguments) async {
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
        message:
            'There is a new version of $packageName available ($latestVersion). Would you like to update?',
        defaultsTo: true,
      );
      if (shouldUpdate) {
        await pubUpdater.update(packageName: packageName);
        print('$packageName has been updated to version $latestVersion.');
      }
    }

    return;
  }
  try {
    final config = await MelosWorkspaceConfig.fromDirectory(Directory.current);
    await MelosCommandRunner(config).run(arguments);
  } on MelosException catch (err) {
    stderr.writeln(err.toString());
    exitCode = 1;
  } catch (err) {
    exitCode = 1;
    rethrow;
  }
}
