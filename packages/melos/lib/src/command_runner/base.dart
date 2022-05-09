import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';

import '../common/glob.dart';
import '../common/utils.dart';
import '../global_options.dart';
import '../package.dart';
import '../workspace_configs.dart';

abstract class MelosCommand extends Command<void> {
  MelosCommand(this.config);

  final MelosWorkspaceConfig config;

  /// The global Melos options parsed from the command line.
  late final global = _parseGlobalOptions();

  Logger? get logger => global.verbose ? Logger.verbose() : Logger.standard();

  /// The `melos.yaml` configuration for this command.
  /// see [ArgParser.allowTrailingOptions]
  bool get allowTrailingOptions => true;

  /// Overridden to support line wrapping when printing usage.
  @override
  late final ArgParser argParser = ArgParser(
    usageLineLength: terminalWidth,
    allowTrailingOptions: allowTrailingOptions,
  );

  GlobalOptions _parseGlobalOptions() {
    return GlobalOptions(
      verbose: globalResults![globalOptionVerbose]! as bool,
      sdkPath: globalResults![globalOptionSdkPath] as String?,
    );
  }

  void setupPackageFilterParser() {
    argParser.addFlag(
      filterOptionPrivate,
      help: 'Whether to include or exclude packages with `publish_to: "none"`. '
          'By default, the filter has no effect.',
      defaultsTo: null,
    );

    argParser.addFlag(
      filterOptionPublished,
      defaultsTo: null,
      help: 'Filter packages where the current local package version exists on '
          'pub.dev. Or "-no-published" to filter packages that have not had '
          'their current version published yet.',
    );

    argParser.addFlag(
      filterOptionNullsafety,
      defaultsTo: null,
      help:
          'Filter packages where the current local version uses a "nullsafety" '
          'prerelease preid. Or "-no-nullsafety" to filter packages where '
          'their current version does not have a "nullsafety" preid.',
    );

    argParser.addFlag(
      filterOptionFlutter,
      defaultsTo: null,
      help: 'Filter packages where the package depends on the Flutter SDK. Or '
          '"-no-flutter" to filter packages that do not depend on the Flutter '
          'SDK.',
    );

    argParser.addMultiOption(
      filterOptionScope,
      valueHelp: 'glob',
      help: 'Include only packages with names matching the given glob. This '
          'option can be repeated.',
    );

    argParser.addMultiOption(
      filterOptionIgnore,
      valueHelp: 'glob',
      help: 'Exclude packages with names matching the given glob. This option '
          'can be repeated.',
    );

    argParser.addOption(
      filterOptionSince,
      valueHelp: 'ref',
      help: 'Only include packages that have been changed since the specified '
          '`ref`, e.g. a commit sha or git tag.',
    );

    argParser.addMultiOption(
      filterOptionDirExists,
      valueHelp: 'dirRelativeToPackageRoot',
      help: 'Include only packages where a specific directory exists inside '
          'the package.',
    );

    argParser.addMultiOption(
      filterOptionFileExists,
      valueHelp: 'fileRelativeToPackageRoot',
      help:
          'Include only packages where a specific file exists in the package.',
    );

    argParser.addMultiOption(
      filterOptionDependsOn,
      valueHelp: 'dependentPackageName',
      help: 'Include only packages that depend on a specific package. This '
          'option can be repeated, to further filter the list of packages.',
    );

    argParser.addMultiOption(
      filterOptionNoDependsOn,
      valueHelp: 'noDependantPackageName',
      help: "Include only packages that *don't* depend on a specific package. "
          'This option can be repeated.',
    );

    argParser.addFlag(
      filterOptionIncludeDependents,
      negatable: false,
      help: 'Include all transitive dependents for each package that matches '
          'the other filters. The included packages skip --ignore and '
          '--since checks.',
    );

    argParser.addFlag(
      filterOptionIncludeDependencies,
      negatable: false,
      help: 'Include all transitive dependencies for each package that '
          'matches the other filters. The included packages skip --ignore '
          'and --since checks.',
    );
  }

  PackageFilter parsePackageFilter(
    String workingDirPath, {
    bool sinceEnabled = true,
  }) {
    assert(
      argResults?.command?.name != 'version' &&
          argResults?.command?.name != 'run',
      'unimplemented',
    );

    final since =
        sinceEnabled ? argResults![filterOptionSince] as String? : null;
    final scope = argResults![filterOptionScope] as List<String>? ?? [];
    final ignore = argResults![filterOptionIgnore] as List<String>? ?? [];

    return PackageFilter(
      scope: scope
          .map((e) => createGlob(e, currentDirectoryPath: workingDirPath))
          .toList(),
      ignore: ignore
          .map((e) => createGlob(e, currentDirectoryPath: workingDirPath))
          .toList()
        ..addAll(config.ignore),
      updatedSince: since,
      includePrivatePackages: argResults![filterOptionPrivate] as bool?,
      published: argResults![filterOptionPublished] as bool?,
      nullSafe: argResults![filterOptionNullsafety] as bool?,
      dirExists: argResults![filterOptionDirExists] as List<String>? ?? [],
      fileExists: argResults![filterOptionFileExists] as List<String>? ?? [],
      flutter: argResults![filterOptionFlutter] as bool?,
      dependsOn: argResults![filterOptionDependsOn] as List<String>? ?? [],
      noDependsOn: argResults![filterOptionNoDependsOn] as List<String>? ?? [],
      includeDependents: argResults![filterOptionIncludeDependents] as bool,
      includeDependencies: argResults![filterOptionIncludeDependencies] as bool,
    );
  }
}
