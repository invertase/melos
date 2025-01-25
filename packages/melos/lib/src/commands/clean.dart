part of 'runner.dart';

mixin _CleanMixin on _Melos {
  Future<void> clean({
    GlobalOptions? global,
    PackageFilters? packageFilters,
  }) async {
    final workspace =
        await createWorkspace(global: global, packageFilters: packageFilters);

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

      await for (final melosXmlFile
          in melosXmlGlob.listFileSystem(const LocalFileSystem())) {
        deleteEntry(melosXmlFile.path);
      }
    }
  }
}
