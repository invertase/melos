part of 'runner.dart';

mixin _CleanMixin on _Melos {
  Future<void> clean({GlobalOptions? global, PackageFilter? filter}) async {
    final workspace = await createWorkspace(global: global, filter: filter);

    return _runLifecycle(
      workspace,
      ScriptLifecycle.clean,
      () async {
        logger.stdout('Cleaning workspace...');

        /// Cleans the workspace of all files generated by Melos.
        cleanWorkspace(workspace);

        await Future.wait(workspace.filteredPackages.values.map(_cleanPackage));

        await cleanIntelliJ(workspace);

        logger.stdout(
          '\nWorkspace cleaned. '
          'You will need to run the bootstrap command again to use this workspace.',
        );
      },
    );
  }

  void cleanWorkspace(MelosWorkspace workspace) {
    if (Directory(workspace.melosToolPath).existsSync()) {
      Directory(workspace.melosToolPath).deleteSync(recursive: true);
    }
  }

  Future<void> _cleanPackage(Package package) async {
    final pathsToClean = [
      ...cleanablePubFilePaths,
      '.dart_tool',
    ];

    for (final generatedPubFilePath in pathsToClean) {
      final file = File(join(package.path, generatedPubFilePath));
      if (file.existsSync()) {
        await file.delete(recursive: true);
      }
    }

    // Remove any Melos generated dependency overrides from
    // `pubspec_overrides.yaml`.
    final pubspecOverridesFile =
        File(join(package.path, 'pubspec_overrides.yaml'));
    if (pubspecOverridesFile.existsSync()) {
      final contents = await pubspecOverridesFile.readAsString();
      final updatedContents = mergeMelosPubspecOverrides({}, contents);
      if (updatedContents != null) {
        if (updatedContents.isEmpty) {
          await pubspecOverridesFile.delete();
        } else {
          await pubspecOverridesFile.writeAsString(updatedContents);
        }
      }
    }
  }

  Future<void> cleanIntelliJ(MelosWorkspace workspace) async {
    if (workspace.ide.intelliJ.runConfigurationsDir.existsSync()) {
      final melosXmlGlob = createGlob(
        join(workspace.ide.intelliJ.runConfigurationsDir.path, 'melos_*.xml'),
        currentDirectoryPath: workspace.path,
      );

      await for (final melosYmlFile
          in melosXmlGlob.listFileSystem(const LocalFileSystem())) {
        await melosYmlFile.delete();
      }
    }
  }
}
