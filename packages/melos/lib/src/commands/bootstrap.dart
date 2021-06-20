part of 'runner.dart';

mixin _BootstrapMixin on _CleanMixin {
  Future<void> bootstrap({PackageFilter? filter}) async {
    final workspace = await createWorkspace(filter: filter);

    return _runLifecycle(
      workspace,
      ScriptLifecycle.bootstrap,
      () async {
        final successMessage = AnsiStyles.green('SUCCESS');

        final pubCommandForLogging =
            "${workspace.isFlutterWorkspace ? "flutter " : ""}pub get";
        logger.stdout(AnsiStyles.yellow.bold('melos bootstrap'));
        logger.stdout('   └> ${AnsiStyles.cyan.bold(workspace.path)}\n');

        logger
            .stdout('Running "$pubCommandForLogging" in workspace packages...');
        if (!utils.isCI && workspace.filteredPackages.keys.length > 20) {
          logger.stdout(
            AnsiStyles.yellow(
              'Note: this may take a while in large workspaces such as this one.',
            ),
          );
        }

        await _generateTemporaryProjects(workspace);

        try {
          await _runPubGet(workspace);
        } catch (_) {
          cleanWorkspace(workspace);
          rethrow;
        }

        logger.stdout('');
        logger.stdout('Linking workspace packages...');

        for (final package in workspace.filteredPackages.values) {
          await package.linkPackages(workspace);
        }

        cleanWorkspace(workspace);
        logger.stdout('  > $successMessage');

        if (workspace.config.ide.intelliJ.enabled) {
          logger.stdout('');
          logger.stdout('Generating IntelliJ IDE files...');

          await cleanIntelliJ(workspace);
          await workspace.ide.intelliJ.generate();
          logger.stdout('  > $successMessage');
        }

        logger.stdout(
          '\n -> ${workspace.filteredPackages.length} plugins bootstrapped',
        );
      },
    );
  }

  Future<void> _runPubGet(MelosWorkspace workspace) async {
    for (final package in workspace.filteredPackages.values) {
      final pubGet = await _runPubGetForPackage(workspace, package);

      // ignore: unawaited_futures
      stdout.addStream(pubGet.process.stdout);
      // ignore: unawaited_futures
      stderr.addStream(pubGet.process.stderr);

      final exitCode = await pubGet.process.exitCode;

      if (exitCode != 0) {
        throw BootstrapException(package);
      }
    }
  }

  Future<_PubGet> _runPubGetForPackage(
    MelosWorkspace workspace,
    Package package,
  ) async {
    final pluginTemporaryPath =
        join(workspace.melosToolPath, package.pathRelativeToWorkspace);

    List<String> command;
    if (workspace.isFlutterWorkspace) {
      command = ['flutter', 'pub', 'get'];
    } else if (utils.isPubSubcommand()) {
      // `pub` is not available do we have to use `dart pub`
      command = ['dart', 'pub', 'get'];
    } else {
      command = ['pub', 'get'];
    }

    final process = await Process.start(
      command[0],
      command.skip(1).toList(),
      workingDirectory: pluginTemporaryPath,
      environment: {
        utils.envKeyMelosTerminalWidth: utils.terminalWidth.toString(),
        'MELOS_SCRIPT': command.join(' '),
      },
      runInShell: true,
    );

    return _PubGet(
      args: command,
      package: package,
      process: process,
    );
  }
}

Future<void> _generateTemporaryProjects(MelosWorkspace workspace) async {
  // Traversing all packages so that transitive dependencies for the bootstraped
  // packages are setup properly.
  for (final package in workspace.allPackages.values) {
    final pluginTemporaryPath =
        join(workspace.melosToolPath, package.pathRelativeToWorkspace);
    var pubspec = package.pubSpec;

    // Traversing all packages so that transitive dependencies for the bootstraped
    // packages are setup properly.
    for (final plugin in workspace.allPackages.values) {
      final pluginPath = utils.relativePath(
        join(workspace.melosToolPath, plugin.pathRelativeToWorkspace),
        pluginTemporaryPath,
      );

      if (package.dependenciesInWorkspace.containsKey(plugin.name) ||
          package.devDependenciesInWorkspace.containsKey(plugin.name) ||
          package.dependencyOverridesInWorkspace.containsKey(plugin.name)) {
        pubspec = pubspec.copy(
          dependencyOverrides: {
            ...pubspec.dependencyOverrides,
            plugin.name: PathReference(pluginPath),
          },
        );
      }
    }

    const header = '# Generated file - do not commit this file.';
    final generatedPubspecYamlString =
        '$header\n${toYamlString(pubspec.toJson())}';

    final pubspecFile = File(
      utils.pubspecPathForDirectory(Directory(pluginTemporaryPath)),
    );
    pubspecFile.createSync(recursive: true);
    pubspecFile.writeAsStringSync(generatedPubspecYamlString);

    // Original pubspec.lock files should also be preserved in our packages
    // mirror, if we don't then this makes melos bootstrap function the same
    // as `dart pub upgrade` every time - which we don't want.
    // See https://github.com/invertase/melos/issues/68
    final originalPubspecLock = join(package.path, 'pubspec.lock');
    if (File(originalPubspecLock).existsSync()) {
      final pubspecLockContents = File(originalPubspecLock).readAsStringSync();
      final copiedPubspecLock = join(pluginTemporaryPath, 'pubspec.lock');
      File(copiedPubspecLock).writeAsStringSync(pubspecLockContents);
    }
  }
}

class _PubGet {
  _PubGet({
    required this.args,
    required this.package,
    required this.process,
  });

  final List<String> args;
  final Package package;
  final Process process;
}

/// An exception for when `pub get` for a package failed.
class BootstrapException implements MelosException {
  BootstrapException(this.package);

  /// The package that failed
  final Package package;

  @override
  String toString() {
    return 'BootstrapException: failed to install ${package.name} at ${package.path}.';
  }
}
