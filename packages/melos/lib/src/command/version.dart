/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:conventional_commit/conventional_commit.dart';
import 'package:mustache_template/mustache.dart';
import 'package:pool/pool.dart' show Pool;
import 'package:pub_semver/pub_semver.dart';

import '../command_runner.dart';
import '../common/changelog.dart';
import '../common/git.dart';
import '../common/logger.dart';
import '../common/package.dart';
import '../common/pending_package_update.dart';
import '../common/utils.dart';
import '../common/versioning.dart' as versioning;
import '../common/workspace.dart';
import 'base.dart';

/// Template variable that is replaced with versioned package info in commit
/// messages.
const packageVersionsTemplateVar = 'new_package_versions';

/// The default commit message used when versioning.
const defaultCommitMessage =
    'chore(release): publish packages\n\n{$packageVersionsTemplateVar}';

class VersionCommand extends MelosCommand {
  VersionCommand() {
    argParser.addFlag(
      'prerelease',
      abbr: 'p',
      negatable: false,
      help: 'Version any packages with changes as a prerelease. Cannot be '
          'combined with graduate flag. Applies only to Conventional '
          'Commits based versioning.',
    );
    argParser.addFlag(
      'graduate',
      abbr: 'g',
      negatable: false,
      help:
          'Graduate current prerelease versioned packages to stable versions, e.g. '
          '"0.10.0-dev.1" would become "0.10.0". Cannot be combined with prerelease '
          'flag. Applies only to Conventional Commits based versioning.',
    );
    argParser.addFlag(
      'changelog',
      abbr: 'c',
      defaultsTo: true,
      help: 'Update CHANGELOG.md files.',
    );
    argParser.addFlag(
      'dependent-constraints',
      abbr: 'd',
      defaultsTo: true,
      help:
          'Update dependency version constraints of packages in this workspace '
          'that depend on any of the packages that will be updated with this '
          'versioning run.',
    );
    argParser.addFlag(
      'dependent-versions',
      abbr: 'D',
      defaultsTo: true,
      help: 'Make a new patch version and changelog entry in packages that are '
          'updated due to "--dependent-constraints" changes. Only usable '
          'with "--dependent-constraints" enabled and Conventional Commits '
          'based versioning.',
    );
    argParser.addFlag(
      'git-tag-version',
      abbr: 't',
      defaultsTo: true,
      help:
          'By default, melos version will commit changes to pubspec.yaml files '
          'and tag the release. Pass --no-git-tag-version to disable the behavior. '
          'Applies only to Conventional Commits based versioning.',
    );
    argParser.addOption(
      'message',
      abbr: 'm',
      valueHelp: 'msg',
      help: "Use the given <msg> as the release's commit message. If the "
          'message contains {$packageVersionsTemplateVar}, it will be '
          'replaced by the list of newly versioned package names.\n'
          'If --message is not provided, the message will default to '
          '"$defaultCommitMessage".',
    );
    argParser.addFlag(
      'yes',
      negatable: false,
      help: 'Skip the Y/n confirmation prompt. Note that for manual versioning '
          '--no-changelog must also be passed to avoid prompts.',
    );
    argParser.addFlag(
      'all',
      abbr: 'a',
      negatable: false,
      help: 'Version private packages that are skipped by default.',
    );
    argParser.addOption(
      'preid',
      help:
          'When run with this option, melos version will increment prerelease '
          'versions using the specified prerelease identifier, e.g. using a '
          '"nullsafety" preid along with the --prerelease flag would '
          'result in a version in the format "1.0.0-1.0.nullsafety.0". '
          'Applies only to Conventional Commits based versioning.',
    );
  }

  @override
  final String name = 'version';

  @override
  final String description =
      'Automatically version and generate changelogs based on the Conventional Commits specification. Supports all package filtering options.';

  @override
  // ignore: leading_newlines_in_multiline_strings
  final String invocation = ' ${AnsiStyles.bold('melos version')}\n'
      '          Version packages automatically using the Conventional Commits specification.\n\n'
      '        ${AnsiStyles.bold('melos version')} <package name> <new version>\n'
      '          Manually set a package to a specific version, and update all packages that depend on it.\n';

  /// The template used to produce the git commit message.
  ///
  // If the commit message was provided via an option, we will unescape newlines
  // as a convenience.
  String get _commitMessage =>
      argResults['message']?.replaceAll(r'\n', '\n') as String ??
      commandConfig.getString('message') ??
      defaultCommitMessage;

  Future<void> applyUserSpecifiedVersion() async {
    logger.stdout(
        AnsiStyles.yellow.bold('melos version <packageName> <newVersion>'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}\n');
    if (argResults.rest.length != 2) {
      exitCode = 1;
      logger.stdout(
        '${AnsiStyles.redBright('ERROR:')} when manually setting a version to '
        'apply to a package you must specify both <packageName> and <newVersion> '
        'arguments when calling "melos version".',
      );
      return;
    }

    final packageName = argResults.rest[0];
    final newVersion = argResults.rest[1];
    final workspacePackage = currentWorkspace.packages.firstWhere(
        (package) => package.name == packageName,
        orElse: () => null);

    // Validate package actually exists in workspace.
    if (workspacePackage == null) {
      exitCode = 1;
      logger.stdout(
        '${AnsiStyles.redBright('ERROR:')} package "$packageName" does not exist in this workspace.',
      );
      return;
    }

    // Validate version is valid.
    if (!versioning.isValidVersion(newVersion)) {
      exitCode = 1;
      logger.stdout(
        '${AnsiStyles.redBright('ERROR:')} version "$newVersion" is not a valid package version.',
      );
      return;
    }

    logger.stdout(
        AnsiStyles.magentaBright('The following package will be updated:\n'));
    logger.stdout(listAsPaddedTable([
      [
        AnsiStyles.underline.bold('Package Name'),
        AnsiStyles.underline.bold('Current Version'),
        AnsiStyles.underline.bold('Updated Version'),
      ],
      [
        AnsiStyles.italic(packageName),
        AnsiStyles.dim(workspacePackage.version.toString()),
        AnsiStyles.green(newVersion),
      ],
    ], paddingSize: 3));
    logger.stdout('');
    final skipPrompt = argResults['yes'] as bool;
    final shouldContinue = skipPrompt || promptBool();
    if (!shouldContinue) {
      logger.stdout(AnsiStyles.red('Operation was canceled.'));
      exitCode = 1;
      return;
    }

    var changelogEntry = '';
    final shouldUpdateDependents = argResults['dependent-constraints'] as bool;
    final shouldGenerateChangelogEntry = argResults['changelog'] as bool;
    if (shouldGenerateChangelogEntry) {
      changelogEntry = promptInput(
          'Describe your change for the changelog entry',
          defaultsTo: 'Bump "$packageName" to `$newVersion`.');
    }

    // Update package pubspec version.
    final newVersionParsed = Version.parse(newVersion);
    await workspacePackage.setPubspecVersion(newVersionParsed.toString());

    // Update changelog, if requested.
    if (shouldGenerateChangelogEntry) {
      logger.stdout(
          'Adding changelog entry in package "$packageName" for version "$newVersion"...');
      final singleEntryChangelog =
          SingleEntryChangelog(workspacePackage, newVersion, changelogEntry);
      await singleEntryChangelog.write();
    }

    if (shouldUpdateDependents) {
      logger.stdout(
          'Updating version constraints for packages that depend on "$packageName"...');
      // Update dependents.
      await Future.forEach([
        ...workspacePackage.dependentsInWorkspace,
        ...workspacePackage.devDependentsInWorkspace
      ], (MelosPackage package) {
        return setDependentPackageVersionConstraint(
            package, workspacePackage.name, newVersionParsed.toString());
      });
    }

    logger.stdout(AnsiStyles.greenBright.bold(
        'Versioning successful. Ensure you commit and push your changes (if applicable).'));
  }

  Future<void> setDependentPackageVersionConstraint(
      MelosPackage package, String dependencyName, String version) {
    // By default dependency constraint using caret syntax to ensure the range allows
    // all versions guaranteed to be backwards compatible with the specified version.
    // For example, ^1.2.3 is equivalent to '>=1.2.3 <2.0.0', and ^0.1.2 is equivalent to '>=0.1.2 <0.2.0'.
    var versionConstraint = '^$version';

    // For nullsafety releases we use a >=currentVersion <nextMajorVersion constraint
    // to allow nullsafety prerelease id versions to function similar to semver without
    // the actual major, minor & patch versions changing.
    // e.g. >=1.2.0-1.0.nullsafety.0 <1.2.0-2.0.nullsafety.0
    if (version.toString().contains('.nullsafety.')) {
      final nextMajorFromCurrentVersion = versioning
          .nextVersion(Version.parse(version), SemverReleaseType.major)
          .toString();
      versionConstraint = '">=$version <$nextMajorFromCurrentVersion"';
    }

    return package.setDependencyVersion(dependencyName, versionConstraint);
  }

  Future<void> applyVersionsFromConventionalCommits() async {
    logger.stdout(AnsiStyles.yellow.bold('melos version'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}\n');

    final changelog = argResults['changelog'] as bool;
    var graduate = argResults['graduate'] as bool;
    final tag = argResults['git-tag-version'] as bool;
    final prerelease = argResults['prerelease'] as bool;
    final updateDependentConstraints =
        argResults['dependent-constraints'] as bool;
    var updateDependentVersions = argResults['dependent-versions'] as bool;
    final skipPrompt = argResults['yes'] as bool;
    final versionAll = argResults['all'] as bool;
    final preid = argResults['preid'] as String;
    final commitMessageTemplate = Template(_commitMessage, delimiters: '{ }');

    final packagesToVersion = <MelosPackage>{};
    final packageCommits = <String, List<ConventionalCommit>>{};
    final dependentPackagesToVersion = <MelosPackage>{};
    final packagesWithVersionableCommits = {};
    var pendingPackageUpdates = <MelosPendingPackageUpdate>[];

    if (graduate && prerelease) {
      logger.stdout(
        '${AnsiStyles.yellow('WARNING:')} graduate & prerelease flags cannot '
        'be combined. Versioning will continue with graduate off.',
      );
      graduate = false;
    }

    if (updateDependentVersions && !updateDependentConstraints) {
      logger.stdout(
        '${AnsiStyles.yellow('WARNING:')} the setting --dependent-versions is '
        'turned on but --dependent-constraints is turned off. Versioning '
        'will continue with this setting turned off.',
      );
      updateDependentVersions = false;
    }

    if (graduate) {
      for (final package in currentWorkspace.packages) {
        if (!package.version.isPreRelease) continue;

        pendingPackageUpdates.add(MelosPendingPackageUpdate(
          package,
          [],
          PackageUpdateReason.graduate,
          graduate: graduate,
          prerelease: prerelease,
          preid: preid,
        ));

        final packageUnscoped = currentWorkspace.packagesNoScope
            .firstWhere((element) => element.name == package.name);
        dependentPackagesToVersion
            .addAll(packageUnscoped.dependentsInWorkspace);
      }
    }
    await Pool(10).forEach<MelosPackage, void>(currentWorkspace.packages,
        (package) {
      if (!versionAll && package.isPrivate) {
        return Future.value();
      }
      return gitCommitsForPackage(
        package,
        since: globalResults['since'] as String,
      ).then((commits) {
        packageCommits[package.name] = commits
            .map((commit) => ConventionalCommit.parse(commit.message))
            .where((element) => element != null)
            .toList();
      });
    }).drain();

    for (final entry in packageCommits.entries) {
      final packageName = entry.key;
      final packageCommits = entry.value;
      final versionableCommits =
          packageCommits.where((e) => e.isVersionableCommit).toList();
      if (versionableCommits.isNotEmpty) {
        packagesWithVersionableCommits[packageName] = versionableCommits;
      }
    }

    for (final package in currentWorkspace.packages) {
      if (packagesWithVersionableCommits.containsKey(package.name)) {
        if (graduate && package.version.isPreRelease) continue;
        packagesToVersion.add(package);
        final packageUnscoped = currentWorkspace.packagesNoScope
            .firstWhere((element) => element.name == package.name);
        dependentPackagesToVersion
            .addAll(packageUnscoped.dependentsInWorkspace);
      }
    }

    pendingPackageUpdates
        .addAll(packagesToVersion.map((package) => MelosPendingPackageUpdate(
              package,
              packageCommits[package.name],
              PackageUpdateReason.commit,
              graduate: graduate,
              prerelease: prerelease,
              preid: preid,
            )));

    for (final package in dependentPackagesToVersion) {
      if (!packagesToVersion.contains(package) &&
          pendingPackageUpdates.firstWhere(
                (packageToVersion) =>
                    packageToVersion.package.name == package.name,
                orElse: () => null,
              ) ==
              null) {
        pendingPackageUpdates.add(MelosPendingPackageUpdate(
          package,
          [],
          PackageUpdateReason.dependency,
          // Dependent packages that should have graduated would have already
          // gone through graduation logic above. So graduate should use the default
          // of 'false' here so as not to graduate anything that was specifically
          // excluded.
          // graduate: false,
          prerelease: prerelease,
          // TODO Should dependent packages also get the same preid, can we expose this as an option?
          // TODO In the case of "nullsafety" it doesn't make sense for dependent packages to also become nullsafety preid versions.
          // preid: preid,
        ));
      }
    }

    // Filter out private packages.
    if (!versionAll) {
      pendingPackageUpdates = pendingPackageUpdates
          .where((update) => !update.package.isPrivate)
          .toList();
    }

    if (pendingPackageUpdates.isEmpty) {
      logger.stdout(AnsiStyles.yellow(
          'No packages were found that required versioning.'));
      logger.stdout(AnsiStyles.gray(
          'Hint: try running "melos list" with the same filtering options to see a list of packages that were included.'));
      logger.stdout(AnsiStyles.gray(
          'Hint: try running "melos version --all" to include private packages.'));
      return;
    }

    logger.stdout(
        AnsiStyles.magentaBright('The following packages will be updated:\n'));

    logger.stdout(listAsPaddedTable([
      [
        AnsiStyles.underline.bold('Package Name'),
        AnsiStyles.underline.bold('Current Version'),
        AnsiStyles.underline.bold('Updated Version'),
        AnsiStyles.underline.bold('Update Reason'),
      ],
      ...pendingPackageUpdates.where((pendingUpdate) {
        if (pendingUpdate.reason == PackageUpdateReason.dependency &&
            !updateDependentVersions &&
            !updateDependentConstraints) {
          return false;
        }
        return true;
      }).map((pendingUpdate) {
        return [
          AnsiStyles.italic(pendingUpdate.package.name),
          AnsiStyles.dim(pendingUpdate.currentVersion.toString()),
          if (pendingUpdate.reason == PackageUpdateReason.dependency &&
              !updateDependentVersions)
            '-'
          else
            AnsiStyles.green(pendingUpdate.nextVersion.toString()),
          AnsiStyles.italic((() {
            switch (pendingUpdate.reason) {
              case PackageUpdateReason.commit:
                final semverType = pendingUpdate.semverReleaseType
                    .toString()
                    .substring(pendingUpdate.semverReleaseType
                            .toString()
                            .indexOf('.') +
                        1);
                return 'updated with ${AnsiStyles.underline(semverType)} changes';
              case PackageUpdateReason.dependency:
                if (pendingUpdate.reason == PackageUpdateReason.dependency &&
                    !updateDependentVersions) {
                  return 'dependency constraints changed';
                }
                return 'dependency was updated';
              case PackageUpdateReason.graduate:
                return 'graduate to stable';
              default:
                return 'unknown';
            }
          })()),
        ];
      }),
    ], paddingSize: 3));

    final shouldContinue = skipPrompt || promptBool();
    if (!shouldContinue) {
      logger.stdout(AnsiStyles.red('Operation was canceled.'));
      exitCode = 1;
      return;
    }

    // Note: not pooling & parrellelzing rights to avoid possible file contention.
    await Future.forEach(pendingPackageUpdates,
        (MelosPendingPackageUpdate pendingPackageUpdate) async {
      // Update package pubspec version.
      if ((pendingPackageUpdate.reason == PackageUpdateReason.dependency &&
              updateDependentVersions) ||
          pendingPackageUpdate.reason != PackageUpdateReason.dependency) {
        await pendingPackageUpdate.package
            .setPubspecVersion(pendingPackageUpdate.nextVersion.toString());
      }

      // Update dependents.
      if (updateDependentConstraints) {
        await Future.forEach([
          ...pendingPackageUpdate.package.dependentsInWorkspace,
          ...pendingPackageUpdate.package.devDependentsInWorkspace
        ], (MelosPackage package) {
          return setDependentPackageVersionConstraint(
            package,
            pendingPackageUpdate.package.name,
            // Note if we're not updating dependent versions then we use the current
            // version rather than the next version as the next version would never
            // have been applied.
            (pendingPackageUpdate.reason == PackageUpdateReason.dependency &&
                    !updateDependentVersions)
                ? pendingPackageUpdate.package.version.toString()
                : pendingPackageUpdate.nextVersion.toString(),
          );
        });
      }

      // Update changelogs if requested.
      if (changelog) {
        if ((pendingPackageUpdate.reason == PackageUpdateReason.dependency &&
                updateDependentVersions) ||
            pendingPackageUpdate.reason != PackageUpdateReason.dependency) {
          await pendingPackageUpdate.changelog.write();
        }
      }
    });

    // TODO allow support for individual package lifecycle version scripts
    if (currentWorkspace.config.scripts.exists('version')) {
      logger.stdout('Running "version" lifecycle script...\n');
      await MelosCommandRunner.instance.run(['run', 'version']);
    }

    if (tag) {
      // 1) Stage changes:
      await Future.forEach(pendingPackageUpdates,
          (MelosPendingPackageUpdate pendingPackageUpdate) async {
        await gitAdd('pubspec.yaml',
            workingDirectory: pendingPackageUpdate.package.path);
        await gitAdd('CHANGELOG.md',
            workingDirectory: pendingPackageUpdate.package.path);
        await Future.forEach([
          ...pendingPackageUpdate.package.dependentsInWorkspace,
          ...pendingPackageUpdate.package.devDependentsInWorkspace,
        ], (MelosPackage dependentPackage) async {
          await gitAdd('pubspec.yaml', workingDirectory: dependentPackage.path);
        });

        // TODO this is a temporary workaround for committing generated dart files.
        // TODO remove once options exposed for this in a later release.
        if (pendingPackageUpdate.package.name == 'melos') {
          await gitAdd('**/*.g.dart',
              workingDirectory: pendingPackageUpdate.package.path);
        }
      });

      // 2) Commit changes:
      final publishedPackagesMessage = pendingPackageUpdates
          .where((pendingUpdate) {
            if (pendingUpdate.reason == PackageUpdateReason.dependency &&
                !updateDependentVersions) {
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
        workingDirectory: currentWorkspace.path,
      );

      // // 3) Tag changes:
      await Future.forEach(pendingPackageUpdates,
          (MelosPendingPackageUpdate pendingPackageUpdate) async {
        if (pendingPackageUpdate.reason == PackageUpdateReason.dependency &&
            !updateDependentVersions) {
          return;
        }
        // TODO '--tag-version-prefix' support (if we decide to support it later) would pass prefix named arg to gitTagForPackageVersion:
        final tag = gitTagForPackageVersion(pendingPackageUpdate.package.name,
            pendingPackageUpdate.nextVersion.toString());
        await gitTagCreate(tag, pendingPackageUpdate.changelog.markdown,
            workingDirectory: pendingPackageUpdate.package.path);
      });
    }

    // TODO allow support for individual package lifecycle postversion scripts
    if (currentWorkspace.config.scripts.exists('postversion')) {
      logger.stdout('Running "postversion" lifecycle script...\n');
      await MelosCommandRunner.instance.run(['run', 'postversion']);
    }

    // TODO automatic push support
    logger.stdout(AnsiStyles.greenBright.bold(
        'Versioning successful. Ensure you push your git changes and tags (if applicable) via ${AnsiStyles.bgBlack.gray('git push --follow-tags')}'));
  }

  @override
  Future<void> run() async {
    if (argResults.rest.isNotEmpty) {
      await applyUserSpecifiedVersion();
    } else {
      await applyVersionsFromConventionalCommits();
    }
  }
}
