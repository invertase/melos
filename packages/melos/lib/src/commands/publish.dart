part of 'runner.dart';

mixin _PublishMixin on _ExecMixin {
  Future<void> publish({
    GlobalOptions? global,
    PackageFilters? packageFilters,
    bool dryRun = true,
    bool gitTagVersion = true,
    // yes
    bool force = false,
  }) async {
    final workspace =
        await createWorkspace(global: global, packageFilters: packageFilters);

    logger.command('melos publish${dryRun ? " --dry-run" : ''}');
    logger.child(targetStyle(workspace.path)).newLine();

    final readRegistryProgress =
        logger.progress('Reading pub registry for package information');

    Map<String, String?> latestPublishedVersionForPackages;

    try {
      latestPublishedVersionForPackages =
          await _getLatestPublishedVersionForPackages(workspace);
    } finally {
      readRegistryProgress.finish(
        message: successLabel,
        showTiming: true,
      );
    }

    final unpublishedPackages = <Package>[
      for (final entry in latestPublishedVersionForPackages.entries)
        if (entry.value == null ||
            entry.value !=
                workspace.filteredPackages[entry.key]!.version.toString())
          workspace.filteredPackages[entry.key]!,
    ];

    if (unpublishedPackages.isEmpty) {
      logger
        ..newLine()
        ..success(
          'No unpublished packages found - '
          'all local packages are already up to date.',
        );
      return;
    }

    sortPackagesForPublishing(unpublishedPackages);

    logger
      ..newLine()
      ..warning(
        AnsiStyles.bold(
          dryRun
              ? 'The following packages will be validated only (dry run):'
              : 'The following packages WILL be published to the registry:',
        ),
        label: false,
        dryRun: dryRun,
      )
      ..newLine();

    logger.stdout(
      listAsPaddedTable(
        [
          [
            AnsiStyles.underline.bold('Package Name'),
            AnsiStyles.underline.bold('Registry'),
            AnsiStyles.underline.bold('Local'),
          ],
          ...unpublishedPackages.map((package) {
            return [
              AnsiStyles.italic(package.name),
              AnsiStyles.dim(latestPublishedVersionForPackages[package.name]),
              AnsiStyles.green(package.version.toString()),
            ];
          }),
        ],
        paddingSize: 4,
      ),
    );

    if (!force) {
      final shouldContinue = promptBool();
      if (!shouldContinue) throw CancelledException();
      logger.newLine();
    }

    await _publish(
      workspace,
      unpublishedPackages,
      dryRun: dryRun,
      gitTagVersion: gitTagVersion,
    );
  }

  Future<Map<String, String?>> _getLatestPublishedVersionForPackages(
    MelosWorkspace workspace,
  ) async {
    final pool = Pool(10);
    final latestPackageVersion = <String, String?>{};

    await pool.forEach<Package, void>(workspace.filteredPackages.values,
        (package) async {
      if (package.isPrivate) return;

      final pubPackage = await package.getPublishedPackage();
      final versions = pubPackage?.prioritizedVersions.reversed
          .map((v) => v.version.toString())
          .toList();

      if (versions == null || versions.isEmpty) {
        latestPackageVersion[package.name] = null;
        return;
      }

      // If current version is a prerelease version then get the latest
      // prerelease version with a matching preid instead if any.
      if (package.version.isPreRelease) {
        final preid = package.version.preRelease.length == 4
            ? package.version.preRelease[2] as String
            : package.version.preRelease[0] as String;
        final versionsWithPreid =
            versions.where((version) => version.contains(preid)).toList();
        latestPackageVersion[package.name] =
            versionsWithPreid.isEmpty ? versions[0] : versionsWithPreid[0];
      } else {
        latestPackageVersion[package.name] = versions[0];
      }
    }).drain<void>();

    return latestPackageVersion;
  }

  Future<void> _publish(
    MelosWorkspace workspace,
    List<Package> unpublishedPackages, {
    required bool dryRun,
    required bool gitTagVersion,
  }) async {
    final updateRegistryProgress = logger.progress(
      'Publishing ${unpublishedPackages.length} packages to registry:',
    );
    final execArgs = [
      ...pubCommandExecArgs(useFlutter: false, workspace: workspace),
      'publish',
    ];

    if (dryRun) {
      execArgs.add('--dry-run');
    } else {
      execArgs.add('--force');
    }

    await _execForAllPackages(
      workspace,
      unpublishedPackages,
      execArgs,
      concurrency: 1,
      failFast: true,
      orderDependents: false,
    );

    if (exitCode != 1) {
      if (!dryRun && gitTagVersion) {
        logger
          ..newLine()
          ..log('Creating git tags for any versions not already created... ');
        await Future.forEach(unpublishedPackages, (package) async {
          final tag =
              gitTagForPackageVersion(package.name, package.version.toString());
          await gitTagCreate(
            tag,
            'Publish $tag.',
            workingDirectory: package.path,
            logger: logger,
          );
        });
      }

      updateRegistryProgress.finish(
        message: successLabel,
        showTiming: true,
      );

      logger
        ..newLine()
        ..success(
          dryRun
              ? 'All packages were validated successfully.'
              : 'All packages have successfully been published.',
          dryRun: dryRun,
        );
    }
  }
}
