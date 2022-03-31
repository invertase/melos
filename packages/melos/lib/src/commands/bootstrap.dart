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
        logger?.stdout(AnsiStyles.yellow.bold('melos bootstrap'));
        logger?.stdout('   └> ${AnsiStyles.cyan.bold(workspace.path)}\n');

        logger?.stdout(
          'Running "$pubCommandForLogging" in workspace packages...',
        );
        if (!utils.isCI && workspace.filteredPackages.keys.length > 20) {
          logger?.stdout(
            AnsiStyles.yellow(
              'Note: this may take a while in large workspaces such as this one.',
            ),
          );
        }

        await _generateTemporaryProjects(workspace);

        try {
          await for (final package in _runPubGet(workspace)) {
            logger?.stdout(
              '''
  ${AnsiStyles.greenBright('✓')} ${AnsiStyles.bold(package.name)}
    └> ${AnsiStyles.blue(package.pathRelativeToWorkspace)}''',
            );
          }
        } catch (err) {
          if (err is BootstrapException) {
            await _logPubGetFailed(
              err.package,
              err.stdout,
              err.stderr,
              workspace,
            );
          }
          cleanWorkspace(workspace);
          rethrow;
        }

        logger?.stdout('');
        logger?.stdout('Linking workspace packages...');

        for (final package in workspace.filteredPackages.values) {
          await package.linkPackages(workspace);
        }

        cleanWorkspace(workspace);
        logger?.stdout('  > $successMessage');

        if (workspace.config.ide.intelliJ.enabled) {
          logger?.stdout('');
          logger?.stdout('Generating IntelliJ IDE files...');

          await cleanIntelliJ(workspace);
          await workspace.ide.intelliJ.generate();
          logger?.stdout('  > $successMessage');
        }

        logger?.stdout(
          '\n -> ${workspace.filteredPackages.length} plugins bootstrapped',
        );
      },
    );
  }

  Future<void> _logPubGetFailed(
    Package package,
    String stdout,
    String stderr,
    MelosWorkspace workspace,
  ) async {
    var processStdOutString = stdout;
    var processStdErrString = stderr;

    processStdOutString = processStdOutString
        .split('\n')
        // We filter these out as they can be quite spammy. This happens
        // as we run multiple pub gets in parallel.
        .where(
          (line) => !line.contains(
            'Waiting for another flutter command to release the startup lock',
          ),
        )
        // Remove empty lines to reduce logging.
        .where((line) => line.trim().isNotEmpty)
        .toList()
        .join('\n');

    processStdErrString = processStdErrString
        .split('\n')
        // We filter these out as they can be quite spammy. This happens
        // as we run multiple pub gets in parallel.
        .where(
          (line) => !line.contains(
            'Waiting for another flutter command to release the startup lock',
          ),
        )
        // Remove empty lines to reduce logging.
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          var lineWithWorkspacePackagesHighlighted = line;
          for (final workspacePackage in workspace.allPackages.values) {
            if (workspacePackage.name == package.name) continue;
            lineWithWorkspacePackagesHighlighted =
                lineWithWorkspacePackagesHighlighted.replaceAll(
              '${workspacePackage.name} ',
              '${AnsiStyles.yellowBright(workspacePackage.name)} ',
            );
          }
          return lineWithWorkspacePackagesHighlighted;
        })
        .toList()
        .join('\n');

    logger?.stdout(
      '''
  - ${AnsiStyles.bold.cyan(package.name)}
    └> ${AnsiStyles.blue(package.pathRelativeToWorkspace)}''',
    );

    logger?.stderr('    └> ${AnsiStyles.red('Failed to install.')}');

    logger?.stdout('');
    logger?.stdout(processStdOutString);
    logger?.stderr(processStdErrString);
  }

  // Return a stream of package that completed.
  Stream<Package> _runPubGet(MelosWorkspace workspace) async* {
    for (final package in workspace.filteredPackages.values) {
      final pubGet = await _runPubGetForPackage(workspace, package);

      // We always fully consume stdout and stderr. This is required to prevent
      // leaking resources and to ensure that the process exits. We
      // need stdout and stderr in case of an error. Otherwise, we don't care
      // about the output, don't wait for it to finish and don't handle errors.
      // We just make sure the output streams are drained.
      final stdout = utf8.decodeStream(pubGet.process.stdout);
      final stderr = utf8.decodeStream(pubGet.process.stderr);

      final exitCode = await pubGet.process.exitCode;

      if (exitCode != 0) {
        throw BootstrapException._(package, await stdout, await stderr);
      }
      yield package;
    }
  }

  Future<_PubGet> _runPubGetForPackage(
    MelosWorkspace workspace,
    Package package,
  ) async {
    final pubGetArgs = ['pub', 'get'];
    final execArgs = package.isFlutterPackage
        ? ['flutter', ...pubGetArgs]
        : [if (utils.isPubSubcommand()) 'dart', ...pubGetArgs];
    final executable = currentPlatform.isWindows ? 'cmd' : '/bin/sh';
    final pluginTemporaryPath =
        join(workspace.melosToolPath, package.pathRelativeToWorkspace);
    final process = await Process.start(
      executable,
      currentPlatform.isWindows ? ['/C', '%MELOS_SCRIPT%'] : [],
      workingDirectory: pluginTemporaryPath,
      environment: {
        utils.envKeyMelosTerminalWidth: utils.terminalWidth.toString(),
        'MELOS_SCRIPT': execArgs.join(' '),
      },
      runInShell: true,
    );

    if (!currentPlatform.isWindows) {
      // Pipe in the arguments to trigger the script to run.
      process.stdin.writeln(execArgs.join(' '));
      // Exit the process with the same exit code as the previous command.
      process.stdin.writeln(r'exit $?');
    }

    return _PubGet(
      args: execArgs,
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

    // Since the generated temporary package is located at the different path than
    // original package, this may break path dependencies that this package uses.
    // As such, we're updating the path dependencies to match the new location
    // by converting paths to absolute ones.
    Map<String, DependencyReference> transformPathDependenciesToAbsolute(
      Map<String, DependencyReference> dependencies,
    ) {
      final result = {...dependencies};

      for (final entry in dependencies.entries) {
        final dependency = entry.value;
        if (dependency is PathReference && dependency.path != null) {
          result[entry.key] =
              PathReference(absolute(package.path, dependency.path));
        }
      }

      return result;
    }

    pubspec = pubspec.copy(
      dependencies: transformPathDependenciesToAbsolute(pubspec.dependencies),
      devDependencies:
          transformPathDependenciesToAbsolute(pubspec.devDependencies),
      dependencyOverrides:
          transformPathDependenciesToAbsolute(pubspec.dependencyOverrides),
    );

    // Traversing all packages so that transitive dependencies for the bootstraped
    // packages are setup properly.
    for (final plugin in workspace.allPackages.values) {
      final pluginPath = utils.relativePath(
        join(workspace.melosToolPath, plugin.pathRelativeToWorkspace),
        pluginTemporaryPath,
      );

      if (package.allTransitiveDependenciesInWorkspace
          .containsKey(plugin.name)) {
        pubspec = pubspec.copy(
          dependencyOverrides: {
            ...pubspec.dependencyOverrides,
            plugin.name: PathReference(pluginPath),
          },
        );

        // If this package is an an add-to-app module, all plugins that are
        // dependencies of the package must have their android main classes copied
        // to the temporary workspace, otherwise pub get fails.
        if (package.isAddToApp &&
            plugin.isFlutterPlugin &&
            plugin.flutterPluginSupportsAndroid &&
            plugin.androidPackage != null &&
            (plugin.javaPluginClassPath != null ||
                plugin.kotlinPluginClassPath != null)) {
          // A plugin should only have one main class, written in java
          // or kotlin. We want to copy that class to the temporary workspace
          // at the same relative location, so pub get can find it
          final hasJavaPluginClass = plugin.javaPluginClassPath != null;
          final hasKotlinPluginClass = plugin.kotlinPluginClassPath != null;
          final pathParts = plugin.androidPackage!.split('.');
          final mainClassDirectoryName = hasJavaPluginClass ? 'java' : 'kotlin';
          final mainClassFileSuffix = hasJavaPluginClass ? '.java' : '.kt';
          final destinationMainClassPath = joinAll([
            join(workspace.melosToolPath, plugin.pathRelativeToWorkspace),
            'android/src/main/$mainClassDirectoryName',
            ...pathParts,
            '${plugin.androidPluginClass!}$mainClassFileSuffix',
          ]);
          File(destinationMainClassPath).createSync(recursive: true);
          String? classPath;
          if (hasJavaPluginClass) {
            classPath = plugin.javaPluginClassPath;
          } else if (hasKotlinPluginClass) {
            classPath = plugin.kotlinPluginClassPath;
          }
          File(classPath!).copySync(destinationMainClassPath);
        }
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
  BootstrapException._(this.package, this.stdout, this.stderr);

  /// The package that failed
  final Package package;
  final String stdout;
  final String stderr;

  @override
  String toString() {
    return 'BootstrapException: failed to install ${package.name} at ${package.path}.';
  }
}
