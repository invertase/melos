import 'package:pub_semver/pub_semver.dart';

typedef Environment = Map<String, VersionConstraint?>;

extension EnvironmentExtension on Environment {
  Map<String, dynamic> toJson() {
    return {
      for (final key in keys) key: this[key]?.toString(),
    };
  }
}

extension SdkConstraintExtension on Environment? {
  String get sdkConstraint => this?['sdk']?.toString() ?? '';
}
