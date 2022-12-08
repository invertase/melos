/*
 * Copyright (c) 2020-present Invertase Limited & Contributors
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';

import 'common/exception.dart';
import 'common/git.dart';
import 'common/glob.dart';
import 'common/http.dart' as http;
import 'common/io.dart';
import 'common/platform.dart';
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

/// The URL where we can find a package server.
///
/// The default is `pub.dev`, but it can be overridden using the
/// `PUB_HOSTED_URL` environment variable.
/// https://dart.dev/tools/pub/environment-variables
Uri get pubUrl => Uri.parse(
      currentPlatform.environment['PUB_HOSTED_URL'] ?? 'https://pub.dev',
    );

/// Enum representing what type of package this is.
enum PackageType {
  dartPackage,
  flutterPackage,
  flutterPlugin,
  flutterApp,
}

// https://regex101.com/r/RAdBOn/3
RegExp versionReplaceRegex = RegExp(
  r'''^(version\s?:\s*?['"]?)(?<version>[-\d\.+\w_]{5,})(.*$)''',
  multiLine: true,
);

// https://regex101.com/r/sY3jXt/2/
RegExp dependencyVersionReplaceRegex(String dependencyName) {
  return RegExp(
    '''(?<dependency>^\\s+$dependencyName\\s?:\\s?)(?!\$)(?<version>any|["'^<>=]*\\d\\.\\d\\.\\d['"._\\s<>=\\d-\\w+]*)\$''',
    multiLine: true,
  );
}

// https://regex101.com/r/HIeQaI/1
RegExp hostedDependencyVersionReplaceRegex(String dependencyName) {
  return RegExp(
    '''(^[ \t]*?(?<dependency>$dependencyName)[ \\t]*?:[ \\t]*?[\\s\\S]*?[ \\t]*?version:[ \\t]*?)(?<version>any|\\^.*|["'^<>=]*\\d\\.\\d\\.\\d['"._ \\t<>=\\d-\\w+]*|\$)\$''',
    multiLine: true,
  );
}

RegExp dependencyTagReplaceRegex(String dependencyName) {
  return RegExp(
    '''(?<tag_ref>^\\s+ref\\s?:\\s?)(?<opening_quote>["']?)(?<tag>$dependencyName-v[\\d]+\\.[\\d]+\\.[\\d]+)(?<closing_quote>['"]?)\$''',
    multiLine: true,
  );
}

@immutable
class PackageFilter {
  PackageFilter({
    this.scope = const [],
    this.ignore = const [],
    this.dirExists = const [],
    this.fileExists = const [],
    List<String> dependsOn = const [],
    List<String> noDependsOn = const [],
    this.updatedSince,
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
        ] {
    _validate();
  }

  factory PackageFilter.fromYaml(
    Map<Object?, Object?> yaml, {
    required String path,
    required String workspacePath,
  }) {
    final scope = assertListOrString(
      key: filterOptionScope,
      map: yaml,
      path: path,
    );
    final ignore = assertListOrString(
      key: filterOptionIgnore,
      map: yaml,
      path: path,
    );
    final dirExists = assertListOrString(
      key: filterOptionDirExists,
      map: yaml,
      path: path,
    );
    final fileExists = assertListOrString(
      key: filterOptionFileExists,
      map: yaml,
      path: path,
    );
    final dependsOn = assertListOrString(
      key: filterOptionDependsOn,
      map: yaml,
      path: path,
    );
    final noDependsOn = assertListOrString(
      key: filterOptionNoDependsOn,
      map: yaml,
      path: path,
    );

    final updatedSince = assertIsA<String?>(
      value: yaml[filterOptionSince],
      key: filterOptionSince,
      path: path,
    );

    final diff = assertIsA<String?>(
      value: yaml[filterOptionDiff],
      key: filterOptionDiff,
      path: path,
    );

    final excludePrivatePackagesTmp = assertIsA<bool?>(
      value: yaml[filterOptionNoPrivate],
      key: filterOptionNoPrivate,
      path: path,
    );
    final includePrivatePackagesTmp = assertIsA<bool?>(
      value: yaml[filterOptionPrivate],
      key: filterOptionNoPrivate,
      path: path,
    );
    if (includePrivatePackagesTmp != null &&
        excludePrivatePackagesTmp != null) {
      throw MelosConfigException(
        'Cannot specify both --private and --no-private at the same time',
      );
    }
    bool? includePrivatePackages;
    if (includePrivatePackagesTmp != null) {
      includePrivatePackages = includePrivatePackagesTmp;
    }
    if (excludePrivatePackagesTmp != null) {
      includePrivatePackages = !excludePrivatePackagesTmp;
    }

    final published = assertIsA<bool?>(
      value: yaml[filterOptionPublished],
      key: filterOptionPublished,
      path: path,
    );
    final nullSafe = assertIsA<bool?>(
      value: yaml[filterOptionNullsafety],
      key: filterOptionNullsafety,
      path: path,
    );
    final flutter = assertIsA<bool?>(
      value: yaml[filterOptionFlutter],
      key: filterOptionFlutter,
      path: path,
    );

    Glob createPackageGlob(String pattern) =>
        createGlob(pattern, currentDirectoryPath: workspacePath);

    return PackageFilter(
      scope: scope.map(createPackageGlob).toList(),
      ignore: ignore.map(createPackageGlob).toList(),
      dirExists: dirExists,
      fileExists: fileExists,
      dependsOn: dependsOn,
      noDependsOn: noDependsOn,
      updatedSince: updatedSince,
      diff: diff,
      includePrivatePackages: includePrivatePackages,
      published: published,
      nullSafe: nullSafe,
      flutter: flutter,
    );
  }

  /// A default constructor with **all** properties as requires, to ensure that
  /// copyWith functions properly copy all properties.
  PackageFilter._({
    required this.scope,
    required this.ignore,
    required this.dirExists,
    required this.fileExists,
    required this.dependsOn,
    required this.noDependsOn,
    required this.updatedSince,
    required this.diff,
    required this.includePrivatePackages,
    required this.published,
    required this.nullSafe,
    required this.includeDependencies,
    required this.includeDependents,
  }) {
    _validate();
  }

  /// Patterns for filtering packages by name.
  final List<Glob> scope;

  /// Patterns for excluding packages by name.
  final List<Glob> ignore;

  /// Include a package only if a given directory exists.
  final List<String> dirExists;

  /// Include a package only if a given file exists.
  final List<String> fileExists;

  /// Include only packages that depend on a specific package.
  final List<String> dependsOn;

  /// Include only packages that do not depend on a specific package.
  final List<String> noDependsOn;

  /// Filter package based on whether they received changed since a specific git
  /// commit/tag ID.
  final String? updatedSince;

  /// Filter package based on whether they are different between specific git
  /// commit/tag ID.
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

  void _validate() {
    if (updatedSince != null && diff != null) {
      throw InvalidPackageFilterException(
        'Cannot specify both updatedSince and diff.',
      );
    }
  }

  Map<String, Object?> toJson() {
    return {
      if (scope.isNotEmpty)
        filterOptionScope: scope.map((e) => e.toString()).toList(),
      if (ignore.isNotEmpty)
        filterOptionIgnore: ignore.map((e) => e.toString()).toList(),
      if (dirExists.isNotEmpty) filterOptionDirExists: dirExists,
      if (fileExists.isNotEmpty) filterOptionFileExists: fileExists,
      if (dependsOn.isNotEmpty) filterOptionDependsOn: dependsOn,
      if (noDependsOn.isNotEmpty) filterOptionNoDependsOn: noDependsOn,
      if (updatedSince != null) filterOptionSince: updatedSince,
      if (diff != null) filterOptionDiff: diff,
      if (includePrivatePackages != null)
        filterOptionPrivate: includePrivatePackages,
      if (published != null) filterOptionPublished: published,
      if (nullSafe != null) filterOptionNullsafety: nullSafe,
      if (includeDependents) filterOptionIncludeDependents: true,
      if (includeDependencies) filterOptionIncludeDependencies: true,
    };
  }

  PackageFilter copyWithUpdatedSince(String? since) {
    return PackageFilter._(
      dependsOn: dependsOn,
      dirExists: dirExists,
      fileExists: fileExists,
      ignore: ignore,
      includePrivatePackages: includePrivatePackages,
      noDependsOn: noDependsOn,
      nullSafe: nullSafe,
      published: published,
      scope: scope,
      updatedSince: since,
      diff: diff,
      includeDependencies: includeDependencies,
      includeDependents: includeDependents,
    );
  }

  PackageFilter copyWithUpdatedIgnore(List<Glob> updatedIgnore) {
    return PackageFilter._(
      dependsOn: dependsOn,
      dirExists: dirExists,
      fileExists: fileExists,
      ignore: updatedIgnore,
      includePrivatePackages: includePrivatePackages,
      noDependsOn: noDependsOn,
      nullSafe: nullSafe,
      published: published,
      scope: scope,
      updatedSince: updatedSince,
      diff: diff,
      includeDependencies: includeDependencies,
      includeDependents: includeDependents,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PackageFilter &&
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
      other.updatedSince == updatedSince &&
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
      updatedSince.hashCode ^
      diff.hashCode;

  @override
  String toString() {
    return '''
PackageFilter(
  nullSafe: $nullSafe,
  published: $published,
  includeDependencies: $includeDependencies,
  includeDependents: $includeDependents,
  includePrivatePackages: $includePrivatePackages,
  scope: $scope,
  ignore: $ignore,
  dirExists: $dirExists,
  fileExists: $fileExists,
  dependsOn: $dependsOn,
  noDependsOn: $noDependsOn,
  updatedSince: $updatedSince,
  diff: $diff,
)''';
  }
}

class InvalidPackageFilterException extends MelosException {
  InvalidPackageFilterException(this.message);

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
    required MelosLogger logger,
  }) async {
    final pubspecFiles = await _resolvePubspecFiles(
      workspacePath: workspacePath,
      packages: packages,
      ignore: [
        ...ignore,
        for (final pattern in _commonIgnorePatterns)
          createGlob(pattern, currentDirectoryPath: workspacePath)
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

  Package? operator [](String key) {
    return _map[key];
  }

  /// Detect packages in the workspace with the provided filters.
  ///
  /// This is the default packages behaviour when a workspace is loaded.
  Future<PackageMap> applyFilter(PackageFilter? filter) async {
    if (filter == null) return this;

    var packageList = await values
        .applyIgnore(filter.ignore)
        .applyDirExists(filter.dirExists)
        .applyFileExists(filter.fileExists)
        .filterPrivatePackages(include: filter.includePrivatePackages)
        .applyScope(filter.scope)
        .applyDependsOn(filter.dependsOn)
        .applyNoDependsOn(filter.noDependsOn)
        .filterNullSafe(nullSafe: filter.nullSafe)
        .filterPublishedPackages(published: filter.published);

    final updatedSince = filter.updatedSince;
    if (updatedSince != null) {
      packageList = await packageList.applySince(updatedSince, _logger);
    }

    final diff = filter.diff;
    if (diff != null) {
      packageList = await packageList.applyDiff(diff, _logger);
    }

    packageList = packageList.applyIncludeDependentsOrDependencies(
      includeDependents: filter.includeDependents,
      includeDependencies: filter.includeDependencies,
    );

    return PackageMap(
      {
        for (final package in packageList) package.name: package,
      },
      _logger,
    );
  }
}

extension on Iterable<Package> {
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
        final expandedFileExistsPath =
            fileExistsPath.replaceAll(r'$MELOS_PACKAGE_NAME', package.name);

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
      final packageVersion = package.version.toString();

      final publishedVersions = await package.getPublishedVersions();

      final isOnPubRegistry = publishedVersions.contains(packageVersion);

      if (published == isOnPubRegistry) {
        packagesFilteredWithPublishStatus.add(package);
      }
    }).drain<void>();

    return packagesFilteredWithPublishStatus;
  }

  Future<Iterable<Package>> applySince(
    String? since,
    MelosLogger logger,
  ) async {
    if (since == null) return this;

    final pool = Pool(10);
    final packagesFilteredWithGitCommitsSince = <Package>[];

    await pool.forEach<Package, void>(this, (package) {
      return gitCommitsForPackage(package, since: since, logger: logger)
          .then((commits) async {
        if (commits.isNotEmpty) {
          packagesFilteredWithGitCommitsSince.add(package);
        }
      });
    }).drain<void>();

    return packagesFilteredWithGitCommitsSince;
  }

  Future<Iterable<Package>> applyDiff(
    String? diff,
    MelosLogger logger,
  ) async {
    if (diff == null) return this;

    final pool = Pool(10);
    final packagesFilteredWithGitCommitsSince = <Package>[];

    await pool.forEach<Package, void>(this, (package) {
      return gitHasDiffInPackage(package, diff: diff, logger: logger)
          .then((commits) async {
        if (commits) {
          packagesFilteredWithGitCommitsSince.add(package);
        }
      });
    }).drain<void>();

    return packagesFilteredWithGitCommitsSince;
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
  Future<List<String>> getPublishedVersions() async {
    if (isPrivate) {
      return [];
    }

    final pubHosted = publishTo ?? pubUrl;

    final url = pubHosted.replace(path: '/packages/$name.json');
    final response = await http.get(url);

    if (response.statusCode == 404) {
      // The package was never published
      return [];
    } else if (response.statusCode != 200) {
      throw Exception(
        'Error reading pub.dev registry for package "$name" '
        '(HTTP Status ${response.statusCode}), response: ${response.body}',
      );
    }
    final versions = <String>[];
    final versionsRaw =
        (json.decode(response.body) as Map)['versions'] as List<Object?>;
    for (final versionElement in versionsRaw) {
      versions.add(versionElement! as String);
    }
    versions.sort((String a, String b) {
      return Version.prioritize(Version.parse(a), Version.parse(b));
    });

    return versions.reversed.toList();
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

    // Must not have a Flutter plugin definition in it's pubspec.yaml.
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
