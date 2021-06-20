import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:collection/collection.dart';
import 'package:conventional_commit/conventional_commit.dart';
import 'package:file/local.dart';
import 'package:mustache_template/mustache.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';

import '../command_runner/version.dart';
import '../common/changelog.dart';
import '../common/exception.dart';
import '../common/git.dart';
import '../common/glob.dart';
import '../common/pending_package_update.dart';
import '../common/platform.dart';
import '../common/utils.dart';
import '../common/utils.dart' as utils;
import '../common/versioning.dart' as versioning;
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
  Melos({required this.logger, required this.workingDirectory});

  @override
  final Logger logger;
  @override
  final Directory workingDirectory;
}

abstract class _Melos {
  Logger get logger;
  Directory? get workingDirectory;

  Future<MelosWorkspace> createWorkspace({PackageFilter? filter}) async {
    return MelosWorkspace.fromDirectory(
      workingDirectory!,
      filter: filter,
      logger: logger,
    );
  }

  Future<void> runLifecycle(
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
      logger.stdout('Running $scriptName script...\n');

      await run(scriptName: scriptName, configs: workspace.config);
    }

    try {
      await cb();
    } finally {
      final postScript = 'post$scriptName';
      if (workspace.config.scripts.containsKey(postScript)) {
        logger.stdout('Running $postScript script...\n');

        await run(scriptName: postScript, configs: workspace.config);
      }
    }
  }

  Future<void> run({
    String? scriptName,
    bool noSelect = false,
    MelosWorkspaceConfig? configs,
  });
}
