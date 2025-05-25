part of 'runner.dart';

mixin _BootstrapMixin on _CleanMixin {
  Future<void> bootstrap({
    GlobalOptions? global,
    PackageFilters? packageFilters,
    bool noExample = false,
    bool? enforceLockfile,
    bool offline = false,
  }) async {
    final workspace = await createWorkspace(
      global: global,
      packageFilters: packageFilters,
    );

    return _runLifecycle(
      workspace,
      CommandWithLifecycle.bootstrap,
      () async {
        final bootstrapCommandConfig = workspace.config.commands.bootstrap;
        final runOffline = bootstrapCommandConfig.runPubGetOffline || offline;
        late final hasLockFile = File(
          p.join(workspace.path, 'pubspec.lock'),
        ).existsSync();
        final enforceLockfileConfigValue =
            workspace.config.commands.bootstrap.enforceLockfile;
        final shouldEnforceLockfile =
            (enforceLockfile ?? enforceLockfileConfigValue) && hasLockFile;

        final pubCommandForLogging = _buildPubGetCommand(
          workspace: workspace,
          noExample: noExample,
          runOffline: runOffline,
          enforceLockfile: shouldEnforceLockfile,
        ).join(' ');

        logger
          ..command('melos bootstrap')
          ..child(targetStyle(workspace.path))
          ..newLine();

        final filteredPackages = workspace.filteredPackages.values;
        final rollbackPubspecContent = <String, String>{};

        try {
          if (bootstrapCommandConfig.environment != null ||
              bootstrapCommandConfig.dependencies != null ||
              bootstrapCommandConfig.devDependencies != null) {
            logger.log('Updating common dependencies in workspace packages...');

            await Stream.fromIterable(filteredPackages).parallel((
              package,
            ) async {
              final pubspecPath = utils.pubspecPathForDirectory(package.path);
              final pubspecContent = await readTextFileAsync(pubspecPath);
              rollbackPubspecContent[pubspecPath] = pubspecContent;

              return _setSharedDependenciesForPackage(
                package,
                pubspecPath: pubspecPath,
                pubspecContent: pubspecContent,
                environment: bootstrapCommandConfig.environment,
                dependencies: bootstrapCommandConfig.dependencies,
                devDependencies: bootstrapCommandConfig.devDependencies,
              );
            }).drain<void>();
          }

          logger.log(
            'Running "$pubCommandForLogging" in workspace...',
          );

          await _runPubGetForWorkspace(
            workspace,
            noExample: noExample,
            runOffline: runOffline,
            enforceLockfile: shouldEnforceLockfile,
          );

          logger
            ..child(successLabel, prefix: '> ')
            ..newLine();
        } on BootstrapException catch (exception) {
          if (rollbackPubspecContent.isNotEmpty) {
            logger.log(
              'Dependency resolution failed, rolling back changes to '
              'the pubspec.yaml files...',
            );

            await Stream.fromIterable(rollbackPubspecContent.entries).parallel((
              entry,
            ) async {
              await writeTextFileAsync(entry.key, entry.value);
            }).drain<void>();
          }

          _logBootstrapException(exception, workspace);
          rethrow;
        }

        if (workspace.config.ide.intelliJ.enabled) {
          logger.log('Generating IntelliJ IDE files...');

          await cleanIntelliJ(workspace);
          await workspace.ide.intelliJ.generate();
          logger
            ..child(successLabel, prefix: '> ')
            ..newLine();
        }
        logger.log(
          ' -> ${workspace.filteredPackages.length} packages bootstrapped',
        );
      },
    );
  }

  Future<void> _runPubGetForWorkspace(
    MelosWorkspace workspace, {
    required bool noExample,
    required bool runOffline,
    required bool enforceLockfile,
  }) async {
    await runPubGetForPackage(
      workspace,
      workspace.rootPackage,
      noExample: noExample,
      runOffline: runOffline,
      enforceLockfile: enforceLockfile,
    );
  }

  @visibleForTesting
  Future<void> runPubGetForPackage(
    MelosWorkspace workspace,
    Package package, {
    required bool noExample,
    required bool runOffline,
    required bool enforceLockfile,
  }) async {
    final command = _buildPubGetCommand(
      workspace: workspace,
      noExample: noExample,
      runOffline: runOffline,
      enforceLockfile: enforceLockfile,
    );
    final process = await startCommandRaw(
      command,
      workingDirectory: package.path,
    );

    const logTimeout = Duration(seconds: 10);
    final packagePrefix = '[${AnsiStyles.blue.bold(workspace.name)}]: ';
    void Function(String) logLineTo(void Function(String) log) =>
        (line) => log.call('$packagePrefix$line');

    // We always fully consume stdout and stderr. This is required to prevent
    // leaking resources and to ensure that the process exits.
    final stdout = process.stdout.toStringAndLogAfterTimeout(
      timeout: logTimeout,
      log: logLineTo(logger.stdout),
    );
    final stderr = process.stderr.toStringAndLogAfterTimeout(
      timeout: logTimeout,
      log: logLineTo(logger.stderr),
    );

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw BootstrapException._(
        package,
        'Failed to run pub get.',
        stdout: await stdout,
        stderr: await stderr,
      );
    }
  }

  List<String> _buildPubGetCommand({
    required MelosWorkspace workspace,
    required bool noExample,
    required bool runOffline,
    required bool enforceLockfile,
  }) {
    return [
      ...pubCommandExecArgs(
        useFlutter: workspace.isFlutterWorkspace,
        workspace: workspace,
      ),
      'get',
      if (noExample) '--no-example',
      if (runOffline) '--offline',
      if (enforceLockfile) '--enforce-lockfile',
    ];
  }

  Future<void> _setSharedDependenciesForPackage(
    Package package, {
    required String pubspecPath,
    required String pubspecContent,
    required Map<String, VersionConstraint?>? environment,
    required Map<String, Dependency>? dependencies,
    required Map<String, Dependency>? devDependencies,
  }) async {
    final pubspecEditor = YamlEditor(pubspecContent);

    final updatedEnvironment = _updateEnvironment(
      pubspecEditor: pubspecEditor,
      workspaceEnvironment: environment,
      packageEnvironment: package.pubspec.environment,
    );

    final updatedDependenciesCount = _updateDependencies(
      pubspecEditor: pubspecEditor,
      workspaceDependencies: dependencies,
      packageDependencies: package.pubspec.dependencies,
      pubspecKey: 'dependencies',
    );

    final updatedDevDependenciesCount = _updateDependencies(
      pubspecEditor: pubspecEditor,
      workspaceDependencies: devDependencies,
      packageDependencies: package.pubspec.devDependencies,
      pubspecKey: 'dev_dependencies',
    );

    if (pubspecEditor.edits.isNotEmpty) {
      await writeTextFileAsync(pubspecPath, pubspecEditor.toString());

      final message = <String>[
        if (updatedEnvironment) 'Updated environment',
        if (updatedDependenciesCount > 0)
          'Updated $updatedDependenciesCount dependencies',
        if (updatedDevDependenciesCount > 0)
          'Updated $updatedDevDependenciesCount dev_dependencies',
      ];
      if (message.isNotEmpty) {
        logger
            .child(packageNameStyle(package.name), prefix: '$checkLabel ')
            .child(message.join('\n'));
      }
    }
  }

  bool _updateEnvironment({
    required YamlEditor pubspecEditor,
    required Environment? workspaceEnvironment,
    required Environment? packageEnvironment,
  }) {
    if (workspaceEnvironment == null || packageEnvironment == null) {
      return false;
    }

    var didUpdate = false;

    if (workspaceEnvironment.sdkConstraint !=
        packageEnvironment.sdkConstraint) {
      pubspecEditor.update(
        ['environment', 'sdk'],
        wrapAsYamlNode(
          workspaceEnvironment.sdkConstraint,
          collectionStyle: CollectionStyle.BLOCK,
        ),
      );
      didUpdate = true;
    }

    for (final entry in workspaceEnvironment.entries) {
      if (!packageEnvironment.containsKey(entry.key)) {
        continue;
      }
      if (packageEnvironment[entry.key] == entry.value) {
        continue;
      }

      pubspecEditor.update(
        ['environment', entry.key],
        wrapAsYamlNode(
          entry.value.toString(),
          collectionStyle: CollectionStyle.BLOCK,
        ),
      );
      didUpdate = true;
    }

    return didUpdate;
  }

  bool _areDependenciesEqual(Dependency? a, Dependency? b) {
    if (a is GitDependency && b is GitDependency) {
      return a == b && a.path == b.path;
    } else {
      return a == b;
    }
  }

  int _updateDependencies({
    required YamlEditor pubspecEditor,
    required Map<String, Dependency>? workspaceDependencies,
    required Map<String, Dependency> packageDependencies,
    required String pubspecKey,
  }) {
    if (workspaceDependencies == null) {
      return 0;
    }
    // Filter out the packages that do not exist in package and only the
    // dependencies that have a different version specified in the workspace.
    final dependenciesToUpdate = workspaceDependencies.entries.where((entry) {
      if (!packageDependencies.containsKey(entry.key)) {
        return false;
      }
      // TODO: We may want to replace the `pubspec` dependency with something
      // else that is actively maintained, so we don't have to provide our own
      // equality logic.
      // See: https://github.com/invertase/melos/discussions/663
      if (_areDependenciesEqual(packageDependencies[entry.key], entry.value)) {
        return false;
      }
      return true;
    });

    for (final entry in dependenciesToUpdate) {
      pubspecEditor.update(
        [pubspecKey, entry.key],
        wrapAsYamlNode(
          entry.value.toJson(),
          collectionStyle: CollectionStyle.BLOCK,
        ),
      );
    }

    return dependenciesToUpdate.length;
  }

  void _logBootstrapException(
    BootstrapException exception,
    MelosWorkspace workspace,
  ) {
    final package = exception.package;

    final processStdOutString = exception.stdout
        ?.split('\n')
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

    final processStdErrString = exception.stderr
        ?.split('\n')
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
            if (workspacePackage.name == package.name) {
              continue;
            }
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

    logger
        .child(targetStyle(package.name), prefix: '- ')
        .child(packagePathStyle(printablePath(package.pathRelativeToWorkspace)))
        .child(errorMessageColor(exception.message), stderr: true)
        .newLine();

    if (processStdOutString != null) {
      logger.stdout(processStdOutString);
    }
    if (processStdErrString != null) {
      logger.stderr(processStdErrString);
    }
  }
}

/// An exception for when `pub get` for a package failed.
class BootstrapException implements MelosException {
  BootstrapException._(
    this.package,
    this.message, {
    this.stdout,
    this.stderr,
  });

  /// The package that failed
  final Package package;
  final String message;
  final String? stdout;
  final String? stderr;

  @override
  String toString() {
    return 'BootstrapException: $message: ${package.name} at '
        '${package.path}.';
  }
}
