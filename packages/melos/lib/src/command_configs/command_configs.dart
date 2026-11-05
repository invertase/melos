import 'package:meta/meta.dart';

import '../common/utils.dart';
import '../common/validation.dart';
import 'analyze.dart';
import 'bootstrap.dart';
import 'clean.dart';
import 'exec.dart';
import 'format.dart';
import 'list.dart';
import 'publish.dart';
import 'run.dart';
import 'test.dart';
import 'version.dart';

export 'analyze.dart';
export 'bootstrap.dart';
export 'clean.dart';
export 'exec.dart';
export 'format.dart';
export 'list.dart';
export 'publish.dart';
export 'run.dart';
export 'test.dart';
export 'version.dart';

/// Melos command-specific configurations.
@immutable
class CommandConfigs {
  const CommandConfigs({
    this.analyze = AnalyzeCommandConfigs.empty,
    this.bootstrap = BootstrapCommandConfigs.empty,
    this.clean = CleanCommandConfigs.empty,
    this.exec = ExecCommandConfigs.empty,
    this.list = ListCommandConfigs.empty,
    this.run = RunCommandConfigs.empty,
    this.test = TestCommandConfigs.empty,
    this.version = VersionCommandConfigs.empty,
    this.publish = PublishCommandConfigs.empty,
    this.format = FormatCommandConfigs.empty,
  });

  factory CommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
    bool repositoryIsConfigured = false,
  }) {
    final analyzeMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'analyze',
      map: yaml,
      path: 'command',
    );

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

    final execMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'exec',
      map: yaml,
      path: 'command',
    );

    final listMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'list',
      map: yaml,
      path: 'command',
    );

    final runMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'run',
      map: yaml,
      path: 'command',
    );

    final testMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'test',
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

    return CommandConfigs(
      analyze: AnalyzeCommandConfigs.fromYaml(analyzeMap ?? const {}),
      bootstrap: BootstrapCommandConfigs.fromYaml(
        bootstrapMap ?? const {},
        workspacePath: workspacePath,
      ),
      clean: CleanCommandConfigs.fromYaml(
        cleanMap ?? const {},
        workspacePath: workspacePath,
      ),
      exec: ExecCommandConfigs.fromYaml(execMap ?? const {}),
      list: ListCommandConfigs.fromYaml(listMap ?? const {}),
      run: RunCommandConfigs.fromYaml(runMap ?? const {}),
      test: TestCommandConfigs.fromYaml(testMap ?? const {}),
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
      format: FormatCommandConfigs.fromYaml(formatMap ?? const {}),
    );
  }

  static const CommandConfigs empty = CommandConfigs();

  final AnalyzeCommandConfigs analyze;
  final BootstrapCommandConfigs bootstrap;
  final CleanCommandConfigs clean;
  final ExecCommandConfigs exec;
  final ListCommandConfigs list;
  final RunCommandConfigs run;
  final TestCommandConfigs test;
  final VersionCommandConfigs version;
  final PublishCommandConfigs publish;
  final FormatCommandConfigs format;

  Map<String, Object?> toJson() {
    return {
      'analyze': analyze.toJson(),
      'bootstrap': bootstrap.toJson(),
      'clean': clean.toJson(),
      'exec': exec.toJson(),
      'list': list.toJson(),
      'run': run.toJson(),
      'test': test.toJson(),
      'version': version.toJson(),
      'publish': publish.toJson(),
      'format': format.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CommandConfigs &&
      runtimeType == other.runtimeType &&
      other.analyze == analyze &&
      other.bootstrap == bootstrap &&
      other.clean == clean &&
      other.exec == exec &&
      other.list == list &&
      other.run == run &&
      other.test == test &&
      other.version == version &&
      other.publish == publish &&
      other.format == format;

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    analyze,
    bootstrap,
    clean,
    exec,
    list,
    run,
    test,
    version,
    publish,
    format,
  ]);

  @override
  String toString() {
    return '''
CommandConfigs(
  analyze: ${analyze.toString().indent('  ')},
  bootstrap: ${bootstrap.toString().indent('  ')},
  clean: ${clean.toString().indent('  ')},
  exec: ${exec.toString().indent('  ')},
  list: ${list.toString().indent('  ')},
  run: ${run.toString().indent('  ')},
  test: ${test.toString().indent('  ')},
  version: ${version.toString().indent('  ')},
  publish: ${publish.toString().indent('  ')},
  format: ${format.toString().indent('  ')},
)
''';
  }
}
