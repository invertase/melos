// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

import 'package:pub_semver/pub_semver.dart';

/// Contents of a `.dart_tool/package_config.json` file.
class PackageConfig {
  /// Version of the configuration in the `.dart_tool/package_config.json` file.
  ///
  /// The only supported value as of writing is `2`.
  int configVersion;

  /// Packages configured.
  List<PackageConfigEntry> packages;

  /// Date-time the `.dart_tool/package_config.json` file was generated.
  ///
  /// This property is **optional** and may be `null` if not given.
  DateTime generated;

  /// Tool that generated the `.dart_tool/package_config.json` file.
  ///
  /// For `pub` this is always `'pub'`.
  ///
  /// This property is **optional** and may be `null` if not given.
  String generator;

  /// Version of the tool that generated the `.dart_tool/package_config.json`
  /// file.
  ///
  /// For `pub` this is the Dart SDK version from which `pub get` was called.
  ///
  /// This property is **optional** and may be `null` if not given.
  Version generatorVersion;

  /// Additional properties not in the specification for the
  /// `.dart_tool/package_config.json` file.
  Map<String, dynamic> additionalProperties;

  PackageConfig({
    @required this.configVersion,
    @required this.packages,
    this.generated,
    this.generator,
    this.generatorVersion,
    this.additionalProperties,
  }) {
    additionalProperties ??= {};
  }

  /// Create [PackageConfig] from JSON [data].
  ///
  /// Throws [FormatException], if format is invalid, this does not validate the
  /// contents only that the format is correct.
  factory PackageConfig.fromJson(Object data) {
    if (data is! Map<String, dynamic>) {
      throw FormatException('package_config.json must be a JSON object');
    }
    final root = data as Map<String, dynamic>;

    void _throw(String property, String mustBe) => throw FormatException(
        '"$property" in .dart_tool/package_config.json $mustBe');

    /// Read the 'configVersion' property
    final configVersion = root['configVersion'];
    if (configVersion is! int) {
      _throw('configVersion', 'must be an integer');
    }
    if (configVersion != 2) {
      _throw('configVersion', 'must be 2 (the only supported version)');
    }

    final packagesRaw = root['packages'];
    if (packagesRaw is! List) {
      _throw('packages', 'must be a list');
    }
    final packages = <PackageConfigEntry>[];
    for (final entry in packagesRaw) {
      packages.add(PackageConfigEntry.fromJson(entry));
    }

    // Read the 'generated' property
    DateTime generated;
    final generatedRaw = root['generated'] as String;
    if (generatedRaw != null) {
      if (generatedRaw is! String) {
        _throw('generated', 'must be a string, if given');
      }
      generated = DateTime.parse(generatedRaw);
    }

    // Read the 'generator' property
    final generator = root['generator'] as String;
    if (generator != null && generator is! String) {
      throw FormatException(
          '"generator" in package_config.json must be a string, if given');
    }

    // Read the 'generatorVersion' property
    Version generatorVersion;
    final generatorVersionRaw = root['generatorVersion'] as String;
    if (generatorVersionRaw != null) {
      if (generatorVersionRaw is! String) {
        _throw('generatorVersion', 'must be a string, if given');
      }
      try {
        generatorVersion = Version.parse(generatorVersionRaw);
      } on FormatException catch (e) {
        _throw('generatorVersion',
            'must be a semver version, if given, error: ${e.message}');
      }
    }

    return PackageConfig(
        configVersion: configVersion as int,
        packages: packages,
        generated: generated,
        generator: generator,
        generatorVersion: generatorVersion,
        additionalProperties: Map.fromEntries(root.entries.where((e) => !{
          'configVersion',
          'packages',
          'generated',
          'generator',
          'generatorVersion',
        }.contains(e.key))));
  }

  /// Convert to JSON structure.
  Map<String, Object> toJson() => {
    'configVersion': configVersion,
    'packages': packages.map((p) => p.toJson()).toList(),
    'generated': generated?.toUtc()?.toIso8601String(),
    'generator': generator,
    'generatorVersion': generatorVersion?.toString(),
  }..addAll(additionalProperties ?? {});
}

final _languageVersionPattern = RegExp(r'^\d+\.\d+$');

class PackageConfigEntry {
  /// Package name.
  String name;

  /// Root [Uri] of the package.
  ///
  /// This specifies the root folder of the package, all files below this folder
  /// is considered part of this package.
  Uri rootUri;

  /// Relative URI path of the library folder relative to [rootUri].
  ///
  /// Import statements in Dart programs are resolved relative to this folder.
  /// This must be in the sub-tree under [rootUri].
  ///
  /// This property is **optional** and may be `null` if not given.
  Uri packageUri;

  /// Language version used by package.
  ///
  /// Given as `<major>.<minor>` version, similar to the `// @dart = X.Y`
  /// comment. This is derived from the lower-bound on the Dart SDK requirement
  /// in the `pubspec.yaml` for the given package.
  ///
  /// This property is **optional** and may be `null` if not given.
  String languageVersion;

  /// Additional properties not in the specification for the
  /// `.dart_tool/package_config.json` file.
  Map<String, dynamic> additionalProperties;

  PackageConfigEntry({
    @required this.name,
    @required this.rootUri,
    this.packageUri,
    this.languageVersion,
    this.additionalProperties,
  }) {
    additionalProperties ??= {};
  }

  /// Create [PackageConfigEntry] from JSON [data].
  ///
  /// Throws [FormatException], if format is invalid, this does not validate the
  /// contents only that the format is correct.
  factory PackageConfigEntry.fromJson(Object data) {
    if (data is! Map<String, dynamic>) {
      throw FormatException(
          'packages[] entries in package_config.json must be JSON objects');
    }
    final root = data as Map<String, dynamic>;

    void _throw(String property, String mustBe) => throw FormatException(
        '"packages[].$property" in .dart_tool/package_config.json $mustBe');

    final name = root['name'] as String;
    if (name is! String) {
      _throw('name', 'must be a string');
    }

    Uri rootUri;
    final rootUriRaw = root['rootUri'] as String;
    if (rootUriRaw is! String) {
      _throw('rootUri', 'must be a string');
    }
    try {
      rootUri = Uri.parse(rootUriRaw);
    } on FormatException {
      _throw('rootUri', 'must be a URI');
    }

    Uri packageUri;
    final packageUriRaw = root['packageUri'] as String;
    if (packageUriRaw != null) {
      if (packageUriRaw is! String) {
        _throw('packageUri', 'must be a string');
      }
      try {
        packageUri = Uri.parse(packageUriRaw);
      } on FormatException {
        _throw('packageUri', 'must be a URI');
      }
    }

    final languageVersion = root['languageVersion'] as String;
    if (languageVersion != null) {
      if (languageVersion is! String) {
        _throw('languageVersion', 'must be a string');
      }
      if (!_languageVersionPattern.hasMatch(languageVersion)) {
        _throw('languageVersion', 'must be on the form <major>.<minor>');
      }
    }

    return PackageConfigEntry(
      name: name,
      rootUri: rootUri,
      packageUri: packageUri,
      languageVersion: languageVersion,
    );
  }

  /// Convert to JSON structure.
  Map<String, Object> toJson() => {
    'name': name,
    'rootUri': rootUri.toString(),
    if (packageUri != null) 'packageUri': packageUri?.toString(),
    if (languageVersion != null) 'languageVersion': languageVersion,
  }..addAll(additionalProperties ?? {});
}

/// Extract the _language version_ from an SDK constraint from `pubspec.yaml`.
///
/// This returns `null` if there is no language version.
String extractLanguageVersion(VersionConstraint c) {
  Version minVersion;
  if (c == null || c.isEmpty) {
    return null;
  } else if (c is Version) {
    minVersion = c;
  } else if (c is VersionRange) {
    minVersion = c.min;
  } else if (c is VersionUnion) {
    // `ranges` is non-empty and sorted.
    minVersion = c.ranges.first.min;
  } else {
    throw ArgumentError('Unknown VersionConstraint type $c.');
  }
  if (minVersion == null) {
    return null;
  }
  return '${minVersion.major}.${minVersion.minor}';
}