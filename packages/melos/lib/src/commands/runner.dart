import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:collection/collection.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:mustache_template/mustache.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../command_runner/version.dart';
import '../common/aggregate_changelog.dart';
import '../common/environment_variable_key.dart';
import '../common/exception.dart';
import '../common/git.dart';
import '../common/git_commit.dart';
import '../common/git_repository.dart';
import '../common/glob.dart';
import '../common/intellij_project.dart';
import '../common/io.dart';
import '../common/pending_package_update.dart';
import '../common/platform.dart';
import '../common/utils.dart' as utils;
import '../common/utils.dart';
import '../common/versioning.dart';
import '../common/versioning.dart' as versioning;
import '../global_options.dart';
import '../logging.dart';
import '../package.dart';
import '../scripts.dart';
import '../workspace.dart';
import '../workspace_configs.dart';

part 'bootstrap.dart';
part 'clean.dart';
part 'exec.dart';
part 'list.dart';
part 'publish.dart';
part 'run.dart';
part 'version.dart';

enum _CommandWithLifecycle {
  bootstrap,
  clean,
  version,
}

class Melos extends _Melos
    with
        _CleanMixin,
        _BootstrapMixin,
        _ListMixin,
        _RunMixin,
        _ExecMixin,
        _VersionMixin,
        _PublishMixin {
  Melos({
    required this.config,
    Logger? logger,
  }) : logger = (logger ?? Logger.standard()).toMelosLogger();

  @override
  final MelosLogger logger;
  @override
  final MelosWorkspaceConfig config;
}

abstract class _Melos {
  MelosLogger get logger;
  MelosWorkspaceConfig get config;

  Future<MelosWorkspace> createWorkspace({
    GlobalOptions? global,
    PackageFilters? packageFilters,
  }) async {
    var filterWithEnv = packageFilters;

    if (currentPlatform.environment
        .containsKey(EnvironmentVariableKey.melosPackages)) {
      // MELOS_PACKAGES environment variable is a comma delimited list of
      // package names - used to scope the `packageFilters` if it is present.
      // This can be user defined or can come from package selection in
      // `melos run`.
      final filteredPackagesScopeFromEnv =
          currentPlatform.environment[EnvironmentVariableKey.melosPackages]!
              .split(',')
              .map(
                (e) => createGlob(e, currentDirectoryPath: config.path),
              )
              .toList();

      filterWithEnv = packageFilters == null
          ? PackageFilters(scope: filteredPackagesScopeFromEnv)
          : packageFilters.copyWith(scope: filteredPackagesScopeFromEnv);
    }

    return (await MelosWorkspace.fromConfig(
      config,
      global: global,
      packageFilters: filterWithEnv,
      logger: logger,
    ))
      ..validate();
  }

  Future<void> _runLifecycle(
    MelosWorkspace workspace,
    _CommandWithLifecycle command,
    FutureOr<void> Function() cb,
  ) async {
    final hooks = workspace.config.commands.lifecycleHooksFor(command);
    final preScript = hooks.pre;
    final postScript = hooks.post;

    if (preScript != null) {
      await _runLifecycleScript(preScript, command: command);
      logger.newLine();
    }

    try {
      await cb();
    } finally {
      if (postScript != null) {
        logger.newLine();
        await _runLifecycleScript(postScript, command: command);
      }
    }
  }

  Future<void> _runLifecycleScript(
    Script script, {
    required _CommandWithLifecycle command,
  }) async {
    logger
      ..command('melos ${command.name} [${script.name}]')
      ..child(targetStyle(script.command().join(' ').replaceAll('\n', '')))
      ..newLine();

    final exitCode = await _runScript(script, noSelect: true);

    if (exitCode != 0) {
      throw ScriptException._('command/${command.name}/hooks/${script.name}');
    }
  }

  Future<void> run({
    String? scriptName,
    bool noSelect = false,
  });

  Future<int> _runScript(
    Script script, {
    bool noSelect = false,
  });
}

extension _ResolveLifecycleHooks on CommandConfigs {
  LifecycleHooks lifecycleHooksFor(_CommandWithLifecycle command) {
    switch (command) {
      case _CommandWithLifecycle.bootstrap:
        return bootstrap.hooks;
      case _CommandWithLifecycle.clean:
        return clean.hooks;
      case _CommandWithLifecycle.version:
        return version.hooks;
    }
  }
}
