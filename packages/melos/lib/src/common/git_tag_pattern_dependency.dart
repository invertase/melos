import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

// TODO: Remove this class once pubspec_parse supports tag_pattern dependencies.
/// Represents a Git dependency that uses tag patterns for versioning.
///
/// Instead of using pubspec_parse for parsing this dependency, we
/// manually parse the pubspec string to extract the necessary fields.
/// Though the tag_pattern feature is officially supported by dart since
/// SDK version 3.9.0, the pubspec_parse package does not yet support it.
/// See: [Dart SDK issue](https://github.com/dart-lang/tools/issues/2155)
class GitTagPatternDependency extends GitDependency {
  GitTagPatternDependency({
    required this.name,
    required this.tagPattern,
    required this.version,
    required Uri url,
    String? path,
  }) : super(url, path: path);
  final String name;
  final String tagPattern;
  final Version version;

  /// Searches for a git dependency with a tag_pattern in the pubspec string.
  ///
  /// Looks for the dependency by [name] in dependencies, dev_dependencies,
  /// and dependency_overrides sections.
  /// Returns a [GitTagPatternDependency] instance
  /// if found, otherwise returns null.
  static GitTagPatternDependency? fromRawCommit({
    required String pubspec,
    required String name,
  }) {
    final yaml = loadYaml(pubspec) as Map<Object?, Object?>?;
    if (yaml == null) {
      return null;
    }
    // Search in all dependency sections
    for (final section in [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ]) {
      final dependencies = yaml[section] as Map<Object?, Object?>?;
      if (dependencies == null) {
        continue;
      }

      final dependency = dependencies[name];
      if (dependency == null || dependency is! Map<Object?, Object?>) {
        continue;
      }

      // Check if this is a git dependency with tag_pattern
      final git = dependency['git'];
      if (git == null || git is! Map<Object?, Object?>) {
        continue;
      }

      final tagPattern = git['tag_pattern'];
      if (tagPattern == null || tagPattern is! String) {
        continue;
      }

      // Extract required fields
      final url = git['url'];
      if (url == null || url is! String) {
        continue;
      }

      final path = git['path'] as String?;

      final versionString = dependency['version'];
      if (versionString == null || versionString is! String) {
        continue;
      }

      final version = VersionConstraint.parse(versionString);
      if (version is! VersionRange || version.min == null) {
        continue;
      }

      return GitTagPatternDependency(
        name: name,
        url: Uri.parse(url),
        path: path,
        tagPattern: tagPattern,
        version: version.min!,
      );
    }

    return null;
  }
}
