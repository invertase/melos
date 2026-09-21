class EnvironmentVariableKey {
  EnvironmentVariableKey._();

  static const String melosRootPath = 'MELOS_ROOT_PATH';
  static const String melosPackageName = 'MELOS_PACKAGE_NAME';
  static const String melosPackageVersion = 'MELOS_PACKAGE_VERSION';
  static const String melosPackagePath = 'MELOS_PACKAGE_PATH';
  static const String melosParentPackageName = 'MELOS_PARENT_PACKAGE_NAME';
  static const String melosParentPackageVersion =
      'MELOS_PARENT_PACKAGE_VERSION';
  static const String melosParentPackagePath = 'MELOS_PARENT_PACKAGE_PATH';
  static const String melosPublishDryRun = 'MELOS_PUBLISH_DRY_RUN';
  static const String melosScript = 'MELOS_SCRIPT';
  static const String melosTest = 'MELOS_TEST';

  /// This user-defined environment variable contains a comma delimited list of
  /// package names that Melos should focus on. This will act as the global
  /// `scope` package filter, and it will override the `scope` for all the
  /// filtering options defined in the `packageFilters` section.
  static const String melosPackages = 'MELOS_PACKAGES';

  /// This user-defined environment has a path to the Dart/Flutter SDK to use.
  /// This environment variable has precedence over the `sdkPath` option in
  /// `pubspec.yaml`, but is overridden by the command line option `--sdk-path`.
  static const String melosSdkPath = 'MELOS_SDK_PATH';

  /// When set to `true`, Melos only prints warnings, errors and the output of
  /// failed commands. Melos sets this environment variable for the scripts it
  /// runs, so that nested Melos commands are quiet too. The `--quiet` command
  /// line option and the `quiet` option in `pubspec.yaml` enable the same
  /// behavior.
  static const String melosQuiet = 'MELOS_QUIET';

  /// When set to `true`, Melos styles its output with ANSI escape codes even if
  /// it does not write to a terminal, and when set to `false` it never does.
  /// Melos sets this environment variable for the scripts it runs, because it
  /// captures their output, which would otherwise make nested Melos commands
  /// lose their colors.
  static const String melosAnsiStyles = 'MELOS_ANSI_STYLES';

  static const String melosTerminalWidth = 'MELOS_TERMINAL_WIDTH';

  /// When set to `true`, `melos exec` runs the command in every package, even
  /// in the packages in which the `sources` did not change since the command
  /// last succeeded. `melos run --force` sets this environment variable for the
  /// scripts it runs, so that it reaches the nested `melos exec` commands.
  static const String melosForce = 'MELOS_FORCE';

  /// When set to `true`, `melos exec` ignores the `sources` of the command, so
  /// that it runs in every package without calculating or storing checksums.
  /// This environment variable has precedence over the `ignoreSources` option
  /// of `melos exec` in `pubspec.yaml`, but is overridden by the command line
  /// option `--ignore-sources`. `melos run --ignore-sources` sets this
  /// environment variable for the scripts it runs.
  static const String melosIgnoreSources = 'MELOS_IGNORE_SOURCES';

  static const String path = 'PATH';

  /// Location of the pub package cache. When unset, pub defaults to
  /// `$HOME/.pub-cache` on POSIX and `%LOCALAPPDATA%\Pub\Cache` on Windows.
  static const String pubCache = 'PUB_CACHE';

  /// The variables that `melos exec` defines separately for every package it
  /// runs a command in.
  static List<String> packageKeys() => [
    melosPackageName,
    melosPackageVersion,
    melosPackagePath,
    melosParentPackageName,
    melosParentPackageVersion,
    melosParentPackagePath,
  ];

  static List<String> allMelosKeys() => [
    melosRootPath,
    ...packageKeys(),
    melosPublishDryRun,
    melosScript,
    melosTest,
    melosPackages,
    melosSdkPath,
    melosQuiet,
    melosAnsiStyles,
    melosTerminalWidth,
    melosForce,
    melosIgnoreSources,
  ];
}
