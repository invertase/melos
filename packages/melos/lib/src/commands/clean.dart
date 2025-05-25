part of 'runner.dart';

mixin _CleanMixin on _Melos {
  Future<void> clean({
    GlobalOptions? global,
    PackageFilters? packageFilters,
  }) async {
    final workspace = await createWorkspace(
      global: global,
      packageFilters: packageFilters,
    );

    return _runLifecycle(
      workspace,
      CommandWithLifecycle.clean,
      () async {
        logger.log('Cleaning workspace...');

        await Future.wait(workspace.filteredPackages.values.map(_cleanPackage));

        await cleanIntelliJ(workspace);

        logger
          ..newLine()
          ..log(
            'Workspace cleaned. You will need to run the bootstrap command '
            'again to use this workspace.',
          );
      },
    );
  }

  Future<void> _cleanPackage(Package package) async {
    final pathsToClean = [
      ...cleanablePubFilePaths,
      '.dart_tool',
    ].map((relativePath) => p.join(package.path, relativePath));

    for (final path in pathsToClean) {
      try {
        deleteEntry(path);
      } catch (error) {
        logger.warning('Failed to delete $path: $error');
      }
    }

    // Remove any old Melos generated dependency overrides from
    // `pubspec_overrides.yaml`. This can be removed after a few versions when
    // everyone has migrated to Melos ^7.0.0.
    final pubspecOverridesFile = p.join(package.path, 'pubspec_overrides.yaml');
    if (fileExists(pubspecOverridesFile)) {
      final contents = await readTextFileAsync(pubspecOverridesFile);
      final updatedContents = _mergeMelosPubspecOverrides({}, contents);
      if (updatedContents != null) {
        if (updatedContents.isEmpty) {
          deleteEntry(pubspecOverridesFile);
        } else {
          await writeTextFileAsync(pubspecOverridesFile, updatedContents);
        }
      }
    }
  }

  Future<void> cleanIntelliJ(MelosWorkspace workspace) async {
    if (dirExists(workspace.ide.intelliJ.runConfigurationsDir.path)) {
      final melosXmlGlob = createGlob(
        p.join(
          workspace.ide.intelliJ.runConfigurationsDir.path,
          '$kRunConfigurationPrefix*.xml',
        ),
        currentDirectoryPath: workspace.path,
      );

      await for (final melosXmlFile in melosXmlGlob.listFileSystem(
        const LocalFileSystem(),
      )) {
        deleteEntry(melosXmlFile.path);
      }
    }
  }
}

/// Merges the [melosDependencyOverrides] for other workspace packages into the
/// `pubspec_overrides.yaml` file for a package.
///
/// [melosDependencyOverrides] must contain a mapping of workspace package names
/// to their paths relative to the package.
///
/// [pubspecOverridesContent] are the current contents of the package's
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
String? _mergeMelosPubspecOverrides(
  Map<String, Dependency> melosDependencyOverrides,
  String? pubspecOverridesContent,
) {
  const managedDependencyOverridesMarker = 'melos_managed_dependency_overrides';
  final managedDependencyOverridesRegex = RegExp(
    '^# $managedDependencyOverridesMarker: (.*)\n',
    multiLine: true,
  );
  final pubspecOverridesEditor = YamlEditor(pubspecOverridesContent ?? '');
  final pubspecOverrides =
      pubspecOverridesEditor
              .parseAt([], orElse: () => wrapAsYamlNode(null))
              .value
          as Object?;

  final dependencyOverrides = pubspecOverridesContent?.isEmpty ?? true
      ? null
      : PubspecOverrides.parse(pubspecOverridesContent!).dependencyOverrides;
  final currentManagedDependencyOverrides =
      managedDependencyOverridesRegex
          .firstMatch(pubspecOverridesContent ?? '')
          ?.group(1)
          ?.split(',')
          .toSet() ??
      {};
  final newManagedDependencyOverrides = {...currentManagedDependencyOverrides};

  if (dependencyOverrides != null) {
    for (final dependencyOverride in dependencyOverrides.entries.toList()) {
      final packageName = dependencyOverride.key;

      if (currentManagedDependencyOverrides.contains(packageName)) {
        // This dependency override is managed by melos and might need to be
        // updated.

        if (melosDependencyOverrides.containsKey(packageName)) {
          // Update changed dependency override.
          final currentRef = dependencyOverride.value;
          final newRef = melosDependencyOverrides[packageName];
          if (currentRef != newRef) {
            pubspecOverridesEditor.update(
              ['dependency_overrides', packageName],
              wrapAsYamlNode(
                newRef!.toJson(),
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
                dependencyOverride.key: dependencyOverride.value.toJson(),
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
                dependencyOverride.key: dependencyOverride.value.toJson(),
            },
            collectionStyle: CollectionStyle.BLOCK,
          ),
        );
      } else {
        for (final dependencyOverride in melosDependencyOverrides.entries) {
          pubspecOverridesEditor.update(
            ['dependency_overrides', dependencyOverride.key],
            wrapAsYamlNode(
              dependencyOverride.value.toJson(),
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
        result = result.replaceAll(managedDependencyOverridesRegex, '');
      } else {
        if (!managedDependencyOverridesRegex.hasMatch(result)) {
          // When there is no marker comment, add one.
          result =
              '# $managedDependencyOverridesMarker: '
              '${newManagedDependencyOverrides.join(',')}\n$result';
        } else {
          // When there is a marker comment, update it.
          result = result.replaceFirstMapped(
            managedDependencyOverridesRegex,
            (match) =>
                '# $managedDependencyOverridesMarker: '
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
