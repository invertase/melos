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

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart';

import '../../melos.dart';
import 'changelog.dart';
import 'pending_package_update.dart';

class WorkspaceChangelog {
  WorkspaceChangelog(
    this.workspace,
    this.title,
    this.pendingPackageUpdates,
    this.logger,
  );

  final MelosWorkspace workspace;
  final String title;
  final Logger? logger;
  final List<MelosPendingPackageUpdate> pendingPackageUpdates;

  String get _changelogFileHeader {
    return '# Change Log\n\nAll notable changes to this project will be documented in this file.\nSee [Conventional Commits](https://conventionalcommits.org) for commit guidelines.\n';
  }

  String _packageVersionTitle(MelosPendingPackageUpdate update) {
    return '`${update.package.name}` - `v${update.nextVersion}`';
  }

  String _packageVersionMarkdownAnchor(MelosPendingPackageUpdate update) {
    return '#${_packageVersionTitle(update).replaceAll(' ', '-').replaceAll(RegExp('[^a-zA-Z_0-9-]'), '')}';
  }

  String get markdown {
    final body = StringBuffer();
    final dependencyOnlyPackages = pendingPackageUpdates
        .where((update) => update.reason == PackageUpdateReason.dependency);
    final graduatedPackages = pendingPackageUpdates
        .where((update) => update.reason == PackageUpdateReason.graduate);
    final packagesWithBreakingChanges =
        pendingPackageUpdates.where((update) => update.hasBreakingChanges);
    final packagesWithOtherChanges =
        pendingPackageUpdates.where((update) => !update.hasBreakingChanges);

    body.writeln(_changelogFileHeader);
    body.writeln('## $title');
    body.writeln();
    body.writeln('### Changes');
    body.writeln();
    body.writeln('---');
    body.writeln();
    body.writeln('Packages with breaking changes:');
    body.writeln();
    if (packagesWithBreakingChanges.isEmpty) {
      body.writeln(' - There are no breaking changes in this release.');
    } else {
      for (final update in packagesWithBreakingChanges) {
        body.writeln(
          ' - [${_packageVersionTitle(update)}](${_packageVersionMarkdownAnchor(update)})',
        );
      }
    }
    body.writeln();
    body.writeln('Packages with other changes:');
    body.writeln();
    if (packagesWithOtherChanges.isEmpty) {
      body.writeln(' - There are no other changes in this release.');
    } else {
      for (final update in packagesWithOtherChanges) {
        body.writeln(
          ' - [${_packageVersionTitle(update)}](${_packageVersionMarkdownAnchor(update)})',
        );
      }
    }
    if (graduatedPackages.isNotEmpty) {
      body.writeln();
      body.writeln(
        'Packages graduated to a stable release (see pre-releases prior to the stable version for changelog entries):',
      );
      body.writeln();
      for (final update in graduatedPackages) {
        body.writeln(
          ' - ${_packageVersionTitle(update)}',
        );
      }
    }
    if (dependencyOnlyPackages.isNotEmpty) {
      body.writeln();
      body.writeln('Packages with dependency updates only:');
      body.writeln();
      body.writeln(
        '> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.',
      );
      body.writeln();
      for (final update in dependencyOnlyPackages) {
        body.writeln(
          ' - ${_packageVersionTitle(update)}',
        );
      }
    }
    if (packagesWithOtherChanges.isNotEmpty ||
        packagesWithBreakingChanges.isNotEmpty) {
      final allChanges = packagesWithBreakingChanges.toList()
        ..addAll(packagesWithOtherChanges);
      body.writeln();
      body.writeln('---');
      body.writeln();

      for (final update in allChanges) {
        if (update.reason == PackageUpdateReason.dependency) {
          // Dependency only updates have no changelog entries
          // and are already listed in the previous
          // "Packages with dependency updates only" section.
          continue;
        }
        body.writeln('#### ${_packageVersionTitle(update)}');
        body.writeln();

        body.writePackageUpdateChanges(update);
      }
    }

    return body.toString();
  }

  String get path {
    return joinAll([workspace.path, 'CHANGELOG.md']);
  }

  @override
  String toString() {
    return markdown;
  }

  Future<String> read() async {
    final file = File(path);
    final exists = file.existsSync();
    if (exists) {
      final contents = await file.readAsString();
      return contents.replaceFirst(_changelogFileHeader, '');
    }
    return '';
  }

  Future<void> write() async {
    var contents = await read();
    if (contents.contains(markdown)) {
      logger?.trace(
        'Identical changelog content for ${workspace.name} already exists, skipping.',
      );
      return;
    }
    contents = '$markdown$contents';

    await File(path).writeAsString(contents);
  }
}
