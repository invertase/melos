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
import 'package:pub_semver/pub_semver.dart';

import '../commands/runner.dart';
import '../workspace_configs.dart';
import 'base.dart';

/// Template variable that is replaced with versioned package info in commit
/// messages.
const packageVersionsTemplateVar = 'new_package_versions';

/// The default commit message used when versioning.
const defaultCommitMessage =
    'chore(release): publish packages\n\n{$packageVersionsTemplateVar}';

class VersionCommand extends MelosCommand {
  VersionCommand(MelosWorkspaceConfig config) : super(config) {
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
    argParser.addMultiOption(
      'version',
      abbr: 'V',
      help: 'Manually specify a version for a package. Can be used multiple '
          'times. Each value must be in the format "package:version". '
          'Applies only to Conventional Commits based versioning. Cannot be '
          'combined with --graduate or --prerelease flag.',
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

  @override
  Future<void> run() async {
    final melos = Melos(logger: logger, config: config);

    final force = argResults!['yes'] as bool;
    final updateDependentsConstraints =
        argResults!['dependent-constraints'] as bool;
    final tag = argResults!['git-tag-version'] as bool;
    final changelog = argResults!['changelog'] as bool;

    if (argResults!.rest.isNotEmpty) {
      if (argResults!.rest.length != 2) {
        logger?.stdout(
          '${AnsiStyles.redBright('ERROR:')} when manually setting a version to '
          'apply to a package you must specify both <packageName> and <newVersion> '
          'arguments when calling "melos version".',
        );
        exitCode = 1;
        return;
      }

      final packageName = argResults!.rest[0];

      Version version;
      try {
        version = Version.parse(argResults!.rest[1]);
      } catch (_) {
        exitCode = 1;
        logger?.stdout(
          '${AnsiStyles.redBright('ERROR:')} version "${argResults!.rest[1]}" is not a valid package version.',
        );
        return;
      }

      return melos.version(
        packageName: packageName,
        newVersion: version,
        force: force,
        gitTag: tag,
        updateChangelog: changelog,
        updateDependentsConstraints: updateDependentsConstraints,
      );
    } else {
      final commitMessage =
          (argResults!['message'] as String?)?.replaceAll(r'\n', '\n');

      final changelog = argResults!['changelog'] as bool;
      var asStableRelease = argResults!['graduate'] as bool;
      final tag = argResults!['git-tag-version'] as bool;
      final asPrerelease = argResults!['prerelease'] as bool;
      final updateDependentsConstraints =
          argResults!['dependent-constraints'] as bool;
      var updateDependentsVersions = argResults!['dependent-versions'] as bool;
      final force = argResults!['yes'] as bool;
      final versionPrivatePackages = argResults!['all'] as bool;
      final preid = argResults!['preid'] as String?;
      final manualVersionArgs = argResults!['version'] as List<String>;
      final manualVersions = Map.fromEntries(
        manualVersionArgs.map((arg) {
          final parts = arg.split(':');
          if (parts.length != 2) {
            throw ArgumentError(
              '`version` arguments must be in the format "package:version".',
            );
          }

          return MapEntry(parts[0], Version.parse(parts[1]));
        }),
      );

      if (asPrerelease && asStableRelease) {
        logger?.stdout(
          '${AnsiStyles.yellow('WARNING:')} graduate & prerelease flags cannot '
          'be combined. Versioning will continue with graduate off.',
        );
        asStableRelease = false;
      }

      if (updateDependentsVersions && !updateDependentsConstraints) {
        logger?.stdout(
          '${AnsiStyles.yellow('WARNING:')} the setting --dependent-versions is '
          'turned on but --dependent-constraints is turned off. Versioning '
          'will continue with this setting turned off.',
        );
        updateDependentsVersions = false;
      }

      await melos.autoVersion(
        filter: parsePackageFilter(config.path),
        force: force,
        gitTag: tag,
        updateChangelog: changelog,
        updateDependentsConstraints: updateDependentsConstraints,
        updateDependentsVersions: updateDependentsVersions,
        preid: preid,
        asPrerelease: asPrerelease,
        asStableRelease: asStableRelease,
        message: commitMessage,
        versionPrivatePackages: versionPrivatePackages,
        manualVersions: manualVersions,
      );
    }
  }
}
