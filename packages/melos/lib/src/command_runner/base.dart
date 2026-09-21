import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:glob/glob.dart';

import '../common/environment_variable_key.dart';
import '../common/glob.dart';
import '../common/platform.dart';
import '../common/utils.dart';
import '../global_options.dart';
import '../logging.dart';
import '../package.dart';
import '../workspace_config.dart';

/// Resolves whether Melos should only print warnings, errors and the output of
/// failed commands.
///
/// The `--quiet` command line option has precedence over the `MELOS_QUIET`
/// environment variable, which has precedence over the `quiet` option in
/// `pubspec.yaml`.
bool resolveQuiet({
  required bool configQuiet,
  required String? envQuiet,
  required bool? commandQuiet,
}) {
  return commandQuiet ??
      switch (envQuiet?.toLowerCase()) {
        'true' || '1' => true,
        'false' || '0' => false,
        _ => configQuiet,
      };
}

abstract class MelosCommand extends Command<void> {
  MelosCommand(this.config);

  final MelosWorkspaceConfig config;

  /// The global Melos options parsed from the command line.
  late final global = _parseGlobalOptions();

  late final logger = MelosLogger(
    global.verbose ? Logger.verbose() : Logger.standard(),
    isQuiet: global.quiet,
  );

  /// The `pubspec.yaml` configuration for this command. see
  /// [ArgParser.allowTrailingOptions]
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
      quiet: resolveQuiet(
        configQuiet: config.quiet,
        envQuiet:
            currentPlatform.environment[EnvironmentVariableKey.melosQuiet],
        commandQuiet: globalResults!.wasParsed(globalOptionQuiet)
            ? globalResults![globalOptionQuiet] as bool
            : null,
      ),
      sdkPath: globalResults![globalOptionSdkPath] as String?,
    );
  }

  /// Adds the package filtering options to [argParser].
  ///
  /// Commands that determine the compared revision range themselves can set
  /// [diff] to `false` to leave out the `--diff` option.
  void setupPackageFilterParser({bool diff = true}) {
    _addPackageFilterOptions(argParser, diff: diff);

    argParser.addFlag(
      filterOptionIncludeDependents,
      negatable: false,
      help:
          'Include all transitive dependents for each package that matches '
          'the other filters. The included packages skip --ignore and '
          '--diff checks, use --post-filter to filter them.',
    );

    argParser.addFlag(
      filterOptionIncludeDependencies,
      negatable: false,
      help:
          'Include all transitive dependencies for each package that '
          'matches the other filters. The included packages skip --ignore '
          'and --diff checks, use --post-filter to filter them.',
    );

    argParser.addMultiOption(
      filterOptionPostFilter,
      valueHelp: 'filter',
      splitCommas: false,
      help:
          'A filter that is applied to all packages after the dependents and '
          'dependencies have been included, written as any of the other '
          'filters without the leading dashes, for example '
          '"--post-filter=depends-on=build_runner" or '
          '"--post-filter=no-private". This option can be repeated.',
    );
  }

  /// Adds the options for the filters that narrow down the list of packages
  /// to [parser].
  static void _addPackageFilterOptions(ArgParser parser, {required bool diff}) {
    parser.addFlag(
      filterOptionPrivate,
      help:
          'Whether to include or exclude packages with `publish_to: "none"`. '
          'By default, the filter has no effect.',
      defaultsTo: null,
    );

    parser.addFlag(
      filterOptionPublished,
      defaultsTo: null,
      help:
          'Filter packages where the current local package version exists on '
          'pub.dev. Or "-no-published" to filter packages that have not had '
          'their current version published yet.',
    );

    parser.addFlag(
      filterOptionNullsafety,
      defaultsTo: null,
      help:
          'Filter packages where the current local version uses a "nullsafety" '
          'prerelease preid. Or "-no-nullsafety" to filter packages where '
          'their current version does not have a "nullsafety" preid.',
    );

    parser.addFlag(
      filterOptionFlutter,
      defaultsTo: null,
      help:
          'Filter packages that need the Flutter SDK, either directly or '
          'through another package in the workspace that they depend on. Or '
          '"--no-flutter" to filter packages that do not need the Flutter '
          'SDK.',
    );

    parser.addMultiOption(
      filterOptionScope,
      valueHelp: 'glob',
      help:
          'Include only packages with names matching the given glob. This '
          'option can be repeated.',
    );

    parser.addMultiOption(
      filterOptionCategory,
      valueHelp: 'glob',
      help:
          'Include only packages with categories matching the given glob. This '
          'option can be repeated.',
    );

    parser.addMultiOption(
      filterOptionIgnore,
      valueHelp: 'glob',
      help:
          'Exclude packages with names matching the given glob. This option '
          'can be repeated.',
    );

    if (diff) {
      parser.addOption(
        filterOptionDiff,
        valueHelp: 'ref',
        help:
            'Filter packages based on whether there were changes between a '
            'commit and the current HEAD or within a range of commits. A '
            'range of commits can be specified using the git shorthand '
            'syntax `<start-commit>..<end-commit>` and '
            '`<start-commit>...<end-commit>`',
      );
    }

    parser.addMultiOption(
      filterOptionDirExists,
      valueHelp: 'dirRelativeToPackageRoot',
      help:
          'Include only packages where a specific directory exists inside '
          'the package.',
    );

    parser.addMultiOption(
      filterOptionFileExists,
      valueHelp: 'fileRelativeToPackageRoot',
      help:
          'Include only packages where a specific file exists in the package.',
    );

    parser.addMultiOption(
      filterOptionDependsOn,
      valueHelp: 'dependentPackageName',
      help:
          'Include only packages that depend on a specific package. This '
          'option can be repeated, to further filter the list of packages.',
    );

    parser.addMultiOption(
      filterOptionNoDependsOn,
      valueHelp: 'noDependantPackageName',
      help:
          "Include only packages that *don't* depend on a specific package. "
          'This option can be repeated.',
    );
  }

  /// The `--concurrency` option, or `null` when it was not passed on the
  /// command line and the configured default should be used instead.
  int? get concurrencyOption {
    final value = argResults!.optional('concurrency') as String?;
    return value == null ? null : int.parse(value);
  }

  /// Whether any package filter arguments were explicitly provided by the
  /// user on the command line.
  bool get hasPackageFilterArgs {
    final results = argResults;
    if (results == null) return false;

    const allFilterOptions = [
      filterOptionScope,
      filterOptionCategory,
      filterOptionIgnore,
      filterOptionDirExists,
      filterOptionFileExists,
      filterOptionDiff,
      filterOptionDependsOn,
      filterOptionNoDependsOn,
      filterOptionPrivate,
      filterOptionPublished,
      filterOptionNullsafety,
      filterOptionFlutter,
      filterOptionIncludeDependents,
      filterOptionIncludeDependencies,
      filterOptionPostFilter,
    ];

    return allFilterOptions
        .where(argParser.options.containsKey)
        .any(results.wasParsed);
  }

  PackageFilters parsePackageFilters(
    String workingDirPath, {
    bool diffEnabled = true,
    bool includeConfigIgnore = true,
  }) {
    final results = argResults!;

    return _packageFiltersFromResults(
      results,
      workingDirPath,
      diffEnabled: diffEnabled,
      configIgnore: includeConfigIgnore ? config.ignore : const [],
    ).copyWith(
      includeDependents: results[filterOptionIncludeDependents] as bool,
      includeDependencies: results[filterOptionIncludeDependencies] as bool,
      postFilters: _parsePostFilters(
        workingDirPath,
        diffEnabled: diffEnabled,
      ),
    );
  }

  /// Parses the values of the `--post-filter` option by reading each of them
  /// as one of the filter options.
  PackageFilters? _parsePostFilters(
    String workingDirPath, {
    required bool diffEnabled,
  }) {
    final postFilters =
        argResults![filterOptionPostFilter] as List<String>? ?? [];
    if (postFilters.isEmpty) {
      return null;
    }

    final hasDiffOption = argParser.options.containsKey(filterOptionDiff);
    final postFilterParser = ArgParser();
    _addPackageFilterOptions(postFilterParser, diff: hasDiffOption);

    final ArgResults results;
    try {
      results = postFilterParser.parse(
        postFilters.map((filter) => '--$filter'),
      );
    } on FormatException catch (exception) {
      usageException(
        'Invalid value for --$filterOptionPostFilter: ${exception.message}',
      );
    }
    if (results.rest.isNotEmpty) {
      usageException(
        'Invalid value for --$filterOptionPostFilter: '
        '"${results.rest.join(' ')}"',
      );
    }

    return _packageFiltersFromResults(
      results,
      workingDirPath,
      diffEnabled: diffEnabled && hasDiffOption,
    );
  }

  static PackageFilters _packageFiltersFromResults(
    ArgResults results,
    String workingDirPath, {
    required bool diffEnabled,
    List<Glob> configIgnore = const [],
  }) {
    final diff = diffEnabled ? results[filterOptionDiff] as String? : null;
    final scope = results[filterOptionScope] as List<String>? ?? [];
    final categories = results[filterOptionCategory] as List<String>? ?? [];
    final ignore = results[filterOptionIgnore] as List<String>? ?? [];

    return PackageFilters(
      scope: scope
          .map((e) => createGlob(e, currentDirectoryPath: workingDirPath))
          .toList(),
      ignore: [
        ...ignore.map(
          (e) => createGlob(e, currentDirectoryPath: workingDirPath),
        ),
        ...configIgnore,
      ],
      categories: categories
          .map((e) => createGlob(e, currentDirectoryPath: workingDirPath))
          .toList(),
      diff: diff,
      includePrivatePackages: results[filterOptionPrivate] as bool?,
      published: results[filterOptionPublished] as bool?,
      nullSafe: results[filterOptionNullsafety] as bool?,
      dirExists: results[filterOptionDirExists] as List<String>? ?? [],
      fileExists: results[filterOptionFileExists] as List<String>? ?? [],
      flutter: results[filterOptionFlutter] as bool?,
      dependsOn: results[filterOptionDependsOn] as List<String>? ?? [],
      noDependsOn: results[filterOptionNoDependsOn] as List<String>? ?? [],
    );
  }
}
