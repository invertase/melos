part of 'runner.dart';

mixin _BootstrapMixin on _CleanMixin {
  Future<void> bootstrap({
    GlobalOptions? global,
    PackageFilters? packageFilters,
    bool noExample = false,
    bool enforceLockfile = false,
    bool skipLinking = false,
  }) async {
    final workspace =
        await createWorkspace(global: global, packageFilters: packageFilters);

    return _runLifecycle(
      workspace,
      CommandWithLifecycle.bootstrap,
      () async {
        final bootstrapCommandConfig = workspace.config.commands.bootstrap;
        final shouldEnforceLockfile =
            bootstrapCommandConfig.enforceLockfile || enforceLockfile;
        final pubCommandForLogging = [
          ...pubCommandExecArgs(
            useFlutter: workspace.isFlutterWorkspace,
            workspace: workspace,
          ),
          'get',
          if (noExample) '--no-example',
          if (bootstrapCommandConfig.runPubGetOffline) '--offline',
          if (shouldEnforceLockfile) '--enforce-lockfile',
        ].join(' ');

        logger
          ..command('melos bootstrap')
          ..child(targetStyle(workspace.path))
          ..newLine();

        if (!utils.isCI && workspace.filteredPackages.keys.length > 20) {
          logger.warning(
            'Note: this may take a while in large workspaces such as this one.',
            label: false,
          );
        }

        try {
          if (bootstrapCommandConfig.environment != null ||
              bootstrapCommandConfig.dependencies != null ||
              bootstrapCommandConfig.devDependencies != null) {
            logger.log('Updating common dependencies in workspace packages...');

            final filteredPackages = workspace.filteredPackages.values;
            await Stream.fromIterable(filteredPackages).parallel((package) {
              return _setSharedDependenciesForPackage(
                package,
                environment: bootstrapCommandConfig.environment,
                dependencies: bootstrapCommandConfig.dependencies,
                devDependencies: bootstrapCommandConfig.devDependencies,
              );
            }).drain<void>();

            logger
              ..child(successLabel, prefix: '> ')
              ..newLine();
          }

          if (!skipLinking) {
            logger.log(
              'Running "$pubCommandForLogging" in workspace packages...',
            );

            await _linkPackagesWithPubspecOverrides(
              workspace,
              enforceLockfile: enforceLockfile,
              noExample: noExample,
            );

            logger
              ..child(successLabel, prefix: '> ')
              ..newLine();
          }
        } on BootstrapException catch (exception) {
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

  Future<void> _linkPackagesWithPubspecOverrides(
    MelosWorkspace workspace, {
    required bool enforceLockfile,
    required bool noExample,
  }) async {
    final filteredPackages = workspace.filteredPackages.values;

    await Stream.fromIterable(filteredPackages).parallel(
      (package) async {
        if (package.isExample) {
          final enclosingPackage = package.enclosingPackage!;
          if (enclosingPackage.isFlutterPackage &&
              filteredPackages.contains(enclosingPackage)) {
            // This package will be bootstrapped as part of bootstrapping
            // the enclosing package.
            return;
          }
        }

        final bootstrappedPackages = [package];
        await _generatePubspecOverrides(workspace, package);
        if (package.isFlutterPackage) {
          final example = package.examplePackage;
          if (example != null && filteredPackages.contains(example)) {
            // The flutter tool bootstraps the example package as part of
            // bootstrapping the enclosing package, so we need to generate
            // the pubspec overrides for the example package as well.
            await _generatePubspecOverrides(workspace, example);
            bootstrappedPackages.add(example);
          }
        }
        await _runPubGetForPackage(
          workspace,
          package,
          enforceLockfile: enforceLockfile,
          noExample: noExample,
        );

        bootstrappedPackages.forEach(_logBootstrapSuccess);
      },
      parallelism:
          workspace.config.commands.bootstrap.runPubGetInParallel ? null : 1,
    ).drain<void>();
  }

  Future<void> _generatePubspecOverrides(
    MelosWorkspace workspace,
    Package package,
  ) async {
    final allTransitiveDependencies =
        package.allTransitiveDependenciesInWorkspace;
    final melosDependencyOverrides = <String, DependencyReference>{};

    // Traversing all packages so that transitive dependencies for the
    // bootstrapped packages are setup properly.
    for (final otherPackage in workspace.allPackages.values) {
      if (allTransitiveDependencies.containsKey(otherPackage.name)) {
        melosDependencyOverrides[otherPackage.name] =
            PathReference(utils.relativePath(otherPackage.path, package.path));
      }
    }

    // Add custom workspace overrides.
    for (final dependencyOverride
        in workspace.dependencyOverridePackages.values) {
      melosDependencyOverrides[dependencyOverride.name] = PathReference(
        utils.relativePath(dependencyOverride.path, package.path),
      );
    }

    // Add existing dependency overrides from pubspec.yaml last, overwriting
    // overrides that would be made by Melos, to provide granular control at a
    // package level.
    melosDependencyOverrides.addAll(package.pubSpec.dependencyOverrides);

    // Load current pubspec_overrides.yaml.
    final pubspecOverridesFile =
        utils.pubspecOverridesPathForDirectory(package.path);
    final pubspecOverridesContents = fileExists(pubspecOverridesFile)
        ? await readTextFileAsync(pubspecOverridesFile)
        : null;

    // Write new version of pubspec_overrides.yaml if it has changed.
    final updatedPubspecOverridesContents = mergeMelosPubspecOverrides(
      melosDependencyOverrides,
      pubspecOverridesContents,
    );
    if (updatedPubspecOverridesContents != null) {
      if (updatedPubspecOverridesContents.isEmpty) {
        deleteEntry(pubspecOverridesFile);
      } else {
        await writeTextFileAsync(
          pubspecOverridesFile,
          updatedPubspecOverridesContents,
        );
      }
    }
  }

  Future<void> _runPubGetForPackage(
    MelosWorkspace workspace,
    Package package, {
    required bool enforceLockfile,
    required bool noExample,
  }) async {
    final shouldEnforceLockfile =
        workspace.config.commands.bootstrap.enforceLockfile || enforceLockfile;
    final command = [
      ...pubCommandExecArgs(
        useFlutter: package.isFlutterPackage,
        workspace: workspace,
      ),
      'get',
      if (noExample) '--no-example',
      if (workspace.config.commands.bootstrap.runPubGetOffline) '--offline',
      if (shouldEnforceLockfile) '--enforce-lockfile',
    ];

    final process = await startCommandRaw(
      command,
      workingDirectory: package.path,
    );

    const logTimeout = Duration(seconds: 10);
    final packagePrefix = '[${AnsiStyles.blue.bold(package.name)}]: ';
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
        'Failed to install.',
        stdout: await stdout,
        stderr: await stderr,
      );
    }
  }

  Future<void> _setSharedDependenciesForPackage(
    Package package, {
    required Environment? environment,
    required Map<String, DependencyReference>? dependencies,
    required Map<String, DependencyReference>? devDependencies,
  }) async {
    final packagePubspecFile = utils.pubspecPathForDirectory(package.path);
    final packagePubspecContents = await readTextFileAsync(packagePubspecFile);
    final pubspecEditor = YamlEditor(packagePubspecContents);

    final updatedEnvironment = _updateEnvironment(
      pubspecEditor: pubspecEditor,
      workspaceEnvironment: environment,
      packageEnvironment: package.pubSpec.environment,
    );

    final updatedDependenciesCount = _updateDependencies(
      pubspecEditor: pubspecEditor,
      workspaceDependencies: dependencies,
      packageDependencies: package.pubSpec.dependencies,
      pubspecKey: 'dependencies',
    );

    final updatedDevDependenciesCount = _updateDependencies(
      pubspecEditor: pubspecEditor,
      workspaceDependencies: devDependencies,
      packageDependencies: package.pubSpec.devDependencies,
      pubspecKey: 'dev_dependencies',
    );

    if (pubspecEditor.edits.isNotEmpty) {
      await writeTextFileAsync(
        packagePubspecFile,
        pubspecEditor.toString(),
      );

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
          workspaceEnvironment.sdkConstraint.toString(),
          collectionStyle: CollectionStyle.BLOCK,
        ),
      );
      didUpdate = true;
    }

    final workspaceUnParsedYaml = workspaceEnvironment.unParsedYaml;
    final packageUnParsedYaml = packageEnvironment.unParsedYaml;
    if (workspaceUnParsedYaml != null && packageUnParsedYaml != null) {
      for (final entry in workspaceUnParsedYaml.entries) {
        if (!packageUnParsedYaml.containsKey(entry.key)) continue;
        if (packageUnParsedYaml[entry.key] == entry.value) continue;

        pubspecEditor.update(
          ['environment', entry.key],
          wrapAsYamlNode(
            entry.value.toString(),
            collectionStyle: CollectionStyle.BLOCK,
          ),
        );
        didUpdate = true;
      }
    }

    return didUpdate;
  }

  int _updateDependencies({
    required YamlEditor pubspecEditor,
    required Map<String, DependencyReference>? workspaceDependencies,
    required Map<String, DependencyReference> packageDependencies,
    required String pubspecKey,
  }) {
    if (workspaceDependencies == null) return 0;
    // Filter out the packages that do not exist in package and only the
    // dependencies that have a different version specified in the workspace.
    final dependenciesToUpdate = workspaceDependencies.entries.where((entry) {
      if (!packageDependencies.containsKey(entry.key)) return false;
      if (packageDependencies[entry.key] == entry.value) return false;
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

  void _logBootstrapSuccess(Package package) {
    logger.child(packageNameStyle(package.name), prefix: '$checkLabel ').child(
          packagePathStyle(printablePath(package.pathRelativeToWorkspace)),
        );
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
  Map<String, DependencyReference> melosDependencyOverrides,
  String? pubspecOverridesContents,
) {
  // ignore: parameter_assignments
  pubspecOverridesContents ??= '';

  final pubspecOverridesEditor = YamlEditor(pubspecOverridesContents);
  final pubspecOverrides = pubspecOverridesEditor
      .parseAt([], orElse: () => wrapAsYamlNode(null)).value as Object?;
  final dependencyOverrides = pubspecOverrides is Map &&
          pubspecOverrides['dependency_overrides'] is Map
      ? {...pubspecOverrides['dependency_overrides'] as Map<Object?, Object?>}
      : null;
  final currentManagedDependencyOverrides = _managedDependencyOverridesRegex
          .firstMatch(pubspecOverridesContents)
          ?.group(1)
          ?.split(',')
          .toSet() ??
      {};
  final newManagedDependencyOverrides = {...currentManagedDependencyOverrides};

  if (dependencyOverrides != null) {
    for (final dependencyOverride in dependencyOverrides.entries.toList()) {
      final packageName = dependencyOverride.key!;

      if (currentManagedDependencyOverrides.contains(packageName)) {
        // This dependency override is managed by melos and might need to be
        // updated.

        if (melosDependencyOverrides.containsKey(packageName)) {
          // Update changed dependency override.
          final currentRef =
              DependencyReference.fromJson(dependencyOverride.value);
          final newRef = melosDependencyOverrides[packageName];
          if (currentRef != newRef) {
            pubspecOverridesEditor.update(
              ['dependency_overrides', packageName],
              wrapAsYamlNode(
                newRef!.toJson() as Object,
                collectionStyle: CollectionStyle.BLOCK,
              ),
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
          {
            'dependency_overrides': {
              for (final dependencyOverride in melosDependencyOverrides.entries)
                dependencyOverride.key:
                    dependencyOverride.value.toJson() as Object,
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
                dependencyOverride.key:
                    dependencyOverride.value.toJson() as Object,
            },
            collectionStyle: CollectionStyle.BLOCK,
          ),
        );
      } else {
        for (final dependencyOverride in melosDependencyOverrides.entries) {
          pubspecOverridesEditor.update(
            ['dependency_overrides', dependencyOverride.key],
            wrapAsYamlNode(
              dependencyOverride.value.toJson() as Object,
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
