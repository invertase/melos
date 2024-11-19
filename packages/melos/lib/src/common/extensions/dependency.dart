import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

extension DependencyExtension on Dependency {
  VersionConstraint? get versionConstraint {
    if (this is HostedDependency) {
      return (this as HostedDependency).version;
    }
    return null;
  }

  Object toJson() {
    final self = this;
    if (self is PathDependency) {
      return self.toJson();
    } else if (self is HostedDependency) {
      return self.toJson();
    } else if (self is GitDependency) {
      return self.toJson();
    } else if (self is SdkDependency) {
      return self.toJson();
    } else {
      throw UnimplementedError();
    }
  }
}

extension PathDependencyExtension on PathDependency {
  Map<String, dynamic> toJson() {
    return {
      'path': path,
    };
  }
}

extension HostedDependencyExtension on HostedDependency {
  Map<String, dynamic> toJson() {
    return {
      'version': version.toString(),
      if (hosted != null)
        'hosted': {
          'name': hosted!.declaredName,
          'url': hosted!.url?.toString(),
        },
    };
  }
}

extension GitDependencyExtension on GitDependency {
  Map<String, dynamic> toJson() {
    return {
      'url': url.toString(),
      if (ref != null) 'ref': ref,
      if (path != null) 'path': path,
    };
  }
}

extension SdkDependencyExtension on SdkDependency {
  Map<String, dynamic> toJson() {
    return {
      'sdk': sdk,
      'version': version.toString(),
    };
  }
}

extension DependencyMapExtension on Map<String, Dependency> {
  Map<String, Object?> toJson() {
    return map((key, value) => MapEntry(key, value.toJson()));
  }
}
