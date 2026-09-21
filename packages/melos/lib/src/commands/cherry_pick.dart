part of 'runner.dart';

mixin _CherryPickMixin on _Melos {
  /// Cherry-picks [commits] onto the current branch without the release changes
  /// they contain.
  ///
  /// Changes to changelogs, to the versions of packages and to the dependencies
  /// between the packages of the workspace are left out of the picked commits,
  /// so that they stay intact on the current branch and a later `melos version`
  /// run releases the picked commits from this branch.
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
        // Separates the conflicted files that git lists in the prepared message
        // from the message, so that they can be removed without stripping the
        // lines of the message that start with a comment character.
        '--cleanup=scissors',
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
        '${pickResult.stdout}${pickResult.stderr}'
        '${_describeRemainingCommits(remainingCommitIds)}',
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
      final conflictedFiles = await _diffFileNames(workspace, [
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
        omittedFiles.isEmpty
            ? 'Skipped $commitLabel since its changes are already on this '
                  'branch.'
            : 'Skipped $commitLabel since it contains no changes besides '
                  'release changes.',
      );
      return;
    }

    if (isStopped) {
      await _commitStoppedPick(workspace);
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

  /// Commits a stopped pick with the message that git has prepared for it,
  /// without the list of conflicted files that git puts below the scissors
  /// line.
  ///
  /// Git only cuts the message at the scissors line when the message is edited,
  /// and stripping all comments instead would also remove the lines of the
  /// original message that start with a comment character.
  Future<void> _commitStoppedPick(MelosWorkspace workspace) async {
    final messagePath = p.join(
      workspace.path,
      await _git(workspace, ['rev-parse', '--git-path', 'MERGE_MSG']),
    );
    final message = await readTextFileAsync(messagePath);
    final scissorsLineStart = message.indexOf(_scissorsLineRegExp);
    if (scissorsLineStart != -1) {
      await writeTextFileAsync(
        messagePath,
        message.substring(0, scissorsLineStart),
      );
    }
    await _git(workspace, ['commit', '--no-edit', '--cleanup=whitespace']);
  }

  /// Restores the changelogs and the release fields of the pubspecs that the
  /// pick in progress has changed to their state in [base] and stages the
  /// result.
  ///
  /// Returns the paths of the files whose release changes have been left out,
  /// relative to the workspace.
  Future<List<String>> _omitReleaseChanges(
    MelosWorkspace workspace,
    _ReleaseFiles releaseFiles, {
    required String base,
    required bool isStopped,
  }) async {
    final changedFiles = await _diffFileNames(workspace, [
      '--relative',
      if (isStopped) ...['--cached', base] else ...[base, 'HEAD'],
    ]);
    final conflictedFiles = (await _diffFileNames(workspace, [
      '--relative',
      '--diff-filter=U',
    ])).toSet();

    final omittedFiles = <String>[];
    for (final file in changedFiles) {
      if (releaseFiles.changelogs.contains(file)) {
        await _restoreFile(workspace, file, base: base);
        omittedFiles.add(file);
      } else if (releaseFiles.pubspecs.contains(file)) {
        final isOmitted = conflictedFiles.contains(file)
            ? await _resolvePubspecReleaseConflict(
                workspace,
                file,
                packageNames: releaseFiles.packageNames,
              )
            : await _restorePubspecReleaseFields(
                workspace,
                file,
                base: base,
                packageNames: releaseFiles.packageNames,
              );
        if (isOmitted) {
          omittedFiles.add(file);
        }
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

  /// Sets the release fields in the pubspec at [file] back to the values they
  /// have in [base] and returns whether any of them had to be changed.
  Future<bool> _restorePubspecReleaseFields(
    MelosWorkspace workspace,
    String file, {
    required String base,
    required Set<String> packageNames,
  }) async {
    final path = _absolutePath(workspace, file);
    if (!fileExists(path) ||
        !await _fileExistsInRevision(workspace, file, revision: base)) {
      return false;
    }

    final baseContents = await _git(workspace, ['show', '$base:./$file']);
    final contents = await readTextFileAsync(path);
    final restoredContents = _withReleaseFieldsOf(
      contents,
      baseContents,
      packageNames: packageNames,
    );
    if (restoredContents == contents) {
      return false;
    }

    await writeTextFileAsync(path, restoredContents);
    await _git(workspace, ['add', '--', file]);
    return true;
  }

  /// Resolves the conflict in the pubspec at [file] by keeping the release
  /// fields of the current branch, and returns whether that resolved the whole
  /// conflict.
  ///
  /// The pubspec is merged again with the release fields of the current branch
  /// set on all sides, so that only conflicts in the other parts of it remain.
  Future<bool> _resolvePubspecReleaseConflict(
    MelosWorkspace workspace,
    String file, {
    required Set<String> packageNames,
  }) async {
    const ancestorStage = 1;
    const currentStage = 2;
    const pickedStage = 3;
    final stages = <int, String>{};
    for (final stage in [currentStage, ancestorStage, pickedStage]) {
      final result = await gitExecuteCommand(
        arguments: ['show', ':$stage:./$file'],
        workingDirectory: workspace.path,
        logger: logger,
        throwOnExitCodeError: false,
      );
      if (result.exitCode != 0) {
        return false;
      }
      stages[stage] = result.stdout as String;
    }

    final mergeDirectory = await Directory.systemTemp.createTemp(
      'melos_cherry_pick_',
    );
    try {
      final mergePaths = <String>[];
      for (final stage in stages.keys) {
        final mergePath = p.join(mergeDirectory.path, '$stage.yaml');
        await writeTextFileAsync(
          mergePath,
          stage == currentStage
              ? stages[stage]!
              : _withReleaseFieldsOf(
                  stages[stage]!,
                  stages[currentStage]!,
                  packageNames: packageNames,
                ),
        );
        mergePaths.add(mergePath);
      }

      final mergeResult = await gitExecuteCommand(
        arguments: ['merge-file', '--stdout', ...mergePaths],
        workingDirectory: workspace.path,
        logger: logger,
        throwOnExitCodeError: false,
      );
      if (mergeResult.exitCode != 0) {
        return false;
      }

      await writeTextFileAsync(
        _absolutePath(workspace, file),
        mergeResult.stdout as String,
      );
      await _git(workspace, ['add', '--', file]);
      return true;
    } finally {
      await mergeDirectory.delete(recursive: true);
    }
  }

  String _absolutePath(MelosWorkspace workspace, String file) =>
      p.join(workspace.path, p.joinAll(p.posix.split(file)));

  /// Returns [pubspecContents] with the release fields of [source], which are
  /// the fields that `melos version` writes to.
  ///
  /// These are the version of the package, and the dependencies on the
  /// packages in [packageNames] that both pubspecs have, since their
  /// constraints and git refs follow the versions of those packages.
  String _withReleaseFieldsOf(
    String pubspecContents,
    String source, {
    required Set<String> packageNames,
  }) {
    final pubspec = loadYaml(pubspecContents);
    final sourcePubspec = loadYaml(source);
    if (pubspec is! YamlMap || sourcePubspec is! YamlMap) {
      return pubspecContents;
    }

    final editor = YamlEditor(pubspecContents);

    final sourceVersion = sourcePubspec['version']?.toString();
    if (pubspec['version']?.toString() != sourceVersion) {
      if (sourceVersion == null) {
        editor.remove(['version']);
      } else {
        editor.update(['version'], sourceVersion);
      }
    }

    for (final section in ['dependencies', 'dev_dependencies']) {
      final dependencies = pubspec[section];
      final sourceDependencies = sourcePubspec[section];
      if (dependencies is! YamlMap || sourceDependencies is! YamlMap) {
        continue;
      }
      for (final name in dependencies.keys) {
        if (!packageNames.contains(name) ||
            !sourceDependencies.containsKey(name)) {
          continue;
        }
        const equality = DeepCollectionEquality();
        if (!equality.equals(dependencies[name], sourceDependencies[name])) {
          editor.update([section, name], sourceDependencies[name]);
        }
      }
    }

    return editor.toString();
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
  /// they are picked.
  ///
  /// The revisions are resolved one after the other, with the commits of a
  /// range ordered from the oldest to the newest. A commit that several
  /// revisions refer to is only picked once.
  Future<List<String>> _resolveCommitsToPick(
    MelosWorkspace workspace,
    List<String> revisions,
  ) async {
    // Insertion ordered, so that a commit keeps the position of the first
    // revision that refers to it.
    final commitIds = <String>{};
    for (final revision in revisions) {
      if (revision.startsWith('^')) {
        throw CherryPickException(
          'Excluding commits with "$revision" is not supported, use a range '
          'such as "${revision.substring(1)}..<end-commit>" instead.',
        );
      }
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
    return commitIds.toList();
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

  /// Returns the names of the files that `git diff` lists for [arguments],
  /// without the quoting that git applies to characters outside of ASCII by
  /// default, so that the names can be compared with the release files.
  Future<List<String>> _diffFileNames(
    MelosWorkspace workspace,
    List<String> arguments,
  ) {
    return _gitLines(workspace, [
      '-c',
      'core.quotePath=false',
      'diff',
      '--name-only',
      ...arguments,
    ]);
  }

  List<String> _lines(String output) {
    return output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

/// Matches the line that git puts above the list of conflicted files in the
/// message of a pick that was started with `--cleanup=scissors`.
final _scissorsLineRegExp = RegExp(r'^.+ -{24} >8 -{24}$', multiLine: true);

/// The files of a workspace that `melos version` writes release changes to, as
/// paths relative to the workspace in the format that git prints them.
class _ReleaseFiles {
  _ReleaseFiles({
    required this.changelogs,
    required this.pubspecs,
    required this.packageNames,
  });

  factory _ReleaseFiles.ofWorkspace(MelosWorkspace workspace) {
    final packages = [
      workspace.rootPackage,
      ...workspace.allPackages.values,
    ];
    final packagePaths = {
      for (final package in packages) package.pathRelativeToWorkspace,
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
      packageNames: {for (final package in packages) package.name},
    );
  }

  final Set<String> changelogs;
  final Set<String> pubspecs;

  /// The names of the packages in the workspace, whose versions the
  /// dependencies between them follow.
  final Set<String> packageNames;

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
        'conflict in a pubspec.yaml file, keep the version and the '
        'constraints on other workspace packages of the current branch. '
        'Afterwards run `git cherry-pick --continue`, or run '
        '`git cherry-pick --abort` to cancel the pick.',
      );
    message.write(_describeRemainingCommits(remainingCommitIds));
    return message.toString().trimRight();
  }
}

String _describeRemainingCommits(List<String> remainingCommitIds) {
  if (remainingCommitIds.isEmpty) {
    return '';
  }
  final description = StringBuffer()
    ..writeln()
    ..writeln(
      'The following commits have not been picked yet, pick them with '
      '`melos cherry-pick` once this commit is dealt with:',
    )
    ..writeln();
  for (final commitId in remainingCommitIds) {
    description.writeln('  $commitId');
  }
  return description.toString().trimRight();
}
