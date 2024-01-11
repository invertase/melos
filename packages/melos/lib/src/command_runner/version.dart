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
import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:pub_semver/pub_semver.dart';

import '../commands/runner.dart';
import '../common/utils.dart';
import '../common/versioning.dart';
import '../package.dart';
import 'base.dart';

/// Template variable that is replaced with versioned package info in commit
/// messages.
const packageVersionsTemplateVar = 'new_package_versions';

/// The default commit message used when versioning.
const defaultCommitMessage =
    'chore(release): publish packages\n\n{$packageVersionsTemplateVar}';

class VersionCommand extends MelosCommand {
  VersionCommand(super.config) {
    setupPackageFilterParser();
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
          'Graduate current prerelease versioned packages to stable versions, '
          'e.g. "0.10.0-dev.1" would become "0.10.0". Cannot be combined with '
          'prerelease flag. Applies only to Conventional Commits based '
          'versioning.',
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
          'with "--dependent-constraints" enabled.',
    );
    argParser.addFlag(
      'git-tag-version',
      abbr: 't',
      defaultsTo: true,
      help: 'By default, melos version will tag the release. Pass '
          '--no-git-tag-version to disable the behaviour.',
    );
    argParser.addFlag(
      'git-commit-version',
      abbr: 'C',
      defaultsTo: true,
      help: 'By default, melos version will commit changes to pubspec.yaml and '
          'changelog files. Pass --no-git-commit-version to disable the '
          'behaviour, passing this also implies --no-git-tag-version.',
    );
    argParser.addFlag(
      'release-url',
      abbr: 'r',
      help: 'Generate and print a link to the prefilled release creation page '
          'for each package after versioning',
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
      help: 'Skip the Y/n confirmation prompt.',
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
    argParser.addOption(
      'dependent-preid',
      help: 'This option is the same as --preid, but only applies to packages '
          'that are versioned due to a change in a dependency version. '
          'When this option is not provided but the --preid option is, the '
          'value of the --preid option will be used instead.',
    );
    argParser.addMultiOption(
      'manual-version',
      abbr: 'V',
      help: 'Manually specify a version change for a package. Can be used '
          'multiple times. Each value must be in the format '
          '"<package name>:<major|patch|minor|build|exactVersion>". '
          'Cannot be combined with --graduate or --prerelease flag.',
    );
  }

  @override
  final String name = 'version';

  @override
  final String description =
      'Automatically version and generate changelogs based on the Conventional '
      'Commits specification. Supports all package filtering options.';

  @override
  final String invocation = '''
 ${AnsiStyles.bold('melos version')}
          Version packages automatically using the Conventional Commits specification.

        ${AnsiStyles.bold('melos version')} <package name> <major|patch|minor|build|exactVersion>
          Manually update the version of a package, and update all packages that depend on it.
''';

  @override
  Future<void> run() async {
    final melos = Melos(logger: logger, config: config);

    final force = argResults!['yes'] as bool;
    final updateDependentsConstraints =
        argResults!['dependent-constraints'] as bool;
    final tag = argResults!['git-tag-version'] as bool;
    final commit = argResults!['git-commit-version'] as bool;
    final releaseUrl = argResults!.optional('release-url') as bool?;
    final changelog = argResults!['changelog'] as bool;
    final commitMessage =
        (argResults!['message'] as String?)?.replaceAll(r'\n', '\n');

    if (argResults!.rest.isNotEmpty) {
      if (argResults!.rest.length != 2) {
        logger.error(
          'When manually setting a version to apply to a package you must '
          'specify both <packageName> and <newVersion> arguments when calling '
          '"melos version".',
        );
        exitCode = 1;
        return;
      }

      final packageName = argResults!.rest[0];
      final versionChange = _parseManualVersionChange(argResults!.rest[1]);
      if (versionChange == null) {
        return;
      }

      return melos.version(
        // We only want to version the specified package and not all packages
        // that could be versioned.
        packageFilters: PackageFilters(scope: [Glob(packageName)]),
        manualVersions: {packageName: versionChange},
        force: force,
        gitTag: tag,
        gitCommit: commit,
        releaseUrl: releaseUrl,
        updateChangelog: changelog,
        updateDependentsConstraints: updateDependentsConstraints,
        updateDependentsVersions: false,
        message: commitMessage,
      );
    } else {
      var asStableRelease = argResults!['graduate'] as bool;
      final asPrerelease = argResults!['prerelease'] as bool;
      var updateDependentsVersions = argResults!['dependent-versions'] as bool;
      final versionPrivatePackages = argResults!['all'] as bool;
      final preid = argResults!['preid'] as String?;
      final dependentPreid = argResults!['dependent-preid'] as String?;
      final manualVersionArgs = argResults!['manual-version'] as List<String>;

      final manualVersions = _parseManualVersions(manualVersionArgs);
      if (manualVersions == null) {
        return;
      }

      if (asPrerelease && asStableRelease) {
        logger.warning(
          'graduate & prerelease flags cannot be combined. Versioning will '
          'continue with graduate off.',
        );
        asStableRelease = false;
      }

      if (updateDependentsVersions && !updateDependentsConstraints) {
        logger.warning(
          'The setting --dependent-versions is turned on but '
          '--dependent-constraints is turned off. Versioning will continue '
          'with this setting turned off.',
        );
        updateDependentsVersions = false;
      }

      await melos.version(
        global: global,
        packageFilters: parsePackageFilters(config.path),
        force: force,
        gitTag: tag,
        gitCommit: commit,
        releaseUrl: releaseUrl,
        updateChangelog: changelog,
        updateDependentsConstraints: updateDependentsConstraints,
        updateDependentsVersions: updateDependentsVersions,
        preid: preid,
        dependentPreid: dependentPreid,
        asPrerelease: asPrerelease,
        asStableRelease: asStableRelease,
        message: commitMessage,
        versionPrivatePackages: versionPrivatePackages,
        manualVersions: manualVersions,
      );
    }
  }

  ManualVersionChange? _parseManualVersionChange(String argument) {
    // ignore: parameter_assignments
    argument = argument.trim();

    if (argument == 'build') {
      return ManualVersionChange.incrementBuildNumber();
    }

    final semverReleaseType = SemverReleaseType.values
        .firstWhereOrNull((releaseType) => releaseType.name == argument);
    if (semverReleaseType != null) {
      return ManualVersionChange.incrementBySemverReleaseType(
        semverReleaseType,
      );
    }

    try {
      return ManualVersionChange(Version.parse(argument));
    } catch (_) {
      exitCode = 1;
      logger.error('version "$argument" is not a valid package version.');
      return null;
    }
  }

  Map<String, ManualVersionChange>? _parseManualVersions(
    List<String> arguments,
  ) {
    final manualVersions = <String, ManualVersionChange>{};

    for (final argument in arguments) {
      final parts = argument.split(':');
      if (parts.length != 2) {
        exitCode = 1;
        logger.error(
          '--manual-version arguments must be in the format '
          '"<package name>:<major|patch|minor|build|exactVersion>".',
        );
        return null;
      }

      final packageName = parts[0];
      final version = _parseManualVersionChange(parts[1]);
      if (version == null) {
        return null;
      }

      manualVersions[packageName] = version;
    }

    return manualVersions;
  }
}
