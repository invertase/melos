import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

extension DependencyExtension on Dependency {
  VersionConstraint? get versionConstraint {
    if (this is HostedDependency) {
      return (this as HostedDependency).version;
    }
    return null;
  }

  /// Converts this dependency to the value used for it in a `pubspec.yaml`
  /// file, inlining the version or url where pub allows it.
  ///
  /// This intentionally differs from `Dependency.toJson` in `pubspec_parse`,
  /// which always produces a map.
  Object toYaml() {
    final self = this;
    if (self is PathDependency) {
      return self.toYaml();
    } else if (self is HostedDependency) {
      return self.toYaml();
    } else if (self is GitDependency) {
      return self.toYaml();
    } else if (self is SdkDependency) {
      return self.toYaml();
    } else {
      throw UnimplementedError();
    }
  }
}

extension PathDependencyExtension on PathDependency {
  Map<String, dynamic> toYaml() {
    return {
      'path': path,
    };
  }
}

extension HostedDependencyExtension on HostedDependency {
  Object toYaml() {
    return _inlineVersion
        ? version.toString()
        : {
            'hosted': hosted!.url?.toString(),
            'version': version.toString(),
          };
  }

  /// Whether the json can be inlined with its parent.
  ///
  /// For example for [HostedDependency] the version shouldn't be on a separate
  /// line when only the version is defined.
  bool get _inlineVersion {
    return hosted == null;
  }
}

extension GitDependencyExtension on GitDependency {
  Map<String, dynamic> toYaml() {
    return {
      'git': _inlineUrl
          ? url.toString()
          : {
              'url': url.toString(),
              if (ref != null) 'ref': ref,
              if (path != null) 'path': path,
            },
    };
  }

  /// Whether the url can be inlined with its parent.
  /// This happens when the [ref] and [path] are null.
  bool get _inlineUrl {
    return ref == null && path == null;
  }
}

extension SdkDependencyExtension on SdkDependency {
  Map<String, dynamic> toYaml() {
    return {
      'sdk': sdk,
      'version': version.toString(),
    };
  }
}

extension DependencyMapExtension on Map<String, Dependency> {
  Map<String, Object?> toYaml() {
    return map((key, value) => MapEntry(key, value.toYaml()));
  }
}
