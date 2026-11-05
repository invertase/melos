import 'package:pub_semver/pub_semver.dart';

class PubHostedPackage {
  PubHostedPackage({required this.name, required this.versions, this.latest});

  factory PubHostedPackage.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final latest = json['latest'] as Map<String, dynamic>?;
    final versions = json['versions'] as List<dynamic>? ?? const [];

    if (name == null) {
      throw const FormatException('Name is not provided for the package');
    }

    final packageVersions = versions
        .map((v) => PubPackageVersion.fromJson(v as Map<String, dynamic>))
        .toList();

    return PubHostedPackage(
      name: name,
      versions: packageVersions,
      latest: latest != null ? PubPackageVersion.fromJson(latest) : null,
    );
  }

  /// Returns the name of this package.
  final String name;

  /// Returns the latest version of this package if available.
  final PubPackageVersion? latest;

  /// Returns the versions of this package.
  final List<PubPackageVersion> versions;

  /// Returns the sorted versions of this package.
  List<PubPackageVersion> get prioritizedVersions {
    final versions = [...this.versions];
    return versions..sort((a, b) => Version.prioritize(a.version, b.version));
  }

  bool isVersionPublished(Version version) {
    if (latest != null && latest!.version == version) {
      return true;
    }

    return prioritizedVersions.map((v) => v.version).contains(version);
  }

  /// Returns the newest stable version that is both newer than
  /// [currentVersion] and compatible with [dartSdkVersion], or `null` if no
  /// such version exists.
  ///
  /// This is used to avoid suggesting an update to a version that requires a
  /// newer Dart SDK than the one currently in use. Pre-release versions are
  /// never suggested, and pre-release users are not prompted to move to a
  /// stable release.
  PubPackageVersion? newestCompatibleUpdate({
    required Version currentVersion,
    required Version dartSdkVersion,
  }) {
    if (currentVersion.isPreRelease) {
      return null;
    }

    PubPackageVersion? best;
    for (final candidate in versions) {
      if (candidate.version.isPreRelease ||
          candidate.version <= currentVersion) {
        continue;
      }
      final constraint = candidate.sdkConstraint;
      if (constraint != null && !constraint.allows(dartSdkVersion)) {
        continue;
      }
      if (best == null || candidate.version > best.version) {
        best = candidate;
      }
    }
    return best;
  }
}

class PubPackageVersion {
  PubPackageVersion({
    required this.version,
    this.published,
    this.sdkConstraint,
  });

  factory PubPackageVersion.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as String?;
    final published = json['published'] as String?;
    final pubspec = json['pubspec'] as Map<String, dynamic>?;
    final environment = pubspec?['environment'] as Map<String, dynamic>?;
    final sdk = environment?['sdk'] as String?;

    if (version == null) {
      throw const FormatException('Version is not provided for the package');
    }

    return PubPackageVersion(
      version: Version.parse(version),
      published: published != null ? DateTime.tryParse(published) : null,
      sdkConstraint: _tryParseConstraint(sdk),
    );
  }

  static VersionConstraint? _tryParseConstraint(String? constraint) {
    if (constraint == null) {
      return null;
    }
    try {
      return VersionConstraint.parse(constraint);
    } on FormatException {
      return null;
    }
  }

  final Version version;

  final DateTime? published;

  /// The Dart SDK constraint declared in this version's pubspec, if any.
  final VersionConstraint? sdkConstraint;
}
