part of 'runner.dart';

final _successLabel = AnsiStyles.green('SUCCESS');
final _warningLabel = AnsiStyles.yellow('WARNING');
final _checkLabel = AnsiStyles.greenBright('✓');

mixin _BootstrapMixin on _CleanMixin {
  Future<void> bootstrap({GlobalOptions? global, PackageFilter? filter}) async {
    final workspace = await createWorkspace(global: global, filter: filter);

    return _runLifecycle(
      workspace,
      ScriptLifecycle.bootstrap,
      () async {
        final pubCommandForLogging = [
          ...pubCommandExecArgs(
            useFlutter: workspace.isFlutterWorkspace,
            workspace: workspace,
          ),
          'get'
        ].join(' ');

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

        try {
          if (workspace.config.commands.bootstrap.usePubspecOverrides) {
            await _linkPackagesWithPubspecOverrides(workspace);
          } else {
            await _linkPackagesWithPubFiles(workspace);
          }
        } on BootstrapException catch (exception) {
          _logBootstrapException(exception, workspace);
          rethrow;
        }

        logger?.stdout('  > $_successLabel');

        if (workspace.config.ide.intelliJ.enabled) {
          logger?.stdout('');
          logger?.stdout('Generating IntelliJ IDE files...');

          await cleanIntelliJ(workspace);
          await workspace.ide.intelliJ.generate();
          logger?.stdout('  > $_successLabel');
        }

        logger?.stdout(
          '\n -> ${workspace.filteredPackages.length} plugins bootstrapped',
        );
      },
    );
  }

  Future<void> _linkPackagesWithPubspecOverrides(
    MelosWorkspace workspace,
  ) async {
    if (!workspace.isPubspecOverridesSupported) {
      logger?.stderr(
        '$_warningLabel: Dart 2.17.0 or greater is required to use Melos with '
        'pubspec overrides.',
      );
    }

    await Stream.fromIterable(workspace.filteredPackages.values).parallel(
      (package) async {
        if (package.pubSpec.dependencyOverrides.isNotEmpty) {
          logger?.stderr(
            '''
  $_warningLabel: ${AnsiStyles.bold(package.name)}
    └> dependency_overrides in pubspec.yaml are being overridden in pubspec_overrides.yaml''',
          );
        }

        await _generatePubspecOverrides(workspace, package);
        await _runPubGetForPackage(workspace, package);

        logger?.stdout(
          '''
  $_checkLabel ${AnsiStyles.bold(package.name)}
    └> ${AnsiStyles.blue(printablePath(package.pathRelativeToWorkspace))}''',
        );
      },
      parallelism: workspace.config.commands.bootstrap.runPubGetInParallel &&
              workspace.canRunPubGetConcurrently
          ? null
          : 1,
    ).drain<void>();
  }

  Future<void> _generatePubspecOverrides(
    MelosWorkspace workspace,
    Package package,
  ) async {
    final allTransitiveDependencies =
        package.allTransitiveDependenciesInWorkspace;
    final melosDependencyOverrides = <String, String>{};

    // Traversing all packages so that transitive dependencies for the
    // bootstraped packages are setup properly.
    for (final otherPackage in workspace.allPackages.values) {
      if (allTransitiveDependencies.containsKey(otherPackage.name)) {
        melosDependencyOverrides[otherPackage.name] =
            utils.relativePath(otherPackage.path, package.path);
      }
    }

    // Load current pubspec_overrides.yaml.
    final pubspecOverridesFile =
        File(utils.pubspecOverridesPathForDirectory(Directory(package.path)));
    final pubspecOverridesContents = pubspecOverridesFile.existsSync()
        ? await pubspecOverridesFile.readAsString()
        : null;

    // Write new version of pubspec_overrides.yaml if it has changed.
    final updatedPubspecOverridesContents = mergeMelosPubspecOverrides(
      melosDependencyOverrides,
      pubspecOverridesContents,
    );
    if (updatedPubspecOverridesContents != null) {
      if (updatedPubspecOverridesContents.isEmpty) {
        await pubspecOverridesFile.delete();
      } else {
        await pubspecOverridesFile.create(recursive: true);
        await pubspecOverridesFile
            .writeAsString(updatedPubspecOverridesContents);
      }
    }
  }

  Future<void> _linkPackagesWithPubFiles(MelosWorkspace workspace) async {
    await _generateTemporaryProjects(workspace);

    try {
      await for (final package in _runPubGet(workspace)) {
        logger?.stdout(
          '''
  $_checkLabel ${AnsiStyles.bold(package.name)}
    └> ${AnsiStyles.blue(printablePath(package.pathRelativeToWorkspace))}''',
        );
      }
    } catch (err) {
      cleanWorkspace(workspace);
      rethrow;
    }

    logger?.stdout('');
    logger?.stdout('Linking workspace packages...');

    for (final package in workspace.filteredPackages.values) {
      await package.linkPackages(workspace);
    }

    cleanWorkspace(workspace);
  }

  // Return a stream of package that completed.
  Stream<Package> _runPubGet(MelosWorkspace workspace) =>
      Stream.fromIterable(workspace.filteredPackages.values).parallel(
        (package) async {
          await _runPubGetForPackage(
            workspace,
            package,
            inTemporaryProject: true,
          );
          return package;
        },
        parallelism: workspace.config.commands.bootstrap.runPubGetInParallel &&
                workspace.canRunPubGetConcurrently
            ? null
            : 1,
      );

  Future<void> _runPubGetForPackage(
    MelosWorkspace workspace,
    Package package, {
    bool inTemporaryProject = false,
  }) async {
    final execArgs = [
      ...pubCommandExecArgs(
        useFlutter: package.isFlutterPackage,
        workspace: workspace,
      ),
      'get',
    ];

    final executable = currentPlatform.isWindows ? 'cmd' : '/bin/sh';
    final packagePath = inTemporaryProject
        ? join(workspace.melosToolPath, package.pathRelativeToWorkspace)
        : package.path;
    final process = await Process.start(
      executable,
      currentPlatform.isWindows ? ['/C', '%MELOS_SCRIPT%'] : [],
      workingDirectory: packagePath,
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

    const logTimeout = Duration(seconds: 10);
    final packagePrefix = '[${AnsiStyles.blue.bold(package.name)}]: ';
    void Function(String) logLineTo(void Function(String)? log) =>
        (line) => log?.call('$packagePrefix$line');

    // We always fully consume stdout and stderr. This is required to prevent
    // leaking resources and to ensure that the process exits.
    final stdout = process.stdout.toStringAndLogAfterTimeout(
      timeout: logTimeout,
      log: logLineTo(logger?.stdout),
    );
    final stderr = process.stderr.toStringAndLogAfterTimeout(
      timeout: logTimeout,
      log: logLineTo(logger?.stderr),
    );

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw BootstrapException._(
        package,
        'Failed to install.',
        stdout: await stdout,
        stderr: await stderr,
      );
    }
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
    └> ${AnsiStyles.blue(printablePath(package.pathRelativeToWorkspace))}''',
    );

    logger?.stderr('    └> ${AnsiStyles.red(exception.message)}');

    logger?.stdout('');
    if (processStdOutString != null) {
      logger?.stdout(processStdOutString);
    }
    if (processStdErrString != null) {
      logger?.stderr(processStdErrString);
    }
  }
}

Future<void> _generateTemporaryProjects(MelosWorkspace workspace) async {
  // Traversing all packages so that transitive dependencies for the bootstraped
  // packages are setup properly.
  for (final package in workspace.allPackages.values) {
    final pluginTemporaryPath =
        join(workspace.melosToolPath, package.pathRelativeToWorkspace);
    var pubspec = package.pubSpec;

    // Since the generated temporary package is located at a different path
    // than the original package, this may break path dependencies that this
    // package uses.
    // As such, we're updating the path dependencies to match the new location
    // by converting paths to absolute ones.
    Map<String, DependencyReference> transformPathDependenciesToAbsolute(
      Map<String, DependencyReference> dependencies,
    ) {
      final result = {...dependencies};

      for (final entry in dependencies.entries) {
        final dependency = entry.value;
        if (dependency is PathReference && dependency.path != null) {
          final absolutePath = absolute(package.path, dependency.path);

          if (currentPlatform.isWindows) {
            result[entry.key] = PathReference(
              windows.normalize(absolutePath).replaceAll(r'\', r'\\'),
            );
          } else {
            result[entry.key] = PathReference(absolutePath);
          }
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

const _managedDependencyOverridesMarker = 'melos_managed_dependency_overrides';
final _managedDependencyOverridesRegex = RegExp(
  '^# $_managedDependencyOverridesMarker: (.*)\n',
  multiLine: true,
);

/// Merges the [melosDependencyOverrides] for other workspace packages into the
/// `pubspec_overrides.yaml` file for a package.
///
/// [melosDependencyOverrides] must contain a mapping of workspace package names
/// to their paths relative to the package.
///
/// [pubspecOverridesContents] are the current contents of the package's
/// `pubspec_overrides.yaml` and may be `null` if the file does not exist.
///
/// Whitespace and comments in an existing `pubspec_overrides.yaml` file are
/// preserved.
///
/// Dependency overrides for a melos workspace package that have not been added
/// by melos are not changed or removed. To mark a dependency override as being
/// managed by melos, it is added to marker comment when first added by this
/// function:
///
/// ```yaml
/// # melos_managed_dependency_overrides: a
/// dependency_overrides:
///   a:
///     path: ../a
/// ```
///
/// This function also takes care of removing any dependency overrides that are
/// obsolete from `dependency_overrides` and the marker comment.
@visibleForTesting
String? mergeMelosPubspecOverrides(
  Map<String, String> melosDependencyOverrides,
  String? pubspecOverridesContents,
) {
  // ignore: parameter_assignments
  pubspecOverridesContents ??= '';

  final pubspecOverridesEditor = YamlEditor(pubspecOverridesContents);
  final pubspecOverrides = pubspecOverridesEditor
      .parseAt([], orElse: () => wrapAsYamlNode(null)).value as Object?;
  final dependencyOverrides = pubspecOverrides is Map &&
          pubspecOverrides['dependency_overrides'] is Map
      ? <dynamic, dynamic>{...pubspecOverrides['dependency_overrides'] as Map}
      : null;
  final currentManagedDependencyOverrides = _managedDependencyOverridesRegex
          .firstMatch(pubspecOverridesContents)
          ?.group(1)
          ?.split(',')
          .toSet() ??
      {};
  final newManagedDependencyOverrides = <String>{
    ...currentManagedDependencyOverrides
  };

  if (dependencyOverrides != null) {
    for (final dependencyOverride in dependencyOverrides.entries.toList()) {
      final packageName = dependencyOverride.key as Object;

      if (currentManagedDependencyOverrides.contains(packageName)) {
        // This dependency override is managed by melos and might need to be
        // updated.

        if (melosDependencyOverrides.containsKey(packageName)) {
          // Update changed dependency override.
          final pathSpec = dependencyOverride.value as Map;
          final packagePath = melosDependencyOverrides[packageName];
          if (pathSpec['path'] != packagePath) {
            pubspecOverridesEditor.update(
              ['dependency_overrides', packageName, 'path'],
              packagePath,
            );
          }
        } else {
          // Remove obsolete dependency override.
          pubspecOverridesEditor.remove(['dependency_overrides', packageName]);
          dependencyOverrides.remove(packageName);
          newManagedDependencyOverrides.remove(packageName);
        }
      }

      // Remove this dependency from the list of workspace dependency overrides,
      // so we only add new overrides later on.
      melosDependencyOverrides.remove(packageName);
    }
  }

  if (melosDependencyOverrides.isNotEmpty) {
    // Now melosDependencyOverrides only contains new dependencies that need to
    // be added to the `pubspec_overrides.yaml` file.

    newManagedDependencyOverrides.addAll(melosDependencyOverrides.keys);

    if (pubspecOverrides == null) {
      pubspecOverridesEditor.update(
        [],
        wrapAsYamlNode(
          <dynamic, dynamic>{
            'dependency_overrides': {
              for (final dependencyOverride in melosDependencyOverrides.entries)
                dependencyOverride.key: {
                  'path': dependencyOverride.value,
                },
            },
          },
          collectionStyle: CollectionStyle.BLOCK,
        ),
      );
    } else {
      if (dependencyOverrides == null) {
        pubspecOverridesEditor.update(
          ['dependency_overrides'],
          wrapAsYamlNode(
            {
              for (final dependencyOverride in melosDependencyOverrides.entries)
                dependencyOverride.key: {
                  'path': dependencyOverride.value,
                },
            },
            collectionStyle: CollectionStyle.BLOCK,
          ),
        );
      } else {
        for (final dependencyOverride in melosDependencyOverrides.entries) {
          pubspecOverridesEditor.update(
            ['dependency_overrides', dependencyOverride.key],
            wrapAsYamlNode(
              {'path': dependencyOverride.value},
              collectionStyle: CollectionStyle.BLOCK,
            ),
          );
        }
      }
    }
  } else {
    // No dependencies need to be added to the `pubspec_overrides.yaml` file.
    // This means it is possible that dependency_overrides and/or
    // melos_managed_dependency_overrides are now empty.
    if (dependencyOverrides?.isEmpty ?? false) {
      pubspecOverridesEditor.remove(['dependency_overrides']);
    }
  }

  if (pubspecOverridesEditor.edits.isNotEmpty) {
    var result = pubspecOverridesEditor.toString();

    // The changes to the `pubspec_overrides.yaml` file might require a change
    // in the managed dependencies marker comment.
    final setOfManagedDependenciesChanged =
        !const DeepCollectionEquality.unordered().equals(
      currentManagedDependencyOverrides,
      newManagedDependencyOverrides,
    );
    if (setOfManagedDependenciesChanged) {
      if (newManagedDependencyOverrides.isEmpty) {
        // When there are no managed dependencies, remove the marker comment.
        result = result.replaceAll(_managedDependencyOverridesRegex, '');
      } else {
        if (!_managedDependencyOverridesRegex.hasMatch(result)) {
          // When there is no marker comment, add one.
          result = '# $_managedDependencyOverridesMarker: '
              '${newManagedDependencyOverrides.join(',')}\n$result';
        } else {
          // When there is a marker comment, update it.
          result = result.replaceFirstMapped(
            _managedDependencyOverridesRegex,
            (match) => '# $_managedDependencyOverridesMarker: '
                '${newManagedDependencyOverrides.join(',')}\n',
          );
        }
      }
    }

    if (result.trim() == '{}') {
      // YamlEditor uses an empty dictionary ({}) when all properties have been
      // removed and the file is essentially empty.
      return '';
    }

    // Make sure the `pubspec_overrides.yaml` file always ends with a newline.
    if (result.isEmpty || !result.endsWith('\n')) {
      result += '\n';
    }

    return result;
  } else {
    return null;
  }
}

/// An exception for when `pub get` for a package failed.
class BootstrapException implements MelosException {
  BootstrapException._(this.package, this.message, {this.stdout, this.stderr});

  /// The package that failed
  final Package package;
  final String message;
  final String? stdout;
  final String? stderr;

  @override
  String toString() {
    return 'BootstrapException: $message: ${package.name} at ${package.path}.';
  }
}
