import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:collection/collection.dart';
import 'package:conventional_commit/conventional_commit.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:mustache_template/mustache.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../command_runner/version.dart';
import '../common/exception.dart';
import '../common/git.dart';
import '../common/git_commit.dart';
import '../common/glob.dart';
import '../common/pending_package_update.dart';
import '../common/platform.dart';
import '../common/utils.dart';
import '../common/utils.dart' as utils;
import '../common/versioning.dart' as versioning;
import '../common/workspace_changelog.dart';
import '../global_options.dart';
import '../package.dart';
import '../prompts/prompt.dart' as prompts;
import '../scripts.dart';
import '../workspace.dart';
import '../workspace_configs.dart';
import '../yamlicious/yaml_writer.dart';

part 'bootstrap.dart';
part 'clean.dart';
part 'exec.dart';
part 'list.dart';
part 'publish.dart';
part 'run.dart';
part 'version.dart';

enum ScriptLifecycle {
  bootstrap,
  clean,
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
  }) : logger = logger ?? Logger.standard();

  @override
  final Logger? logger;
  @override
  final MelosWorkspaceConfig config;
}

abstract class _Melos {
  Logger? get logger;
  MelosWorkspaceConfig get config;

  Future<MelosWorkspace> createWorkspace({
    GlobalOptions? global,
    PackageFilter? filter,
  }) async {
    var filterWithEnv = filter;

    if (currentPlatform.environment.containsKey(envKeyMelosPackages)) {
      // MELOS_PACKAGES environment variable is a comma delimited list of
      // package names - used instead of filters if it is present.
      // This can be user defined or can come from package selection in `melos run`.
      filterWithEnv = PackageFilter(
        scope: currentPlatform.environment[envKeyMelosPackages]!
            .split(',')
            .map(
              (e) => createGlob(e, currentDirectoryPath: config.path),
            )
            .toList(),
      );
    }

    return (await MelosWorkspace.fromConfig(
      config,
      global: global,
      filter: filterWithEnv,
      logger: logger,
    ))
      ..validate();
  }

  Future<void> _runLifecycle(
    MelosWorkspace workspace,
    ScriptLifecycle lifecycle,
    FutureOr<void> Function() cb,
  ) async {
    String scriptName;
    switch (lifecycle) {
      case ScriptLifecycle.bootstrap:
        scriptName = 'bootstrap';
        break;
      case ScriptLifecycle.clean:
        scriptName = 'clean';
        break;
    }

    if (workspace.config.scripts.containsKey(scriptName)) {
      logger?.stdout('Running $scriptName script...\n');

      await run(scriptName: scriptName);
    }

    try {
      await cb();
    } finally {
      final postScript = 'post$scriptName';
      if (workspace.config.scripts.containsKey(postScript)) {
        logger?.stdout('Running $postScript script...\n');

        await run(scriptName: postScript);
      }
    }
  }

  Future<void> run({
    String? scriptName,
    bool noSelect = false,
  });
}
