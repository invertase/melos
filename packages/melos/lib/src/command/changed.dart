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
import 'package:args/command_runner.dart' show Command;
import 'package:melos/src/common/logger.dart';
import 'package:melos/src/common/package.dart';
import 'package:melos/src/common/workspace.dart';

class ChangedCommand extends Command {
  @override
  final String name = 'changed';

  @override
  final String description =
      'Lists all the packages that have been affected by changes since a given commit/tag.';

  @override
  final String invocation = 'melos changed <commit/tag>';

  @override
  void run() async {
    if (argResults.rest.isEmpty) {
      logger.stderr(
        AnsiStyles.yellow('Warning: No commit/tag specified\n'),
      );
      logger.stdout(usage);
      exitCode = 1;
      return;
    }

    String commit = argResults.rest[0];

    logger.stdout(
        AnsiStyles.yellow('Calculating affected packages since $commit'));

    final processResult = await Process.run('git', [
      'diff',
      '--name-only',
      'HEAD',
      commit,
    ]);

    Set<MelosPackage> changedPackages = {};

    List<String> affectedFiles = (processResult.stdout as String)
        .split('\n')
        .where((element) => element.trim().isNotEmpty)
        .toList();

    // Cross check packages with affected files to determine affected packages
    currentWorkspace.packages.forEach((p) {
      var file = affectedFiles.firstWhere(
        (element) {
          return element.startsWith(p.pathRelativeToWorkspace);
        },
        orElse: () => null,
      );
      if (file != null) {
        changedPackages.add(p);
      }
    });

    Set<MelosPackage> affectedPackages = findDependents(changedPackages);
    affectedPackages.forEach((package) {
      print('${package.name}');
    });
  }

  // Recursively finds all the dependents of a set of packages
  Set<MelosPackage> findDependents(Set<MelosPackage> packages) {
    Set<MelosPackage> affectedPackages = {};
    packages.forEach((element) {
      affectedPackages.add(element);
      affectedPackages
          .addAll(findDependents(element.dependentsInWorkspace.toSet()));
    });
    return affectedPackages;
  }
}
