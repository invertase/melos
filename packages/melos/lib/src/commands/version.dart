part of 'runner.dart';

mixin _VersionMixin on _RunMixin {
  /// Version packages automatically based on the git history
  Future<void> autoVersion({
    PackageFilter? filter,
    bool asPrerelease = false,
    bool asStableRelease = false,
    bool updateChangelog = true,
    bool updateDependentsConstraints = true,
    bool updateDependentsVersions = true,
    bool gitTag = true,
    String? message,
    bool force = false,
    // all
    bool showPrivatePackages = false,
    String? preid,
    bool versionPrivatePackages = false,
  }) async {
    if (asPrerelease && asStableRelease) {
      throw ArgumentError('Cannot use both asPrerelease and asStableRelease.');
    }

    if (updateDependentsVersions && !updateDependentsConstraints) {
      throw ArgumentError(
        'Cannot use both updateDependentsVersions and updateDependentsConstraints.',
      );
    }

    final workspace = await createWorkspace(
      // We ignore `since` package list filtering on the 'version' command as it
      // already filters it itself, filtering here would map dependant version fail
      // as it won't be aware of any packages that have been filtered out here
      // because of the 'since' filter.
      filter: filter?.copyWithUpdatedSince(null),
    );

    message ??=
        workspace.config.commands.version.message ?? defaultCommitMessage;

    logger.stdout(AnsiStyles.yellow.bold('melos version'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(workspace.path)}\n');

    final commitMessageTemplate = Template(message, delimiters: '{ }');

    final packagesToVersion = <Package>{};
    final dependentPackagesToVersion = <Package>{};
    var pendingPackageUpdates = <MelosPendingPackageUpdate>[];

    if (workspace.config.scripts.containsKey('preversion')) {
      logger.stdout('Running "preversion" lifecycle script...\n');
      await run(scriptName: 'preversion');
    }

    final packageCommits = await _getPackageCommits(
      workspace,
      versionPrivatePackages: versionPrivatePackages,
      since: filter?.updatedSince,
    );

    final packagesWithVersionableCommits =
        _getPackagesWithVersionableCommits(packageCommits);

    if (asStableRelease) {
      for (final package in workspace.filteredPackages.values) {
        if (!package.version.isPreRelease) continue;

        pendingPackageUpdates.add(
          MelosPendingPackageUpdate(
            workspace,
            package,
            [],
            PackageUpdateReason.graduate,
            graduate: asStableRelease,
            prerelease: asPrerelease,
            preid: preid,
            logger: logger,
          ),
        );

        final packageUnscoped = workspace.allPackages[package.name]!;
        dependentPackagesToVersion
            .addAll(packageUnscoped.dependentsInWorkspace.values);
      }
    }

    for (final package in workspace.filteredPackages.values) {
      if (packagesWithVersionableCommits.contains(package.name)) {
        if (asStableRelease && package.version.isPreRelease) continue;

        packagesToVersion.add(package);

        final packageUnscoped = workspace.allPackages[package.name]!;
        dependentPackagesToVersion
            .addAll(packageUnscoped.dependentsInWorkspace.values);
      }
    }

    pendingPackageUpdates.addAll(
      packagesToVersion.map(
        (package) => MelosPendingPackageUpdate(
          workspace,
          package,
          packageCommits[package.name]!,
          PackageUpdateReason.commit,
          graduate: asStableRelease,
          prerelease: asPrerelease,
          preid: preid,
          logger: logger,
        ),
      ),
    );

    for (final package in dependentPackagesToVersion) {
      final packageHasPendingUpdate = pendingPackageUpdates.any(
        (packageToVersion) => packageToVersion.package.name == package.name,
      );

      if (!packagesToVersion.contains(package) && !packageHasPendingUpdate) {
        pendingPackageUpdates.add(
          MelosPendingPackageUpdate(
            workspace,
            package,
            [],
            PackageUpdateReason.dependency,
            // Dependent packages that should have graduated would have already
            // gone through graduation logic above. So graduate should use the default
            // of 'false' here so as not to graduate anything that was specifically
            // excluded.
            // graduate: false,
            prerelease: asPrerelease,
            // TODO Should dependent packages also get the same preid, can we expose this as an option?
            // TODO In the case of "nullsafety" it doesn't make sense for dependent packages to also become nullsafety preid versions.
            // preid: preid,
            logger: logger,
          ),
        );
      }
    }

    // Filter out private packages.
    if (!versionPrivatePackages) {
      pendingPackageUpdates = pendingPackageUpdates
          .where((update) => !update.package.isPrivate)
          .toList();
    }

    if (pendingPackageUpdates.isEmpty) {
      logger.stdout(
        AnsiStyles.yellow(
          'No packages were found that required versioning.',
        ),
      );
      logger.stdout(
        AnsiStyles.gray(
          '''
Hint: try running "melos list" with the same filtering options to see a list of packages that were included.
Hint: try running "melos version --all" to include private packages.
''',
        ),
      );
      return;
    }

    logger.stdout(
      AnsiStyles.magentaBright('The following packages will be updated:\n'),
    );

    _logNewVersionTable(
      pendingPackageUpdates,
      updateDependentsVersions: updateDependentsVersions,
      updateDependentsConstraints: updateDependentsConstraints,
    );

    final shouldContinue = force || promptBool();
    if (!shouldContinue) {
      logger.stdout(AnsiStyles.red('Operation was canceled.'));
      exitCode = 1;
      return;
    }

    await _performPackageUpdates(
      pendingPackageUpdates,
      updateDependentsVersions: updateDependentsVersions,
      updateDependentsConstraints: updateDependentsConstraints,
      updateChangelog: updateChangelog,
    );

    // TODO allow support for individual package lifecycle version scripts
    if (workspace.config.scripts.containsKey('version')) {
      logger.stdout('Running "version" lifecycle script...\n');
      await run(scriptName: 'version');
    }

    if (gitTag) {
      await _gitStageChanges(pendingPackageUpdates);
      await _gitCommitChanges(
        workspace,
        pendingPackageUpdates,
        commitMessageTemplate,
        updateDependentsVersions: updateDependentsVersions,
      );
      await _gitTagChanges(
        pendingPackageUpdates,
        updateDependentsVersions,
      );
    }

    // TODO allow support for individual package lifecycle postversion scripts
    if (workspace.config.scripts.containsKey('postversion')) {
      logger.stdout('Running "postversion" lifecycle script...\n');
      await run(scriptName: 'postversion');
    }

    // TODO automatic push support
    logger.stdout(
      AnsiStyles.greenBright.bold(
        'Versioning successful. '
        'Ensure you push your git changes and tags (if applicable) via ${AnsiStyles.bgBlack.gray('git push --follow-tags')}',
      ),
    );
  }

  /// Manually version one package with a given version
  Future<void> version({
    bool force = false,
    required String packageName,
    required Version newVersion,
    bool gitTag = true,
    bool updateChangelog = true,
    bool updateDependentsConstraints = true,
  }) async {
    final workspace = await createWorkspace();

    logger.stdout(
      AnsiStyles.yellow.bold('melos version <packageName> <newVersion>'),
    );
    logger.stdout('   └> ${AnsiStyles.cyan.bold(workspace.path)}\n');

    final workspacePackage = workspace.filteredPackages.values.firstWhereOrNull(
      (package) => package.name == packageName,
    );

    // Validate package actually exists in workspace.
    if (workspacePackage == null) {
      exitCode = 1;
      logger.stdout(
        '${AnsiStyles.redBright('ERROR:')} package "$packageName" does not exist in this workspace.',
      );
      return;
    }

    logger.stdout(
      AnsiStyles.magentaBright('The following package will be updated:\n'),
    );
    logger.stdout(
      listAsPaddedTable(
        [
          [
            AnsiStyles.underline.bold('Package Name'),
            AnsiStyles.underline.bold('Current Version'),
            AnsiStyles.underline.bold('Updated Version'),
          ],
          [
            AnsiStyles.italic(packageName),
            AnsiStyles.dim(workspacePackage.version.toString()),
            AnsiStyles.green(newVersion.toString()),
          ],
        ],
        paddingSize: 3,
      ),
    );
    logger.stdout('');
    final shouldContinue = force || promptBool();
    if (!shouldContinue) {
      throw CancelledException();
    }

    var changelogEntry = '';

    if (updateChangelog) {
      changelogEntry = promptInput(
        'Describe your change for the changelog entry',
        defaultsTo: 'Bump "$packageName" to `$newVersion`.',
      );
    }

    // TODO allow support for individual package lifecycle version scripts
    if (workspace.config.scripts.containsKey('preversion')) {
      logger.stdout('Running "preversion" lifecycle script...\n');
      await run(scriptName: 'preversion');
    }

    // Update package pubspec version.
    await _setPubspecVersionForPackage(workspacePackage, newVersion);

    // Update changelog, if requested.
    if (updateChangelog) {
      logger.stdout(
        'Adding changelog entry in package "$packageName" for version "$newVersion"...',
      );
      final singleEntryChangelog = SingleEntryChangelog(
        workspacePackage,
        newVersion,
        changelogEntry,
        logger,
      );
      await singleEntryChangelog.write();
    }

    if (updateDependentsConstraints) {
      logger.stdout(
        'Updating version constraints for packages that depend on "$packageName"...',
      );
      // Update dependents.
      await Future.forEach([
        ...workspacePackage.dependentsInWorkspace.values,
        ...workspacePackage.devDependentsInWorkspace.values,
      ], (Package package) {
        return _setDependentPackageVersionConstraint(
          package,
          workspacePackage.name,
          newVersion,
        );
      });
    }

    // TODO allow support for individual package lifecycle version scripts
    if (workspace.config.scripts.containsKey('version')) {
      logger.stdout('Running "version" lifecycle script...\n');
      await run(scriptName: 'version');
    }

    logger.stdout(
      AnsiStyles.greenBright.bold(
        'Versioning successful. Ensure you commit and push your changes (if applicable).',
      ),
    );
  }

  Future<void> _setPubspecVersionForPackage(
    Package package,
    Version version,
  ) async {
    final pubspec = File(pubspecPathForDirectory(Directory(package.path)));
    final contents = await pubspec.readAsString();

    final updatedContents =
        contents.replaceAllMapped(versionReplaceRegex, (match) {
      return '${match.group(1)}$version${match.group(3)}';
    });

    // Sanity check that contents actually changed.
    if (contents == updatedContents) {
      logger.trace(
        'Failed to update a pubspec.yaml version to $version for package ${package.name}. '
        'You should probably report this issue with a copy of your pubspec.yaml file.',
      );
      return;
    }

    await pubspec.writeAsString(updatedContents);
  }

  Future<void> _setDependentPackageVersionConstraint(
    Package package,
    String dependencyName,
    Version version,
  ) {
    // By default dependency constraint using caret syntax to ensure the range allows
    // all versions guaranteed to be backwards compatible with the specified version.
    // For example, ^1.2.3 is equivalent to '>=1.2.3 <2.0.0', and ^0.1.2 is equivalent to '>=0.1.2 <0.2.0'.
    var versionConstraint = VersionConstraint.compatibleWith(version);

    // For nullsafety releases we use a >=currentVersion <nextMajorVersion constraint
    // to allow nullsafety prerelease id versions to function similar to semver without
    // the actual major, minor & patch versions changing.
    // e.g. >=1.2.0-1.0.nullsafety.0 <1.2.0-2.0.nullsafety.0
    if (version.toString().contains('.nullsafety.')) {
      final nextMajorFromCurrentVersion =
          versioning.nextVersion(version, SemverReleaseType.major);

      versionConstraint = VersionRange(
        min: version,
        includeMin: true,
        max: nextMajorFromCurrentVersion,
      );
    }

    return _setDependencyVersionForPackage(
      package,
      dependencyName,
      versionConstraint,
    );
  }

  Future<void> _setDependencyVersionForPackage(
    Package package,
    String dependencyName,
    VersionConstraint dependencyVersion,
  ) async {
    if (package.pubSpec.dependencies.containsKey(dependencyName) &&
        package.pubSpec.dependencies[dependencyName] is! HostedReference &&
        package.pubSpec.dependencies[dependencyName]
            is! ExternalHostedReference) {
      logger.trace(
        'Skipping updating dependency $dependencyName for package ${package.name} - '
        'the version is a Map definition and is most likely a dependency that is importing from a path or git remote.',
      );
      return;
    }
    if (package.pubSpec.devDependencies.containsKey(dependencyName) &&
        package.pubSpec.devDependencies[dependencyName] is! HostedReference &&
        package.pubSpec.devDependencies[dependencyName]
            is! ExternalHostedReference) {
      logger.trace(
        'Skipping updating dev dependency $dependencyName for package ${package.name} - '
        'the version is a Map definition and is most likely a dependency that is importing from a path or git remote.',
      );
      return;
    }

    final pubspec = File(pubspecPathForDirectory(Directory(package.path)));
    final contents = await pubspec.readAsString();
    final updatedContents = contents.replaceAllMapped(
        dependencyVersionReplaceRegex(dependencyName), (Match match) {
      return '${match.group(1)}$dependencyVersion';
    });

    // Sanity check that contents actually changed.
    if (contents == updatedContents) {
      logger.trace(
        'Failed to update dependency $dependencyName version to $dependencyVersion for package ${package.name}, '
        'you should probably report this issue with a copy of your pubspec.yaml file.',
      );
      return;
    }

    await pubspec.writeAsString(updatedContents);
  }

  void _logNewVersionTable(
    List<MelosPendingPackageUpdate> pendingPackageUpdates, {
    required bool updateDependentsVersions,
    required bool updateDependentsConstraints,
  }) {
    logger.stdout(
      listAsPaddedTable(
        [
          [
            AnsiStyles.underline.bold('Package Name'),
            AnsiStyles.underline.bold('Current Version'),
            AnsiStyles.underline.bold('Updated Version'),
            AnsiStyles.underline.bold('Update Reason'),
          ],
          ...pendingPackageUpdates.where((pendingUpdate) {
            if (pendingUpdate.reason == PackageUpdateReason.dependency &&
                !updateDependentsVersions &&
                !updateDependentsConstraints) {
              return false;
            }
            return true;
          }).map((pendingUpdate) {
            return [
              AnsiStyles.italic(pendingUpdate.package.name),
              AnsiStyles.dim(pendingUpdate.currentVersion.toString()),
              if (pendingUpdate.reason == PackageUpdateReason.dependency &&
                  !updateDependentsVersions)
                '-'
              else
                AnsiStyles.green(pendingUpdate.nextVersion.toString()),
              AnsiStyles.italic(
                (() {
                  switch (pendingUpdate.reason) {
                    case PackageUpdateReason.commit:
                      final semverType =
                          pendingUpdate.semverReleaseType.toString().substring(
                                pendingUpdate.semverReleaseType
                                        .toString()
                                        .indexOf('.') +
                                    1,
                              );
                      return 'updated with ${AnsiStyles.underline(semverType)} changes';
                    case PackageUpdateReason.dependency:
                      if (pendingUpdate.reason ==
                              PackageUpdateReason.dependency &&
                          !updateDependentsVersions) {
                        return 'dependency constraints changed';
                      }
                      return 'dependency was updated';
                    case PackageUpdateReason.graduate:
                      return 'graduate to stable';
                    default:
                      return 'unknown';
                  }
                })(),
              ),
            ];
          }),
        ],
        paddingSize: 3,
      ),
    );
  }

  Future<void> _performPackageUpdates(
    List<MelosPendingPackageUpdate> pendingPackageUpdates, {
    required bool updateDependentsVersions,
    required bool updateDependentsConstraints,
    required bool updateChangelog,
  }) async {
    // Note: not pooling & parrellelzing rights to avoid possible file contention.
    await Future.forEach(pendingPackageUpdates,
        (MelosPendingPackageUpdate pendingPackageUpdate) async {
      // Update package pubspec version.
      if ((pendingPackageUpdate.reason == PackageUpdateReason.dependency &&
              updateDependentsVersions) ||
          pendingPackageUpdate.reason != PackageUpdateReason.dependency) {
        await _setPubspecVersionForPackage(
          pendingPackageUpdate.package,
          pendingPackageUpdate.nextVersion,
        );
      }

      // Update dependents.
      if (updateDependentsConstraints) {
        await Future.forEach([
          ...pendingPackageUpdate.package.dependentsInWorkspace.values,
          ...pendingPackageUpdate.package.devDependentsInWorkspace.values
        ], (Package package) {
          return _setDependentPackageVersionConstraint(
            package,
            pendingPackageUpdate.package.name,
            // Note if we're not updating dependent versions then we use the current
            // version rather than the next version as the next version would never
            // have been applied.
            (pendingPackageUpdate.reason == PackageUpdateReason.dependency &&
                    !updateDependentsVersions)
                ? pendingPackageUpdate.package.version
                : pendingPackageUpdate.nextVersion,
          );
        });
      }

      // Update changelogs if requested.
      if (updateChangelog) {
        if ((pendingPackageUpdate.reason == PackageUpdateReason.dependency &&
                updateDependentsVersions) ||
            pendingPackageUpdate.reason != PackageUpdateReason.dependency) {
          await pendingPackageUpdate.changelog.write();
        }
      }
    });

    if (updateChangelog) {
      final workspace = await createWorkspace();
      final today = DateTime.now();
      final dateSlug =
          "${today.year.toString()}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final workspaceChangelog = WorkspaceChangelog(
        workspace,
        dateSlug,
        pendingPackageUpdates,
        logger,
      );

      await workspaceChangelog.write();
    }
  }

  Set<String> _getPackagesWithVersionableCommits(
    Map<String, List<RichGitCommit>> packageCommits,
  ) {
    final packagesWithVersionableCommits = <String>{};
    for (final entry in packageCommits.entries) {
      final packageName = entry.key;
      final packageCommits = entry.value;
      final versionableCommits = packageCommits
          .where((e) => e.parsedMessage.isVersionableCommit)
          .toList();
      if (versionableCommits.isNotEmpty) {
        packagesWithVersionableCommits.add(packageName);
      }
    }

    return packagesWithVersionableCommits;
  }

  Future<Map<String, List<RichGitCommit>>> _getPackageCommits(
    MelosWorkspace workspace, {
    required bool versionPrivatePackages,
    required String? since,
  }) async {
    final packageCommits = <String, List<RichGitCommit>>{};
    await Pool(10).forEach<Package, void>(workspace.filteredPackages.values,
        (package) async {
      if (!versionPrivatePackages && package.isPrivate) return;

      final commits = await gitCommitsForPackage(
        package,
        since: since,
        logger: logger,
      );

      packageCommits[package.name] = commits
          .map(RichGitCommit.tryParse)
          .whereType<RichGitCommit>()
          .toList();
    }).drain<void>();
    return packageCommits;
  }

  Future<void> _gitTagChanges(
    List<MelosPendingPackageUpdate> pendingPackageUpdates,
    bool updateDependentsVersions,
  ) async {
    await Future.forEach(pendingPackageUpdates,
        (MelosPendingPackageUpdate pendingPackageUpdate) async {
      if (pendingPackageUpdate.reason == PackageUpdateReason.dependency &&
          !updateDependentsVersions) {
        return;
      }

      // TODO '--tag-version-prefix' support (if we decide to support it later) would pass prefix named arg to gitTagForPackageVersion:
      final tag = gitTagForPackageVersion(
        pendingPackageUpdate.package.name,
        pendingPackageUpdate.nextVersion.toString(),
      );

      await gitTagCreate(
        tag,
        pendingPackageUpdate.changelog.markdown,
        workingDirectory: pendingPackageUpdate.package.path,
        logger: logger,
      );
    });
  }

  Future<void> _gitCommitChanges(
    MelosWorkspace workspace,
    List<MelosPendingPackageUpdate> pendingPackageUpdates,
    Template commitMessageTemplate, {
    required bool updateDependentsVersions,
  }) async {
    final publishedPackagesMessage = pendingPackageUpdates
        .where((pendingUpdate) {
          if (pendingUpdate.reason == PackageUpdateReason.dependency &&
              !updateDependentsVersions) {
            return false;
          }
          return true;
        })
        .map((e) => ' - ${e.package.name}@${e.nextVersion.toString()}')
        .join('\n');

    // Render our commit message template into the final string
    final resolvedCommitMessage = commitMessageTemplate.renderString({
      packageVersionsTemplateVar: publishedPackagesMessage,
    });

    // TODO this is currently blocking git submodules support (if we decide to
    // support it later) for packages as commit is only ran at the root.
    await gitCommit(
      resolvedCommitMessage,
      workingDirectory: workspace.path,
      logger: logger,
    );
  }

  Future<void> _gitStageChanges(
    List<MelosPendingPackageUpdate> pendingPackageUpdates,
  ) async {
    await Future.forEach(pendingPackageUpdates,
        (MelosPendingPackageUpdate pendingPackageUpdate) async {
      await gitAdd(
        'pubspec.yaml',
        workingDirectory: pendingPackageUpdate.package.path,
        logger: logger,
      );
      await gitAdd(
        'CHANGELOG.md',
        workingDirectory: pendingPackageUpdate.package.path,
        logger: logger,
      );
      await Future.forEach([
        ...pendingPackageUpdate.package.dependentsInWorkspace.values,
        ...pendingPackageUpdate.package.devDependentsInWorkspace.values,
      ], (Package dependentPackage) async {
        await gitAdd(
          'pubspec.yaml',
          workingDirectory: dependentPackage.path,
          logger: logger,
        );
      });

      // TODO this is a temporary workaround for committing generated dart files.
      // TODO remove once options exposed for this in a later release.
      if (pendingPackageUpdate.package.name == 'melos') {
        await gitAdd(
          '**/*.g.dart',
          workingDirectory: pendingPackageUpdate.package.path,
          logger: logger,
        );
      }
    });
  }
}

class PackageNotFoundException extends MelosException {
  PackageNotFoundException(this.packageName);

  final String packageName;

  @override
  String toString() {
    return 'PackageNotFoundException: The package $packageName';
  }
}
