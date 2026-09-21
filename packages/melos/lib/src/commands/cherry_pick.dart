part of 'runner.dart';

mixin _CherryPickMixin on _Melos {
  /// Cherry-picks [commits] onto the current branch without the release changes
  /// they contain.
  ///
  /// Changes to changelogs and to the versions of packages are left out of the
  /// picked commits, so that the changelog and the versions of the current
  /// branch stay intact and a later `melos version` run releases the picked
  /// commits from this branch.
  ///
  /// Each entry in [commits] is either a single commit or a range of commits
  /// in the git shorthand syntax.
  Future<void> cherryPick({
    required List<String> commits,
    GlobalOptions? global,
    bool recordOrigin = true,
    int? mainline,
  }) async {
    final workspace = await createWorkspace(global: global);

    await _ensureNoUncommittedChanges(workspace);

    final commitIds = await _resolveCommitsToPick(workspace, commits);
    if (commitIds.isEmpty) {
      throw CherryPickException('There are no commits to pick in $commits.');
    }

    final releaseFiles = _ReleaseFiles.ofWorkspace(workspace);

    for (final (index, commitId) in commitIds.indexed) {
      await _cherryPickCommit(
        workspace,
        commitId,
        releaseFiles: releaseFiles,
        remainingCommitIds: commitIds.sublist(index + 1),
        recordOrigin: recordOrigin,
        mainline: mainline,
      );
    }

    logger
      ..newLine()
      ..hint(
        'Run `melos version` on this branch to release the picked commits.',
      );
  }

  Future<void> _cherryPickCommit(
    MelosWorkspace workspace,
    String commitId, {
    required _ReleaseFiles releaseFiles,
    required List<String> remainingCommitIds,
    required bool recordOrigin,
    required int? mainline,
  }) async {
    final subject = await _git(workspace, [
      'show',
      '--no-patch',
      '--format=%s',
      commitId,
    ]);
    final commitLabel = '${commitId.substring(0, 8)} $subject';

    final pickResult = await gitExecuteCommand(
      arguments: [
        'cherry-pick',
        if (recordOrigin) '-x',
        if (mainline != null) ...['--mainline', '$mainline'],
        commitId,
      ],
      workingDirectory: workspace.path,
      logger: logger,
      throwOnExitCodeError: false,
    );
    final isStopped = pickResult.exitCode != 0;
    if (isStopped && !await _isCherryPickInProgress(workspace)) {
      throw CherryPickException(
        'Could not pick $commitLabel:\n'
        '${pickResult.stdout}${pickResult.stderr}',
      );
    }

    // A stopped pick has not created a commit yet, so the branch is still at
    // the commit the release files are restored from.
    final base = isStopped ? 'HEAD' : 'HEAD~1';
    final omittedFiles = await _omitReleaseChanges(
      workspace,
      releaseFiles,
      base: base,
      isStopped: isStopped,
    );

    if (isStopped) {
      final conflictedFiles = await _gitLines(workspace, [
        'diff',
        '--name-only',
        '--diff-filter=U',
      ]);
      if (conflictedFiles.isNotEmpty) {
        throw CherryPickConflictException(
          commitLabel: commitLabel,
          conflictedFiles: conflictedFiles,
          remainingCommitIds: remainingCommitIds,
        );
      }
    }

    if (await _hasNoStagedChangesSince(workspace, base)) {
      await _git(
        workspace,
        isStopped ? ['cherry-pick', '--abort'] : ['reset', '--soft', base],
      );
      logger.log(
        'Skipped $commitLabel since it contains no changes besides release '
        'changes.',
      );
      return;
    }

    if (isStopped) {
      // Git lists the conflicted files as comments in the prepared message,
      // which are only removed when the message is stripped.
      await _git(workspace, ['commit', '--no-edit', '--cleanup=strip']);
    } else if (omittedFiles.isNotEmpty) {
      await _git(workspace, ['commit', '--amend', '--no-edit']);
    }

    logger.log('Picked $commitLabel');
    if (omittedFiles.isNotEmpty) {
      final omittedLogger = logger.childWithoutMessage()
        ..log('Left out the release changes in:');
      omittedFiles.forEach(omittedLogger.childWithoutMessage().log);
    }
  }

  /// Restores the changelogs and the package versions that the pick in progress
  /// has changed to their state in [base] and stages the result.
  ///
  /// Returns the paths of the files whose release changes have been left out,
  /// relative to the workspace.
  Future<List<String>> _omitReleaseChanges(
    MelosWorkspace workspace,
    _ReleaseFiles releaseFiles, {
    required String base,
    required bool isStopped,
  }) async {
    final changedFiles = await _gitLines(workspace, [
      'diff',
      '--name-only',
      '--relative',
      if (isStopped) ...['--cached', base] else ...[base, 'HEAD'],
    ]);
    final conflictedFiles = (await _gitLines(workspace, [
      'diff',
      '--name-only',
      '--relative',
      '--diff-filter=U',
    ])).toSet();

    final omittedFiles = <String>[];
    for (final file in changedFiles) {
      if (releaseFiles.changelogs.contains(file)) {
        await _restoreFile(workspace, file, base: base);
        omittedFiles.add(file);
      } else if (releaseFiles.pubspecs.contains(file) &&
          !conflictedFiles.contains(file) &&
          await _restorePubspecVersion(workspace, file, base: base)) {
        omittedFiles.add(file);
      }
    }
    return omittedFiles;
  }

  Future<void> _restoreFile(
    MelosWorkspace workspace,
    String file, {
    required String base,
  }) async {
    if (await _fileExistsInRevision(workspace, file, revision: base)) {
      await _git(workspace, ['checkout', base, '--', file]);
    } else {
      await _git(workspace, ['rm', '--force', '--quiet', '--', file]);
    }
  }

  /// Sets the version in the pubspec at [file] back to the version it has in
  /// [base] and returns whether the version had to be changed.
  Future<bool> _restorePubspecVersion(
    MelosWorkspace workspace,
    String file, {
    required String base,
  }) async {
    final path = p.join(workspace.path, p.joinAll(p.posix.split(file)));
    if (!fileExists(path) ||
        !await _fileExistsInRevision(workspace, file, revision: base)) {
      return false;
    }

    final baseContents = await _git(workspace, ['show', '$base:./$file']);
    final contents = await readTextFileAsync(path);
    final baseVersion = _pubspecVersion(baseContents);
    if (baseVersion == _pubspecVersion(contents)) {
      return false;
    }

    final editor = YamlEditor(contents);
    if (baseVersion == null) {
      editor.remove(['version']);
    } else {
      editor.update(['version'], baseVersion);
    }
    await writeTextFileAsync(path, editor.toString());
    await _git(workspace, ['add', '--', file]);
    return true;
  }

  String? _pubspecVersion(String pubspecContents) {
    final pubspec = loadYaml(pubspecContents);
    return pubspec is YamlMap ? pubspec['version']?.toString() : null;
  }

  Future<void> _ensureNoUncommittedChanges(MelosWorkspace workspace) async {
    final changes = await _gitLines(workspace, [
      'status',
      '--porcelain',
      '--untracked-files=no',
    ]);
    if (changes.isNotEmpty) {
      throw CherryPickException(
        'There are uncommitted changes in the repository. Commit or stash '
        'them before picking commits.',
      );
    }
  }

  /// Returns the ids of the commits that [revisions] refer to, in the order
  /// they are picked, which is the same order that `git cherry-pick` uses.
  Future<List<String>> _resolveCommitsToPick(
    MelosWorkspace workspace,
    List<String> revisions,
  ) async {
    final commitIds = <String>[];
    for (final revision in revisions) {
      final result = await gitExecuteCommand(
        arguments: gitIsRevisionRange(revision)
            ? ['rev-list', '--reverse', revision]
            : ['rev-parse', '--verify', '--quiet', '$revision^{commit}'],
        workingDirectory: workspace.path,
        logger: logger,
        throwOnExitCodeError: false,
      );
      if (result.exitCode != 0) {
        throw CherryPickException(
          'The revision "$revision" does not exist in this repository.',
        );
      }
      commitIds.addAll(_lines(result.stdout as String));
    }
    return commitIds;
  }

  Future<bool> _isCherryPickInProgress(MelosWorkspace workspace) async {
    final result = await gitExecuteCommand(
      arguments: ['rev-parse', '--verify', '--quiet', 'CHERRY_PICK_HEAD'],
      workingDirectory: workspace.path,
      logger: logger,
      throwOnExitCodeError: false,
    );
    return result.exitCode == 0;
  }

  Future<bool> _hasNoStagedChangesSince(
    MelosWorkspace workspace,
    String revision,
  ) async {
    final result = await gitExecuteCommand(
      arguments: ['diff', '--cached', '--quiet', revision],
      workingDirectory: workspace.path,
      logger: logger,
      throwOnExitCodeError: false,
    );
    return result.exitCode == 0;
  }

  Future<bool> _fileExistsInRevision(
    MelosWorkspace workspace,
    String file, {
    required String revision,
  }) async {
    final result = await gitExecuteCommand(
      arguments: ['cat-file', '-e', '$revision:./$file'],
      workingDirectory: workspace.path,
      logger: logger,
      throwOnExitCodeError: false,
    );
    return result.exitCode == 0;
  }

  Future<String> _git(MelosWorkspace workspace, List<String> arguments) async {
    final result = await gitExecuteCommand(
      arguments: arguments,
      workingDirectory: workspace.path,
      logger: logger,
    );
    return (result.stdout as String).trim();
  }

  Future<List<String>> _gitLines(
    MelosWorkspace workspace,
    List<String> arguments,
  ) async {
    return _lines(await _git(workspace, arguments));
  }

  List<String> _lines(String output) {
    return output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

/// The files of a workspace that `melos version` writes release changes to, as
/// paths relative to the workspace in the format that git prints them.
class _ReleaseFiles {
  _ReleaseFiles({required this.changelogs, required this.pubspecs});

  factory _ReleaseFiles.ofWorkspace(MelosWorkspace workspace) {
    final packagePaths = {
      workspace.rootPackage.pathRelativeToWorkspace,
      for (final package in workspace.allPackages.values)
        package.pathRelativeToWorkspace,
    };
    final aggregateChangelogs =
        workspace.config.commands.version.aggregateChangelogs;

    return _ReleaseFiles(
      changelogs: {
        for (final packagePath in packagePaths)
          _gitPath(p.join(packagePath, 'CHANGELOG.md')),
        for (final aggregateChangelog in aggregateChangelogs)
          _gitPath(aggregateChangelog.path),
      },
      pubspecs: {
        for (final packagePath in packagePaths)
          _gitPath(p.join(packagePath, 'pubspec.yaml')),
      },
    );
  }

  final Set<String> changelogs;
  final Set<String> pubspecs;

  static String _gitPath(String path) =>
      p.posix.joinAll(p.split(p.normalize(path)));
}

class CherryPickException extends MelosException {
  CherryPickException(this.message);

  final String message;

  @override
  String toString() {
    return 'CherryPickException: $message';
  }
}

class CherryPickConflictException extends MelosException {
  CherryPickConflictException({
    required this.commitLabel,
    required this.conflictedFiles,
    required this.remainingCommitIds,
  });

  final String commitLabel;
  final List<String> conflictedFiles;
  final List<String> remainingCommitIds;

  @override
  String toString() {
    final message = StringBuffer()
      ..writeln(
        'CherryPickConflictException: Picking $commitLabel resulted in '
        'conflicts that have to be resolved manually:',
      )
      ..writeln();
    for (final file in conflictedFiles) {
      message.writeln('  $file');
    }
    message
      ..writeln()
      ..writeln(
        'The changelogs have already been restored. When resolving a '
        'conflict in a pubspec.yaml file, keep the version of the current '
        'branch. Afterwards run `git cherry-pick --continue`, or run '
        '`git cherry-pick --abort` to cancel the pick.',
      );
    if (remainingCommitIds.isNotEmpty) {
      message
        ..writeln()
        ..writeln(
          'The following commits have not been picked yet, pick them with '
          '`melos cherry-pick` once the conflicts are resolved:',
        )
        ..writeln();
      for (final commitId in remainingCommitIds) {
        message.writeln('  $commitId');
      }
    }
    return message.toString().trimRight();
  }
}
