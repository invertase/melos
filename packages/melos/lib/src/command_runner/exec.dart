import 'dart:io';

import 'package:glob/glob.dart';

import '../commands/runner.dart';
import '../common/environment_variable_key.dart';
import '../common/platform.dart';
import '../common/utils.dart';
import 'base.dart';

class ExecCommand extends MelosCommand {
  ExecCommand(super.config) {
    setupPackageFilterParser();
    argParser.addOption(
      'concurrency',
      defaultsTo: Platform.numberOfProcessors.toString(),
      abbr: 'c',
    );
    argParser.addFlag(
      'fail-fast',
      abbr: 'f',
      help:
          'Whether exec should fail fast and not execute the script in further '
          'packages if the script fails in a individual package.',
    );
    argParser.addFlag(
      'group-logs',
      help:
          'Whether the output of each package should be buffered and printed '
          'grouped per package once every package has finished, instead of '
          'being streamed and interleaved while the packages run. The output '
          'of packages in which the command failed is printed last. Only has '
          'an effect when running in more than one package with a concurrency '
          'greater than 1.',
    );
    argParser.addFlag(
      'order-dependents',
      abbr: 'o',
      help:
          'Whether exec should order the execution of the script in multiple '
          'packages based on the dependency graph of the packages. The script '
          'will be executed in leaf packages first and then in packages that '
          'depend on them and so on. This is useful for example, for a script '
          'that generates code in multiple packages, which depend on each '
          'other.',
    );
    argParser.addMultiOption(
      'sources',
      valueHelp: 'glob',
      splitCommas: false,
      help:
          'Globs relative to the root of each package. The command is skipped '
          'in the packages in which the matching files, and those of their '
          'dependencies in the workspace, did not change since the command '
          'last succeeded. Can be specified multiple times.',
    );
    argParser.addFlag(
      'force',
      negatable: false,
      help:
          'Run the command in every package, even in the packages in which '
          'the files matching --sources did not change.',
    );
    argParser.addFlag(
      'ignore-sources',
      help:
          'Ignore --sources, so that the command runs in every package '
          'without calculating or storing checksums.',
    );
  }

  @override
  bool get allowTrailingOptions => false;

  @override
  final String name = 'exec';

  @override
  final String description =
      'Execute an arbitrary command in each package. Supports all package '
      'filtering options.';

  @override
  Future<void> run() async {
    final execArgs = argResults!.rest;

    if (execArgs.isEmpty) {
      logger.stdout(description);
      logger.stdout(argParser.usage);
      exit(1);
    }

    final melos = Melos(logger: logger, config: config);

    final packageFilters = parsePackageFilters(config.path);
    final failFast = argResults!.optional('fail-fast') as bool?;
    final orderDependents = argResults!.optional('order-dependents') as bool?;
    final groupLogs = argResults!.optional('group-logs') as bool?;
    final sources = argResults!['sources'] as List<String>;
    for (final source in sources) {
      try {
        Glob(source);
      } on FormatException catch (error) {
        usageException(
          'The glob "$source" of --sources is invalid: ${error.message}',
        );
      }
    }
    final environment = currentPlatform.environment;
    final force =
        argResults!['force'] as bool ||
        environment[EnvironmentVariableKey.melosForce] == 'true';
    final ignoreSources =
        argResults!.optional('ignore-sources') as bool? ??
        bool.tryParse(
          environment[EnvironmentVariableKey.melosIgnoreSources] ?? '',
        );

    return melos.exec(
      execArgs,
      concurrency: concurrencyOption,
      failFast: failFast,
      orderDependents: orderDependents,
      groupLogs: groupLogs,
      sources: sources,
      force: force,
      ignoreSources: ignoreSources,
      global: global,
      packageFilters: packageFilters,
    );
  }
}
