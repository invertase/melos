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
}

class PubPackageVersion {
  PubPackageVersion({required this.version, this.published});

  factory PubPackageVersion.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as String?;
    final published = json['published'] as String?;

    if (version == null) {
      throw const FormatException('Version is not provided for the package');
    }

    return PubPackageVersion(
      version: Version.parse(version),
      published: published != null ? DateTime.tryParse(published) : null,
    );
  }

  final Version version;

  final DateTime? published;
}
