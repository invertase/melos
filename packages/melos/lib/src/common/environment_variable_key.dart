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
  /// `melos.yaml`, but is overridden by the command line option `--sdk-path`.
  static const String melosSdkPath = 'MELOS_SDK_PATH';

  static const String melosTerminalWidth = 'MELOS_TERMINAL_WIDTH';

  static const String path = 'PATH';

  static List<String> allMelosKeys() => [
        melosRootPath,
        melosPackageName,
        melosPackageVersion,
        melosPackagePath,
        melosParentPackageName,
        melosParentPackageVersion,
        melosParentPackagePath,
        melosPublishDryRun,
        melosScript,
        melosTest,
        melosPackages,
        melosSdkPath,
        melosTerminalWidth,
      ];
}
