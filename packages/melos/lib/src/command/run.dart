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

import 'package:args/command_runner.dart' show Command;
import 'package:prompts/prompts.dart' as prompts;
import 'package:ansi_styles/ansi_styles.dart';

import '../common/logger.dart';
import '../common/utils.dart';
import '../common/workspace.dart';
import '../common/workspace_script.dart';

class RunCommand extends Command {
  @override
  final String name = 'run';

  @override
  final String description =
      'Run a script by name defined in the workspace melos.yaml config file.';

  @override
  final String invocation = 'melos run <name>';

  RunCommand() {
    argParser.addFlag(
      'no-select',
      defaultsTo: false,
      negatable: false,
      help:
          'Skips the prompt to select a package (if defined in the script configuration). Filters defined in the scripts "select-package" options will however still be applied.',
    );
  }

  @override
  void run() async {
    if (currentWorkspace.config.scripts.namesExcludingLifecycles.isEmpty) {
      logger.stderr(
        AnsiStyles.yellow(
            "Warning: This workspace has no scripts defined in it's 'melos.yaml' file.\n"),
      );
      logger.stdout(usage);
      exitCode = 1;
      return;
    }

    String scriptName;

    if (argResults.rest.isEmpty) {
      if (currentWorkspace.config.scripts.namesExcludingLifecycles.isNotEmpty) {
        var scriptChoices = currentWorkspace
            .config.scripts.namesExcludingLifecycles
            .map((name) {
          var script = currentWorkspace.config.scripts.script(name);
          var styledName = AnsiStyles.cyan(script.name);
          var styledDescription = script.description != null
              ? '\n    └> ${AnsiStyles.gray(script.description.trim().split('\n').join('\n       '))}'
              : '';

          return '$styledName$styledDescription';
        }).toList();
        var selectedScript = prompts.choose(
          AnsiStyles.white('Select a script to run in this workspace'),
          scriptChoices,
          interactive: false,
        );
        var selectedScriptIndex = scriptChoices.indexOf(selectedScript);
        scriptName = currentWorkspace
            .config.scripts.namesExcludingLifecycles[selectedScriptIndex];
        logger.stdout('');
      } else {
        logger.stderr('You have no scripts defined in your melos.yaml file.\n');
        logger.stdout(usage);
        exitCode = 1;
        return;
      }
    }

    scriptName ??= argResults.rest[0];

    if (!currentWorkspace.config.scripts.exists(scriptName)) {
      logger.stderr('Invalid run script name specified.\n');
      if (currentWorkspace.config.scripts.names.isNotEmpty) {
        logger.stdout('Available scripts:');
        currentWorkspace.config.scripts.names.forEach((key) {
          logger.stdout(' - ${AnsiStyles.blue(key)}');
        });
        logger.stdout('');
      }
      logger.stdout(usage);
      exitCode = 1;
      return;
    }

    MelosScript script = currentWorkspace.config.scripts.script(scriptName);

    var environment = {
      'MELOS_ROOT_PATH': currentWorkspace.path,
      ...script.env,
    };

    if (script.shouldPromptForPackageSelection) {
      await currentWorkspace.loadPackagesWithFilters(
        scope: script.selectPackageOptions[filterOptionScope] as List<String>,
        ignore: script.selectPackageOptions[filterOptionIgnore] as List<String>,
        dirExists:
            script.selectPackageOptions[filterOptionDirExists] as List<String>,
        fileExists:
            script.selectPackageOptions[filterOptionFileExists] as List<String>,
        since: script.selectPackageOptions[filterOptionSince] as String,
        skipPrivate: script.selectPackageOptions[filterOptionNoPrivate] as bool,
        published: script.selectPackageOptions[filterOptionPublished] as bool,
        hasFlutter: script.selectPackageOptions[filterOptionFlutter] as bool,
        dependsOn:
            script.selectPackageOptions[filterOptionDependsOn] as List<String>,
        noDependsOn: script.selectPackageOptions[filterOptionNoDependsOn]
            as List<String>,
      );

      var choices = currentWorkspace.packages
          .map((e) => AnsiStyles.cyan(e.name))
          .toList();

      if (choices.isEmpty) {
        logger.stderr(AnsiStyles.yellow(
            'No packages found with the currently applied workspace filters.\n'));
        logger.stdout(usage);
        return;
      }

      // Add a select all choice.
      if (choices.length > 1) {
        choices = [
          AnsiStyles.green('*'),
          ...choices,
        ];
      }

      String selectedPackage;
      if (choices.length == 1) {
        // Only 1 package - no need to prompt the user for a selection.
        selectedPackage = currentWorkspace.packages[0].name;
      } else if (argResults['no-select'] == true) {
        // Skipping selection if flag present.
        selectedPackage = choices[0];
      } else {
        // Prompt user to select a package.
        selectedPackage = prompts.choose(
          [
            AnsiStyles.white('Select a package to run the '),
            AnsiStyles.cyan(scriptName),
            AnsiStyles.white(' script'),
            AnsiStyles.gray(''),
          ].join(),
          choices,
          interactive: false,
          defaultsTo: choices[0],
        );
      }

      var selectedPackageIndex =
          choices.length > 1 ? choices.indexOf(selectedPackage) : 1;
      // Comma delimited string of packages selected (all or a single package).
      var packagesEnv = selectedPackageIndex == 0 && choices.length > 1
          ? currentWorkspace.packages.map((e) => e.name).toList().join(',')
          : currentWorkspace.packages[selectedPackageIndex - 1].name;
      // MELOS_PACKAGES environment is detected by melos itself when through
      // a defined script, this comma delimited list of package names is used
      // instead of any filters if detected.
      environment[envKeyMelosPackages] = packagesEnv;
      print('\n');
    }

    var scriptSource = currentWorkspace.config.scripts.script(scriptName).run;
    var scriptParts = scriptSource.split(' ');

    logger.stdout(AnsiStyles.yellow.bold('melos run $scriptName'));
    logger.stdout(
        '   └> ${AnsiStyles.cyan.bold(scriptSource.replaceAll('\n', ''))}');
    logger.stdout('       └> ${AnsiStyles.yellow.bold('RUNNING')}\n');

    int processExitCode = await startProcess(scriptParts,
        environment: environment, workingDirectory: currentWorkspace.path);

    logger.stdout('');
    logger.stdout(AnsiStyles.yellow.bold('melos run $scriptName'));
    logger.stdout(
        '   └> ${AnsiStyles.cyan.bold(scriptSource.replaceAll('\n', ''))}');

    if (processExitCode > 0) {
      logger.stdout('       └> ${AnsiStyles.red.bold('FAILED')}');
      exitCode = processExitCode;
    } else {
      logger.stdout('       └> ${AnsiStyles.green.bold('SUCCESS')}');
    }
  }
}
