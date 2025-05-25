import 'dart:io';

import 'package:melos/src/common/extensions/dependency.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'yaml_to_string.dart';

extension PubspecExtension on Pubspec {
  Pubspec copyWith({
    String? name,
    Version? version,
    String? description,
    String? homepage,
    String? publishTo,
    Uri? repository,
    Uri? issueTracker,
    List<Uri>? funding,
    List<String>? topics,
    List<String>? ignoredAdvisories,
    List<Screenshot>? screenshots,
    String? documentation,
    Map<String, VersionConstraint?>? environment,
    List<String>? workspace,
    String? resolution,
    Map<String, Dependency>? dependencies,
    Map<String, Dependency>? devDependencies,
    Map<String, Dependency>? dependencyOverrides,
    Map<String, dynamic>? flutter,
  }) {
    return Pubspec(
      name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      homepage: homepage ?? this.homepage,
      publishTo: publishTo ?? this.publishTo,
      repository: repository ?? this.repository,
      issueTracker: issueTracker ?? this.issueTracker,
      funding: funding ?? this.funding,
      topics: topics ?? this.topics,
      ignoredAdvisories: ignoredAdvisories ?? this.ignoredAdvisories,
      screenshots: screenshots ?? this.screenshots,
      documentation: documentation ?? this.documentation,
      environment: environment ?? this.environment,
      workspace: workspace ?? this.workspace,
      resolution: resolution ?? this.resolution,
      dependencies: dependencies ?? this.dependencies,
      devDependencies: devDependencies ?? this.devDependencies,
      dependencyOverrides: dependencyOverrides ?? this.dependencyOverrides,
      flutter: flutter ?? this.flutter,
    );
  }

  /// Saves the pubspec to the [projectDirectory].
  Future<void> save(Directory projectDirectory) async {
    final ioSink = File(
      p.join(projectDirectory.path, 'pubspec.yaml'),
    ).openWrite();
    try {
      const YamlToString().writeYamlString(toJson(), ioSink);
    } finally {
      await ioSink.close();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version?.toString(),
      'description': description,
      'homepage': homepage,
      'publish_to': publishTo,
      'repository': repository?.toString(),
      'issue_tracker': issueTracker?.toString(),
      'funding': funding?.map((uri) => uri.toString()).toList(),
      'topics': topics,
      'ignored_advisories': ignoredAdvisories,
      'screenshots': screenshots
          ?.map((screenshot) => screenshot.toJson())
          .toList(),
      'documentation': documentation,
      'environment': environment.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
      'workspace': workspace,
      'resolution': resolution,
      'dependencies': dependencies.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'dev_dependencies': devDependencies.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'dependency_overrides': dependencyOverrides.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'flutter': flutter,
    }..removeWhere((_, value) => value == null);
  }
}

extension on Screenshot {
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'description': description,
    };
  }
}
