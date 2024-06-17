import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';

import 'common/environment_variable_key.dart';
import 'common/exception.dart';
import 'common/git.dart';
import 'common/glob.dart';
import 'common/io.dart';
import 'common/platform.dart';
import 'common/pub_hosted.dart' as pub;
import 'common/pub_hosted_package.dart';
import 'common/utils.dart';
import 'common/validation.dart';
import 'logging.dart';

/// Key for windows platform.
const String kWindows = 'windows';

/// Key for macos platform.
const String kMacos = 'macos';

/// Key for linux platform.
const String kLinux = 'linux';

/// Key for IPA (iOS) platform.
const String kIos = 'ios';

/// Key for APK (Android) platform.
const String kAndroid = 'android';

/// Key for Web platform.
const String kWeb = 'web';

/// Paths that are safe to delete when running `melos clean`.
final List<String> cleanablePubFilePaths = [
  '.packages',
  '.flutter-plugins',
  '.flutter-plugins-dependencies',
  '.dart_tool${currentPlatform.pathSeparator}package_config.json',
  '.dart_tool${currentPlatform.pathSeparator}package_config_subset',
  '.dart_tool${currentPlatform.pathSeparator}version',
];

final _isValidPubPackageNameRegExp =
    RegExp(r'^[a-z][a-z\d_-]*$', caseSensitive: false);

/// Returns whether the given [name] is a valid pub package name.
bool isValidPubPackageName(String name) =>
    _isValidPubPackageNameRegExp.hasMatch(name);

/// Enum representing what type of package this is.
enum PackageType {
  dartPackage,
  flutterPackage,
  flutterPlugin,
  flutterApp,
}

RegExp versionReplaceRegex = RegExp(
  r'''^(version\s?:\s*?['"]?)(?<version>[\w\-.+_]{5,})(.*$)''',
  multiLine: true,
);

const _versionRegExp = r'''\d+\.\d+\.\d+[\w\-.+_]*''';

const _versionConstraintRegExp =
    r"""(?<version>any|["'^<>=]*\d+\.\d+\.\d+['"<>=\w\-.+_]*)""";

RegExp dependencyVersionReplaceRegex(String dependencyName) {
  return RegExp(
    '''(?<dependency>^\\s+$dependencyName\\s?:\\s?)(?!\$)$_versionConstraintRegExp''',
    multiLine: true,
  );
}

RegExp hostedDependencyVersionReplaceRegex(String dependencyName) {
  return RegExp(
    '''(^[ \t]*?(?<dependency>$dependencyName)[ \\t]*?:[ \\t]*?[\\s\\S]*?[ \\t]*?version:[ \\t]*?)$_versionConstraintRegExp''',
    multiLine: true,
  );
}

RegExp dependencyTagReplaceRegex(String dependencyName) {
  return RegExp(
    '''(?<tag_ref>^\\s+ref\\s?:\\s?)(?<opening_quote>["']?)(?<tag>$dependencyName-v$_versionRegExp)(?<closing_quote>['"]?)''',
    multiLine: true,
  );
}

@immutable
class PackageFilters {
  PackageFilters({
    this.scope = const [],
    this.ignore = const [],
    this.categories = const [],
    this.dirExists = const [],
    this.fileExists = const [],
    List<String> dependsOn = const [],
    List<String> noDependsOn = const [],
    this.diff,
    this.includePrivatePackages,
    this.published,
    this.nullSafe,
    bool? flutter,
    this.includeDependencies = false,
    this.includeDependents = false,
  })  : dependsOn = [
          ...dependsOn,
          // ignore: use_if_null_to_convert_nulls_to_bools
          if (flutter == true) 'flutter',
        ],
        noDependsOn = [
          ...noDependsOn,
          if (flutter == false) 'flutter',
        ];

  factory PackageFilters.fromYaml(
    Map<Object?, Object?> yaml, {
    required String path,
    required String workspacePath,
  }) {
    final scope = assertListOrString(
      key: filterOptionScope.camelCased,
      map: yaml,
      path: path,
    );

    final category = assertListOrString(
      key: filterOptionCategory.camelCased,
      map: yaml,
      path: path,
    );

    final ignore = assertListOrString(
      key: filterOptionIgnore.camelCased,
      map: yaml,
      path: path,
    );

    final dirExists = assertListOrString(
      key: filterOptionDirExists.camelCased,
      map: yaml,
      path: path,
    );

    final fileExists = assertListOrString(
      key: filterOptionFileExists.camelCased,
      map: yaml,
      path: path,
    );

    final dependsOn = assertListOrString(
      key: filterOptionDependsOn.camelCased,
      map: yaml,
      path: path,
    );

    final noDependsOn = assertListOrString(
      key: filterOptionNoDependsOn.camelCased,
      map: yaml,
      path: path,
    );

    final diff = assertKeyIsA<String?>(
      key: filterOptionDiff.camelCased,
      map: yaml,
      path: path,
    );

    final includeDependents = assertKeyIsA<bool?>(
          key: filterOptionIncludeDependents.camelCased,
          map: yaml,
          path: path,
        ) ??
        false;

    final includeDependencies = assertKeyIsA<bool?>(
          key: filterOptionIncludeDependencies.camelCased,
          map: yaml,
          path: path,
        ) ??
        false;

    final noPrivateOptionKey = filterOptionNoPrivate.camelCased;
    final excludePrivatePackagesTmp = assertKeyIsA<bool?>(
      key: noPrivateOptionKey,
      map: yaml,
      path: path,
    );

    final privateOptionKey = filterOptionPrivate.camelCased;
    final includePrivatePackagesTmp = assertKeyIsA<bool?>(
      key: privateOptionKey,
      map: yaml,
      path: path,
    );

    if (includePrivatePackagesTmp != null &&
        excludePrivatePackagesTmp != null) {
      throw MelosConfigException(
        'Cannot specify both "$noPrivateOptionKey" and '
        '"$excludePrivatePackagesTmp" at the same time in "$path".',
      );
    }
    bool? includePrivatePackages;
    if (includePrivatePackagesTmp != null) {
      includePrivatePackages = includePrivatePackagesTmp;
    }
    if (excludePrivatePackagesTmp != null) {
      includePrivatePackages = !excludePrivatePackagesTmp;
    }

    final published = assertKeyIsA<bool?>(
      key: filterOptionPublished.camelCased,
      map: yaml,
      path: path,
    );

    final nullSafe = assertKeyIsA<bool?>(
      key: filterOptionNullsafety.camelCased,
      map: yaml,
      path: path,
    );

    final flutter = assertKeyIsA<bool?>(
      key: filterOptionFlutter.camelCased,
      map: yaml,
      path: path,
    );

    Glob createPackageGlob(String pattern) =>
        createGlob(pattern, currentDirectoryPath: workspacePath);

    return PackageFilters(
      scope: scope.map(createPackageGlob).toList(),
      ignore: ignore.map(createPackageGlob).toList(),
      dirExists: dirExists,
      fileExists: fileExists,
      dependsOn: dependsOn,
      noDependsOn: noDependsOn,
      diff: diff,
      includeDependents: includeDependents,
      includeDependencies: includeDependencies,
      includePrivatePackages: includePrivatePackages,
      published: published,
      nullSafe: nullSafe,
      flutter: flutter,
      categories: category.map(createPackageGlob).toList(),
    );
  }

  /// A default constructor with **all** properties as requires, to ensure that
  /// copyWith functions properly copy all properties.
  const PackageFilters._({
    required this.scope,
    required this.ignore,
    required this.categories,
    required this.dirExists,
    required this.fileExists,
    required this.dependsOn,
    required this.noDependsOn,
    required this.diff,
    required this.includePrivatePackages,
    required this.published,
    required this.nullSafe,
    required this.includeDependencies,
    required this.includeDependents,
  });

  /// Patterns for filtering packages by name.
  final List<Glob> scope;

  /// Patterns for excluding packages by name.
  final List<Glob> ignore;

  /// Patterns for filtering packages by category.
  final List<Glob> categories;

  /// Include a package only if a given directory exists.
  final List<String> dirExists;

  /// Include a package only if a given file exists.
  final List<String> fileExists;

  /// Include only packages that depend on a specific package.
  final List<String> dependsOn;

  /// Include only packages that do not depend on a specific package.
  final List<String> noDependsOn;

  /// Filter packages based on whether there were changes between a commit and
  /// the current HEAD or within a range of commits.
  ///
  /// A range of commits can be specified using the git short hand syntax
  /// `<start-commit>..<end-commit>` and `<start-commit>...<end-commit>`.
  final String? diff;

  /// Include/Exclude packages with `publish_to: none`.
  final bool? includePrivatePackages;

  /// Include/exclude packages that are up-to-date on pub.dev
  final bool? published;

  /// Include/exclude packages that are null-safe.
  final bool? nullSafe;

  /// Whether to include packages that depends on the filtered packages.
  ///
  /// This supersede other filters.
  final bool includeDependents;

  /// Whether to include the packages that the filtered packages depends on.
  ///
  /// This supersede other filters.
  final bool includeDependencies;

  Map<String, Object?> toJson() {
    return {
      if (scope.isNotEmpty)
        filterOptionScope.camelCased: scope.map((e) => e.toString()).toList(),
      if (categories.isNotEmpty)
        filterOptionCategory.camelCased:
            scope.map((e) => e.toString()).toList(),
      if (ignore.isNotEmpty)
        filterOptionIgnore.camelCased: ignore.map((e) => e.toString()).toList(),
      if (dirExists.isNotEmpty) filterOptionDirExists.camelCased: dirExists,
      if (fileExists.isNotEmpty) filterOptionFileExists.camelCased: fileExists,
      if (dependsOn.isNotEmpty) filterOptionDependsOn.camelCased: dependsOn,
      if (noDependsOn.isNotEmpty)
        filterOptionNoDependsOn.camelCased: noDependsOn,
      if (diff != null) filterOptionDiff.camelCased: diff,
      if (includePrivatePackages != null)
        filterOptionPrivate.camelCased: includePrivatePackages,
      if (published != null) filterOptionPublished.camelCased: published,
      if (nullSafe != null) filterOptionNullsafety.camelCased: nullSafe,
      if (includeDependents) filterOptionIncludeDependents.camelCased: true,
      if (includeDependencies) filterOptionIncludeDependencies.camelCased: true,
    };
  }

  PackageFilters copyWithDiff(String? diff) {
    return PackageFilters._(
      dependsOn: dependsOn,
      dirExists: dirExists,
      fileExists: fileExists,
      ignore: ignore,
      includePrivatePackages: includePrivatePackages,
      noDependsOn: noDependsOn,
      nullSafe: nullSafe,
      published: published,
      scope: scope,
      diff: diff,
      includeDependencies: includeDependencies,
      includeDependents: includeDependents,
      categories: categories,
    );
  }

  PackageFilters copyWithUpdatedIgnore(List<Glob> ignore) {
    return PackageFilters._(
      dependsOn: dependsOn,
      dirExists: dirExists,
      fileExists: fileExists,
      ignore: ignore,
      includePrivatePackages: includePrivatePackages,
      noDependsOn: noDependsOn,
      nullSafe: nullSafe,
      published: published,
      scope: scope,
      diff: diff,
      includeDependencies: includeDependencies,
      includeDependents: includeDependents,
      categories: categories,
    );
  }

  PackageFilters copyWith({
    List<String>? dependsOn,
    List<String>? dirExists,
    List<String>? fileExists,
    List<Glob>? ignore,
    bool? includePrivatePackages,
    List<String>? noDependsOn,
    bool? nullSafe,
    bool? published,
    List<Glob>? scope,
    String? diff,
    bool? includeDependencies,
    bool? includeDependents,
    List<Glob>? categories,
  }) {
    return PackageFilters._(
      dependsOn: dependsOn ?? this.dependsOn,
      dirExists: dirExists ?? this.dirExists,
      fileExists: fileExists ?? this.fileExists,
      ignore: ignore ?? this.ignore,
      categories: categories ?? this.categories,
      includePrivatePackages:
          includePrivatePackages ?? this.includePrivatePackages,
      noDependsOn: noDependsOn ?? this.noDependsOn,
      nullSafe: nullSafe ?? this.nullSafe,
      published: published ?? this.published,
      scope: scope ?? this.scope,
      diff: diff ?? this.diff,
      includeDependencies: includeDependencies ?? this.includeDependencies,
      includeDependents: includeDependents ?? this.includeDependents,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PackageFilters &&
      runtimeType == other.runtimeType &&
      other.nullSafe == nullSafe &&
      other.published == published &&
      other.includeDependencies == includeDependencies &&
      other.includeDependents == includeDependents &&
      other.includePrivatePackages == includePrivatePackages &&
      const DeepCollectionEquality().equals(other.scope, scope) &&
      const DeepCollectionEquality().equals(other.ignore, ignore) &&
      const DeepCollectionEquality().equals(other.dirExists, dirExists) &&
      const DeepCollectionEquality().equals(other.fileExists, fileExists) &&
      const DeepCollectionEquality().equals(other.dependsOn, dependsOn) &&
      const DeepCollectionEquality().equals(other.noDependsOn, noDependsOn) &&
      const DeepCollectionEquality().equals(other.categories, categories) &&
      other.diff == diff;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      nullSafe.hashCode ^
      published.hashCode ^
      includeDependencies.hashCode ^
      includeDependents.hashCode ^
      includePrivatePackages.hashCode ^
      const DeepCollectionEquality().hash(scope) ^
      const DeepCollectionEquality().hash(ignore) ^
      const DeepCollectionEquality().hash(dirExists) ^
      const DeepCollectionEquality().hash(fileExists) ^
      const DeepCollectionEquality().hash(dependsOn) ^
      const DeepCollectionEquality().hash(noDependsOn) ^
      const DeepCollectionEquality().hash(categories) ^
      diff.hashCode;

  @override
  String toString() {
    return '''
PackageFilters(
  nullSafe: $nullSafe,
  published: $published,
  includeDependencies: $includeDependencies,
  includeDependents: $includeDependents,
  includePrivatePackages: $includePrivatePackages,
  scope: $scope,
  categories: $categories,
  ignore: $ignore,
  dirExists: $dirExists,
  fileExists: $fileExists,
  dependsOn: $dependsOn,
  noDependsOn: $noDependsOn,
  diff: $diff,
)''';
  }
}

class InvalidPackageFiltersException extends MelosException {
  InvalidPackageFiltersException(this.message);

  final String message;

  @override
  String toString() => 'Invalid package filters: $message';
}

// Not using MapView to prevent map mutation
class PackageMap {
  PackageMap(Map<String, Package> packages, this._logger)
      : _map = _packagesSortedByName(packages);

  static const _commonIgnorePatterns = [
    '**/.dart_tool/**',
    // Flutter symlinked plugins for iOS/macOS should not be included in the
    // package list.
    '**/.symlinks/plugins/**',
    // Flutter version manager should not be included in the package list.
    '**/.fvm/**',
    // Ephemeral plugin symlinked packages should not be included in the
    // package list.
    '**/.plugin_symlinks/**',
  ];

  static Map<String, Package> _packagesSortedByName(
    Map<String, Package> packages,
  ) {
    final sortedNames = packages.keys.sorted((a, b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    // Map literals creates an HashMap which preserves key order.
    // So map.keys/map.values will be sorted by name.
    return {
      for (final name in sortedNames) name: packages[name]!,
    };
  }

  static Future<PackageMap> resolvePackages({
    required String workspacePath,
    required List<Glob> packages,
    required List<Glob> ignore,
    required Map<String, List<Glob>> categories,
    required MelosLogger logger,
  }) async {
    final pubspecFiles = await _resolvePubspecFiles(
      workspacePath: workspacePath,
      packages: packages,
      ignore: [
        ...ignore,
        for (final pattern in _commonIgnorePatterns)
          createGlob(pattern, currentDirectoryPath: workspacePath),
      ],
    );

    final packageMap = <String, Package>{};

    await Future.wait<void>(
      pubspecFiles.map((pubspecFile) async {
        final pubspecDirPath = pubspecFile.parent.path;
        final pubSpec = await PubSpec.load(pubspecFile.parent);

        final name = pubSpec.name!;

        if (packageMap.containsKey(name)) {
          throw MelosConfigException(
            '''
Multiple packages with the name `$name` found in the workspace, which is unsupported.
To fix this problem, consider renaming your packages to have a unique name.

The packages that caused the problem are:
- $name at ${printablePath(relativePath(pubspecDirPath, workspacePath))}
- $name at ${printablePath(relativePath(packageMap[name]!.path, workspacePath))}
''',
          );
        }

        final filteredCategories = <String>[];

        categories.forEach((key, value) {
          final isCategoryMatching = value.any(
            (category) => category.matches(
              relativePath(pubspecDirPath, workspacePath),
            ),
          );

          if (isCategoryMatching) {
            filteredCategories.add(key);
          }
        });

        packageMap[name] = Package(
          name: name,
          path: pubspecDirPath,
          pathRelativeToWorkspace: relativePath(pubspecDirPath, workspacePath),
          version: pubSpec.version ?? Version.none,
          publishTo: pubSpec.publishTo,
          packageMap: packageMap,
          dependencies: pubSpec.dependencies.keys.toList(),
          devDependencies: pubSpec.devDependencies.keys.toList(),
          dependencyOverrides: pubSpec.dependencyOverrides.keys.toList(),
          pubSpec: pubSpec,
          categories: filteredCategories,
        );
      }),
    );

    return PackageMap(packageMap, logger);
  }

  static Future<List<File>> _resolvePubspecFiles({
    required String workspacePath,
    required List<Glob> packages,
    required List<Glob> ignore,
  }) async {
    final pubspecEntities = await Stream.fromIterable(packages)
        .map(_createPubspecGlob)
        .asyncExpand((pubspecGlob) => pubspecGlob.list(root: workspacePath))
        .toList();

    final pubspecIgnoreGlobs = ignore.map(_createPubspecGlob).toList();
    bool isIgnored(File file) =>
        pubspecIgnoreGlobs.any((glob) => glob.matches(file.path));

    final paths = pubspecEntities
        .whereType<File>()
        .whereNot(isIgnored)
        .map((file) => p.canonicalize(file.absolute.path))
        .toSet();

    return paths.map(File.new).toList();
  }

  static Glob _createPubspecGlob(Glob event) {
    return createGlob(
      p.posix.normalize('${event.pattern}/pubspec.yaml'),
      caseSensitive: event.caseSensitive,
      context: event.context,
      recursive: event.recursive,
      currentDirectoryPath: event.context.current,
    );
  }

  final Map<String, Package> _map;
  final MelosLogger _logger;

  Iterable<String> get keys => _map.keys;

  Iterable<Package> get values => _map.values;

  int get length => _map.length;

  Package? operator [](String key) => _map[key];

  /// Detect packages in the workspace with the provided filters.
  ///
  /// This is the default packages behaviour when a workspace is loaded.
  Future<PackageMap> applyFilters(PackageFilters? filters) async {
    if (filters == null) return this;

    var packageList = await values
        .applyIgnore(filters.ignore)
        .applyDirExists(filters.dirExists)
        .applyFileExists(filters.fileExists)
        .filterPrivatePackages(include: filters.includePrivatePackages)
        .applyScope(filters.scope)
        .applyCategories(filters.categories)
        .applyDependsOn(filters.dependsOn)
        .applyNoDependsOn(filters.noDependsOn)
        .filterNullSafe(nullSafe: filters.nullSafe)
        .filterPublishedPackages(published: filters.published);

    final diff = filters.diff;
    if (diff != null) {
      packageList = await packageList.applyDiff(diff, _logger);
    }

    packageList = packageList.applyIncludeDependentsOrDependencies(
      includeDependents: filters.includeDependents,
      includeDependencies: filters.includeDependencies,
    );

    return PackageMap(
      {
        for (final package in packageList) package.name: package,
      },
      _logger,
    );
  }
}

extension IterablePackageExt on Iterable<Package> {
  Iterable<Package> applyIgnore(List<Glob> ignore) {
    if (ignore.isEmpty) return this;

    return where((package) {
      return ignore.every((glob) => !glob.matches(package.name));
    });
  }

  Iterable<Package> applyDirExists(List<String> directoryPaths) {
    if (directoryPaths.isEmpty) return this;

    // Directory exists packages filter, multiple filters behaviour is 'AND'.
    return where((package) {
      return directoryPaths.every((dirExistsPath) {
        // TODO(rrousselGit): should support environment variables
        return dirExists(p.join(package.path, dirExistsPath));
      });
    });
  }

  Iterable<Package> applyFileExists(List<String> filePaths) {
    if (filePaths.isEmpty) return this;

    return where((package) {
      final fileExistsMatched = filePaths.any((fileExistsPath) {
        // TODO(rrousselGit): refactor the logic for applying environment
        // variables
        // TODO(rrousselGit): should support environment variables other than
        // PACKAGE_NAME
        final expandedFileExistsPath = fileExistsPath.replaceAll(
          '\$${EnvironmentVariableKey.melosPackageName}',
          package.name,
        );

        return fileExists(p.join(package.path, expandedFileExistsPath));
      });
      return fileExistsMatched;
    });
  }

  /// Whether to include packages with `publish_to: none`.
  ///
  /// If `include` is true, only include private packages. If false, only
  /// include public packages. If null, does nothing.
  Iterable<Package> filterPrivatePackages({bool? include}) {
    if (include == null) return this;

    return where((package) => include == package.isPrivate);
  }

  /// Whether to include/exclude packages with no changes since the latest
  /// version available on the registry.
  ///
  /// If `include` is true, only include published packages. If false, only
  /// include unpublished packages. If null, does nothing.
  Future<Iterable<Package>> filterPublishedPackages({
    required bool? published,
  }) async {
    if (published == null) return this;

    final pool = Pool(10);
    final packagesFilteredWithPublishStatus = <Package>[];

    await pool.forEach<Package, void>(this, (package) async {
      final pubPackage = await package.getPublishedPackage();

      final isOnPubRegistry = pubPackage?.isVersionPublished(package.version);

      if (published == (isOnPubRegistry ?? false)) {
        packagesFilteredWithPublishStatus.add(package);
      }
    }).drain<void>();

    return packagesFilteredWithPublishStatus;
  }

  Future<Iterable<Package>> applyDiff(
    String? diff,
    MelosLogger logger,
  ) async {
    if (diff == null) return this;

    return Pool(10)
        .forEach(this, (package) async {
          final hasDiff =
              await gitHasDiffInPackage(package, diff: diff, logger: logger);
          return MapEntry(package, hasDiff);
        })
        .where((event) => event.value)
        .map((event) => event.key)
        .toList();
  }

  /// Whether to include/exclude packages that are null-safe.
  ///
  /// If `include` is true, only null-safe packages. If false, only include
  /// packages that are not null-safe. If null, does nothing.
  Iterable<Package> filterNullSafe({required bool? nullSafe}) {
    if (nullSafe == null) return this;

    return where((package) {
      final version = package.version;

      final isNullsafetyVersion =
          version.isPreRelease && version.preRelease.contains('nullsafety');

      return nullSafe == isNullsafetyVersion;
    });
  }

  Iterable<Package> applyScope(List<Glob> scope) {
    if (scope.isEmpty) return this;

    return where((package) {
      return scope.any(
        (scope) => scope.matches(package.name),
      );
    }).toList();
  }

  Iterable<Package> applyCategories(List<Glob> appliedCategories) {
    if (appliedCategories.isEmpty) return this;

    return where((package) {
      return package.categories.any(
        (category) => appliedCategories.any(
          (appliedCategory) => appliedCategory.matches(category),
        ),
      );
    }).toList();
  }

  Iterable<Package> applyDependsOn(List<String> dependsOn) {
    if (dependsOn.isEmpty) return this;

    return where((package) {
      return dependsOn.every((element) {
        return package.dependencies.contains(element) ||
            package.devDependencies.contains(element);
      });
    });
  }

  Iterable<Package> applyNoDependsOn(List<String> noDependsOn) {
    if (noDependsOn.isEmpty) return this;

    return where((package) {
      return noDependsOn.every((element) {
        return !package.dependencies.contains(element) &&
            !package.devDependencies.contains(element);
      });
    });
  }

  Iterable<Package> applyIncludeDependentsOrDependencies({
    required bool includeDependents,
    required bool includeDependencies,
  }) {
    // We apply both dependents and includeDependencies at the same time, as if
    // both flags are enabled, this could otherwise include the dependencies
    // of the dependents – which is undesired.
    if (!includeDependents && !includeDependencies) return this;

    return {
      for (final package in this) ...[
        package,
        if (includeDependents)
          ...package.allTransitiveDependentsInWorkspace.values,
        if (includeDependencies)
          ...package.allTransitiveDependenciesInWorkspace.values,
      ],
    };
  }
}

class Package {
  Package({
    required this.devDependencies,
    required this.dependencies,
    required this.dependencyOverrides,
    required Map<String, Package> packageMap,
    required this.name,
    required this.path,
    required this.pathRelativeToWorkspace,
    required this.version,
    required this.publishTo,
    required this.pubSpec,
    required this.categories,
  })  : _packageMap = packageMap,
        assert(p.isAbsolute(path));

  final Map<String, Package> _packageMap;

  final List<String> devDependencies;
  final List<String> dependencies;
  final List<String> dependencyOverrides;

  final Uri? publishTo;
  final String name;
  final Version version;
  final String path;
  final PubSpec pubSpec;
  final List<String> categories;

  /// Package path as a normalized sting relative to the root of the workspace.
  /// e.g. "packages/firebase_database".
  final String pathRelativeToWorkspace;

  late final allDependenciesInWorkspace = {
    ...dependenciesInWorkspace,
    ...devDependenciesInWorkspace,
    ...dependencyOverridesInWorkspace,
  };

  late final allDependentsInWorkspace = {
    ...dependentsInWorkspace,
    ...devDependentsInWorkspace,
    ...dependentsOverridesInWorkspace,
  };

  /// The dependencies listed in `dependencies:` inside the package's
  /// `pubspec.yaml` that are part of the melos workspace.
  late final Map<String, Package> dependenciesInWorkspace =
      _packagesInWorkspaceForNames(dependencies);

  /// The dependencies listed in `dev_dependencies:` inside the package's
  /// `pubspec.yaml` that are part of the melos workspace.
  late final Map<String, Package> devDependenciesInWorkspace =
      _packagesInWorkspaceForNames(devDependencies);

  /// The dependencies listed in `dependency_overrides:` inside the package's
  /// `pubspec.yaml` that are part of the melos workspace.
  late final Map<String, Package> dependencyOverridesInWorkspace =
      _packagesInWorkspaceForNames(dependencyOverrides);

  /// The packages that depend on this package as a dependency.
  late final Map<String, Package> dependentsInWorkspace = {
    for (final entry in _packageMap.entries)
      if (entry.value.dependenciesInWorkspace.containsKey(name))
        entry.key: entry.value,
  };

  /// The packages that depend on this package as a dev dependency.
  late final Map<String, Package> devDependentsInWorkspace = {
    for (final entry in _packageMap.entries)
      if (entry.value.devDependenciesInWorkspace.containsKey(name))
        entry.key: entry.value,
  };

  /// The packages that depend on this package as a dependency override.
  late final Map<String, Package> dependentsOverridesInWorkspace = {
    for (final entry in _packageMap.entries)
      if (entry.value.dependencyOverridesInWorkspace.containsKey(name))
        entry.key: entry.value,
  };

  late final Map<String, Package> allTransitiveDependenciesInWorkspace =
      _transitivelyRelatedPackages(
    root: this,
    directlyRelatedPackages: (package, isRoot) => isRoot
        ? package.allDependenciesInWorkspace
        : package.dependenciesInWorkspace,
  );

  late final Map<String, Package> allTransitiveDependentsInWorkspace =
      _transitivelyRelatedPackages(
    root: this,
    directlyRelatedPackages: (package, _) => package.allDependentsInWorkspace,
  );

  Map<String, Package> _packagesInWorkspaceForNames(List<String> names) {
    return {
      for (final name in names)
        if (_packageMap.containsKey(name)) name: _packageMap[name]!,
    };
  }

  /// Type of this package, e.g. [PackageType.flutterApp].
  PackageType get type {
    if (isFlutterApp) return PackageType.flutterApp;
    if (isFlutterPlugin) return PackageType.flutterPlugin;
    if (isFlutterPackage) return PackageType.flutterPackage;
    return PackageType.dartPackage;
  }

  /// Returns whether this package is for Flutter.
  ///
  /// This is determined by whether the package depends on the Flutter SDK.
  late final bool isFlutterPackage = dependencies.contains('flutter');

  /// Returns whether this package is private (publish_to set to 'none').
  bool get isPrivate {
    // Unversioned package, assuming private, e.g. example apps.
    if (pubSpec.version == null) return true;

    return publishTo.toString() == 'none';
  }

  /// Queries the pub.dev registry for published versions of this package.
  /// Primarily used for publish filters and versioning.
  Future<PubHostedPackage?> getPublishedPackage() async {
    if (isPrivate) {
      return null;
    }

    final pubClient = pub.PubHostedClient.fromUri(pubHosted: publishTo);
    return pubClient.fetchPackage(name);
  }

  /// The example [Package] contained within this package, if any.
  ///
  /// A package is considered to be an example if it is located in the `example`
  /// directory of the [enclosingPackage].
  late final Package? examplePackage = () {
    final examplePath = p.join(path, 'example');
    return _packageMap.values
        .firstWhereOrNull((package) => p.equals(package.path, examplePath));
  }();

  /// The [Package] that encloses this package, if any.
  ///
  /// A package is considered to be the enclosing package if this package is
  /// located in a direct child directory of the enclosing package.
  late final Package? enclosingPackage = () {
    final enclosingPackagePath = p.dirname(path);
    return _packageMap.values.firstWhereOrNull(
      (package) => p.equals(package.path, enclosingPackagePath),
    );
  }();

  /// Whether this package is an example package as defined by [examplePackage].
  bool get isExample => enclosingPackage?.examplePackage == this;

  /// Returns whether this package is a Flutter app.
  ///
  /// This is determined by ensuring all the following conditions are met:
  ///
  /// - a) the package depends on the Flutter SDK.
  /// - b) the package does not define itself as a Flutter plugin inside
  ///   pubspec.yaml.
  /// - c) a lib/main.dart file exists in the package.
  bool get isFlutterApp {
    // Must directly depend on the Flutter SDK.
    if (!isFlutterPackage) return false;

    // Must not have a Flutter plugin definition in its pubspec.yaml.
    if (pubSpec.flutter?.plugin != null) return false;

    return fileExists(p.join(path, 'lib', 'main.dart'));
  }

  /// Returns whether this package supports Flutter for Android.
  bool get flutterAppSupportsAndroid {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kAndroid);
  }

  /// Returns whether this package supports Flutter for Web.
  bool get flutterAppSupportsWeb {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kWeb);
  }

  /// Returns whether this package supports Flutter for Windows.
  bool get flutterAppSupportsWindows {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kWindows);
  }

  /// Returns whether this package supports Flutter for MacOS.
  bool get flutterAppSupportsMacos {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kMacos);
  }

  /// Returns whether this package supports Flutter for iOS.
  bool get flutterAppSupportsIos {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kIos);
  }

  /// Returns whether this package supports Flutter for Linux.
  bool get flutterAppSupportsLinux {
    if (!isFlutterApp) return false;
    return _flutterAppSupportsPlatform(kLinux);
  }

  /// Returns whether this package is a Flutter plugin.
  ///
  /// This is determined by whether the pubspec contains a flutter.plugin
  /// definition.
  bool get isFlutterPlugin => pubSpec.flutter?.plugin != null;

  /// Returns whether this package supports Flutter for Android.
  bool get flutterPluginSupportsAndroid {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kAndroid);
  }

  /// Returns whether this package supports Flutter for Web.
  bool get flutterPluginSupportsWeb {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kWeb);
  }

  /// Returns whether this package supports Flutter for Windows.
  bool get flutterPluginSupportsWindows {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kWindows);
  }

  /// Returns whether this package supports Flutter for MacOS.
  bool get flutterPluginSupportsMacos {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kMacos);
  }

  /// Returns whether this package supports Flutter for iOS.
  bool get flutterPluginSupportsIos {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kIos);
  }

  /// Returns whether this package supports Flutter for Linux.
  bool get flutterPluginSupportsLinux {
    if (!isFlutterPlugin) return false;
    return _flutterPluginSupportsPlatform(kLinux);
  }

  /// Returns whether this package contains a test directory.
  bool get hasTests => dirExists(p.join(path, 'test'));

  bool _flutterAppSupportsPlatform(String platform) {
    assert(
      platform == kIos ||
          platform == kAndroid ||
          platform == kWeb ||
          platform == kMacos ||
          platform == kWindows ||
          platform == kLinux,
    );

    return dirExists('$path${currentPlatform.pathSeparator}$platform');
  }

  bool _flutterPluginSupportsPlatform(String platform) {
    assert(
      platform == kIos ||
          platform == kAndroid ||
          platform == kWeb ||
          platform == kMacos ||
          platform == kWindows ||
          platform == kLinux,
    );

    return pubSpec.flutter?.plugin?.platforms?[platform] != null;
  }

  @override
  String toString() {
    return 'Package($name)';
  }
}

/// Collects transitively related packages, starting at [root].
///
/// The relationship is defined by [directlyRelatedPackages]. Given a [Package]
/// that is being traversed, the function returns the packages that are directly
/// related to it.
Map<String, Package> _transitivelyRelatedPackages({
  required Package root,
  // ignore: avoid_positional_boolean_parameters
  required Map<String, Package> Function(Package, bool isRoot)
      directlyRelatedPackages,
}) {
  final result = <String, Package>{};
  final workingSet = directlyRelatedPackages(root, true).values.toList();

  while (workingSet.isNotEmpty) {
    final current = workingSet.removeLast();

    // Don't add the root to the result.
    if (current.name == root.name) {
      continue;
    }

    result.putIfAbsent(current.name, () {
      // Since `current` is a package that was not in the result, we are
      // seeing it for the first time and still need to traverse its related
      // packages.
      workingSet.insertAll(0, directlyRelatedPackages(current, false).values);

      return current;
    });
  }

  return result;
}

extension on PubSpec {
  Flutter? get flutter =>
      (unParsedYaml?['flutter'] as Map<Object?, Object?>?).let(Flutter.new);
}

class Flutter {
  Flutter(this._flutter);

  final Map<Object?, Object?> _flutter;

  Plugin? get plugin =>
      (_flutter['plugin'] as Map<Object?, Object?>?).let(Plugin.new);
}

class Plugin {
  Plugin(this._plugin);

  final Map<Object?, Object?> _plugin;

  Map<Object?, Object?>? get platforms =>
      _plugin['platforms'] as Map<Object?, Object?>?;
}
