import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:melos_cli/src/common/workspace_config.dart';
import 'package:meta/meta.dart';

import 'logger.dart';
import 'package.dart';

MelosWorkspace currentWorkspace;

class MelosWorkspace {
  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

  final MelosWorkspaceConfig _config;

  MelosWorkspaceConfig get config => _config;

  List<MelosPackage> _packages;

  List<MelosPackage> get packages => _packages;

  MelosWorkspace._(this._name, this._path, this._config);

  static Future<MelosWorkspace> fromDirectory(Directory directory,
      {@required ArgResults arguments}) async {
    final workspaceConfig = await MelosWorkspaceConfig.fromDirectory(directory);

    if (workspaceConfig == null) {
      return null;
    }

    return MelosWorkspace._(
        workspaceConfig.name, workspaceConfig.path, workspaceConfig);
  }

  Future<List<MelosPackage>> loadPackages(
      {List<String> scope, List<String> ignore}) async {
    if (_packages != null) return Future.value(_packages);

    _packages = await Directory(_path)
        .list(recursive: true, followLinks: false)
        .where((file) {
      return file.path.endsWith('pubspec.yaml');
    }).where((file) {
      // Filter matching 'packages' config from melos.yaml
      final packageGlobs = _config.packages;
      // No 'package' glob patterns in 'melos.yaml' so skip all packages.
      if (packageGlobs.isEmpty) return false;
      final matchedPattern = packageGlobs.firstWhere((pattern) {
        return pattern.matches(file.path);
      }, orElse: () => null);
      return matchedPattern != null;
    }).asyncMap((entity) async {
      // Convert into Package for further filtering
      return MelosPackage.fromPubspecPath(entity);
    }).where((package) {
      // Scoped packages filter.
      if (scope.isEmpty) return true;
      final matchedPattern = scope.firstWhere((pattern) {
        return Glob(pattern).matches(package.name);
      }, orElse: () => null);
      return matchedPattern != null;
    }).where((package) {
      // Ignore packages filter.
      if (ignore.isEmpty) return true;
      final matchedPattern = ignore.firstWhere((pattern) {
        return Glob(pattern).matches(package.name);
      }, orElse: () => null);
      return matchedPattern == null;
    }).toList();

    return _packages;
  }

  /// Execute a command in the root of this workspace.
  Future<void> exec(
    List<String> execArgs,
  ) async {
    final execProcess = await Process.start(execArgs[0], execArgs.sublist(1),
        workingDirectory: _path,
        runInShell: true,
        includeParentEnvironment: true,
        environment: {
          'MELOS_ROOT_PATH': currentWorkspace.path,
        });

    var stdoutSub;
    var stderrSub;

    final stdoutStream = execProcess.stdout;
    final stderrStream = execProcess.stderr;
    var completeFuture = Completer();

    stdoutSub =
        stdoutStream.listen(stdout.add, onDone: completeFuture.complete);
    stderrSub = stderrStream.listen(stderr.add);

    await completeFuture.future;
    await stdoutSub.cancel();
    await stderrSub.cancel();
    logger.stdout('\n');
  }
}
