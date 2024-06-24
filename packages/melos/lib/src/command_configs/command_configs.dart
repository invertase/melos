import 'package:meta/meta.dart';

import '../common/utils.dart';
import '../common/validation.dart';
import 'analyze.dart';
import 'bootstrap.dart';
import 'clean.dart';
import 'format.dart';
import 'publish.dart';
import 'version.dart';

export 'bootstrap.dart';
export 'clean.dart';
export 'version.dart';

/// Melos command-specific configurations.
@immutable
class CommandConfigs {
  const CommandConfigs({
    this.bootstrap = BootstrapCommandConfigs.empty,
    this.clean = CleanCommandConfigs.empty,
    this.version = VersionCommandConfigs.empty,
    this.publish = PublishCommandConfigs.empty,
    this.format = FormatCommandConfigs.empty,
    this.analyze = AnalyzeCommandConfigs.empty,
  });

  factory CommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
    bool repositoryIsConfigured = false,
  }) {
    final bootstrapMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'bootstrap',
      map: yaml,
      path: 'command',
    );

    final cleanMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'clean',
      map: yaml,
      path: 'command',
    );

    final versionMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'version',
      map: yaml,
      path: 'command',
    );

    final publishMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'publish',
      map: yaml,
      path: 'command',
    );

    final formatMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'format',
      map: yaml,
      path: 'command',
    );

    final analyzeMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'analyze',
      map: yaml,
      path: 'command',
    );

    return CommandConfigs(
      bootstrap: BootstrapCommandConfigs.fromYaml(
        bootstrapMap ?? const {},
        workspacePath: workspacePath,
      ),
      clean: CleanCommandConfigs.fromYaml(
        cleanMap ?? const {},
        workspacePath: workspacePath,
      ),
      version: VersionCommandConfigs.fromYaml(
        versionMap ?? const {},
        workspacePath: workspacePath,
        repositoryIsConfigured: repositoryIsConfigured,
      ),
      publish: PublishCommandConfigs.fromYaml(
        publishMap ?? const {},
        workspacePath: workspacePath,
        repositoryIsConfigured: repositoryIsConfigured,
      ),
      format: FormatCommandConfigs.fromYaml(
        formatMap ?? const {},
        workspacePath: workspacePath,
      ),
      analyze: AnalyzeCommandConfigs.fromYaml(
        analyzeMap ?? const {},
        workspacePath: workspacePath,
      ),
    );
  }

  static const CommandConfigs empty = CommandConfigs();

  final BootstrapCommandConfigs bootstrap;
  final CleanCommandConfigs clean;
  final VersionCommandConfigs version;
  final PublishCommandConfigs publish;
  final FormatCommandConfigs format;
  final AnalyzeCommandConfigs analyze;

  Map<String, Object?> toJson() {
    return {
      'bootstrap': bootstrap.toJson(),
      'clean': clean.toJson(),
      'version': version.toJson(),
      'publish': publish.toJson(),
      'format': format.toJson(),
      'analyze': analyze.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CommandConfigs &&
      runtimeType == other.runtimeType &&
      other.bootstrap == bootstrap &&
      other.clean == clean &&
      other.version == version &&
      other.publish == publish &&
      other.format == format &&
      other.analyze == analyze;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        bootstrap,
        clean,
        version,
        publish,
        format,
        analyze,
      );

  @override
  String toString() {
    return '''
CommandConfigs(
  bootstrap: ${bootstrap.toString().indent('  ')},
  clean: ${clean.toString().indent('  ')},
  version: ${version.toString().indent('  ')},
  publish: ${publish.toString().indent('  ')},
  format: ${format.toString().indent('  ')},
  analyze: ${analyze.toString().indent('  ')},
)
''';
  }
}
