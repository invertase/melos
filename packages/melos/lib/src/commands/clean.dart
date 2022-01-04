part of 'runner.dart';

mixin _CleanMixin on _Melos {
  Future<void> clean({PackageFilter? filter}) async {
    final workspace = await createWorkspace(filter: filter);

    return _runLifecycle(
      workspace,
      ScriptLifecycle.clean,
      () async {
        logger?.stdout('Cleaning workspace...');

        /// Cleans the workspace of all files generated by Melos.
        cleanWorkspace(workspace);

        workspace.filteredPackages.values.forEach(_cleanPackage);

        await cleanIntelliJ(workspace);

        logger?.stdout(
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

  void _cleanPackage(Package package) {
    final pathsToClean = [
      ...cleanablePubFilePaths,
      '.dart_tool',
    ];

    for (final generatedPubFilePath in pathsToClean) {
      final file = File(join(package.path, generatedPubFilePath));
      if (file.existsSync()) {
        file.deleteSync(recursive: true);
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
