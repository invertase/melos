import 'package:pubspec_parse/pubspec_parse.dart';

/// Encapsulates the dependency overrides from pubspec_overrides.yaml.
///
/// This is needed since the pubspec_parse library requires a name field to
/// parse the pubspec.
class PubspecOverrides {
  const PubspecOverrides(this.dependencyOverrides);

  factory PubspecOverrides.parse(String yaml) {
    final pubspec = Pubspec.parse('name: dummy\n$yaml');
    return PubspecOverrides(pubspec.dependencyOverrides);
  }

  final Map<String, Dependency> dependencyOverrides;
}
