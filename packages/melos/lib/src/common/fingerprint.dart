import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

import '../package.dart';
import 'glob.dart';
import 'io.dart';

/// The directory inside of a package in which Melos stores the fingerprints of
/// the commands that succeeded in it.
final fingerprintsDirectory = p.join('.dart_tool', 'melos', 'fingerprints');

/// Tracks whether the [sources] of packages changed since [command] last
/// succeeded in them, so that `melos exec` can skip the packages that are up
/// to date.
///
/// The fingerprint of a package covers the files that match [sources] in the
/// package itself and in all of its transitive dependencies in the workspace,
/// since the result of a command, such as code generation, can depend on
/// them.
class ExecFingerprints {
  ExecFingerprints({required List<String> command, required this.sources})
    : command = command.join(' ');

  final String command;

  /// Globs relative to the root of each package.
  final List<String> sources;

  final _sourcesDigests = <String, Future<String>>{};
  final _matchedSources = <String>{};
  final _dependenciesDigestsAtStart = <String, Map<String, String>>{};
  final _dependenciesDigestsOfUpToDate = <String, Map<String, String>>{};
  final _hashingPool = Pool(32);

  late final _fileName =
      '${sha256.convert(utf8.encode(jsonEncode([command, sources])))}.json';

  String _fingerprintPath(Package package) =>
      p.join(package.path, fingerprintsDirectory, _fileName);

  /// Hashes the sources of [packages] and of their dependencies.
  ///
  /// Has to be called before [command] starts in any package, so that no
  /// sources are hashed for the first time while the command is changing them.
  Future<void> hashSources(List<Package> packages) async {
    final packagesToHash = {
      for (final package in packages) ...{
        package.name: package,
        ...package.allTransitiveDependenciesInWorkspace,
      },
    };
    await Future.wait(packagesToHash.values.map(_sourcesDigest));
  }

  /// The [sources] that did not match a file in any of the packages that were
  /// hashed, which usually indicates a mistake in the glob.
  List<String> get unmatchedSources =>
      sources.whereNot(_matchedSources.contains).toList();

  /// Whether [command] does not have to run in [package], because its
  /// fingerprint is the same as when the command last succeeded in it.
  ///
  /// This has to be checked right before the command would start in the
  /// package, so that it takes into account what the command changed in the
  /// dependencies in which it already finished.
  Future<bool> isUpToDate(Package package) async {
    final dependenciesDigests = await _dependenciesDigests(package);
    final fingerprint = await _fingerprint(package, dependenciesDigests);
    if (await _storedFingerprint(package) != fingerprint) {
      return false;
    }

    _dependenciesDigestsOfUpToDate[package.name] = dependenciesDigests;
    return true;
  }

  /// Has to be called right before [command] starts in [package].
  ///
  /// The stored fingerprint is removed, so that the package is not considered
  /// up to date if the command fails or is interrupted. The state of the
  /// dependencies is recorded, because the result of the command is only known
  /// to be based on the sources that they have at this point.
  Future<void> commandStarted(Package package) async {
    final path = _fingerprintPath(package);
    if (fileExists(path)) {
      deleteEntry(path);
    }
    _dependenciesDigestsAtStart[package.name] = await _dependenciesDigests(
      package,
    );
  }

  /// Has to be called when [command] finished in [package].
  ///
  /// The sources of the package are hashed again, because the command can
  /// generate files that match [sources], which would otherwise make the
  /// package look changed the next time.
  Future<void> commandFinished(
    Package package, {
    required bool succeeded,
  }) async {
    await (_sourcesDigests[package.name] = _computeSourcesDigest(package));
    final dependenciesDigests = _dependenciesDigestsAtStart.remove(
      package.name,
    );
    if (!succeeded || dependenciesDigests == null) {
      return;
    }
    _dependenciesDigestsOfUpToDate[package.name] = dependenciesDigests;

    await writeTextFileAsync(
      _fingerprintPath(package),
      const JsonEncoder.withIndent('  ').convert({
        'command': command,
        'sources': sources,
        'fingerprint': await _fingerprint(package, dependenciesDigests),
      }),
      recursive: true,
    );
  }

  /// Returns the packages that are considered up to date, because they were
  /// skipped or [command] succeeded in them, even though the command changed
  /// the sources of some of their dependencies afterwards, mapped to these
  /// dependencies.
  ///
  /// These packages can be based on outdated sources, which is why the command
  /// runs in them the next time.
  Future<Map<String, List<String>>> findChangedDependencies() async {
    final changedDependencies = <String, List<String>>{};
    for (final MapEntry(key: name, value: digests)
        in _dependenciesDigestsOfUpToDate.entries.toList()) {
      final changed = [
        for (final MapEntry(key: dependency, value: digest) in digests.entries)
          if (await _sourcesDigests[dependency] != digest) dependency,
      ];
      if (changed.isNotEmpty) {
        changedDependencies[name] = changed;
      }
    }
    return changedDependencies;
  }

  Future<String?> _storedFingerprint(Package package) async {
    final path = _fingerprintPath(package);
    if (!fileExists(path)) {
      return null;
    }

    try {
      final stored = jsonDecode(await readTextFileAsync(path));
      final fingerprint = stored is Map<String, Object?>
          ? stored['fingerprint']
          : null;
      return fingerprint is String ? fingerprint : null;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<String> _fingerprint(
    Package package,
    Map<String, String> dependenciesDigests,
  ) async {
    final buffer = StringBuffer()
      ..write(package.name)
      ..write(' ')
      ..writeln(await _sourcesDigest(package));
    for (final MapEntry(key: name, value: digest)
        in dependenciesDigests.entries) {
      buffer
        ..write(name)
        ..write(' ')
        ..writeln(digest);
    }

    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  Future<Map<String, String>> _dependenciesDigests(Package package) async {
    final dependencies =
        package.allTransitiveDependenciesInWorkspace.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return {
      for (final dependency in dependencies)
        dependency.name: await _sourcesDigest(dependency),
    };
  }

  Future<String> _sourcesDigest(Package package) =>
      _sourcesDigests[package.name] ??= _computeSourcesDigest(package);

  Future<String> _computeSourcesDigest(Package package) async {
    try {
      return await _hashSources(package);
    } on FileSystemException {
      // A file could not be read, for example because another process removed
      // it after it was listed. This never matches another digest, so the
      // command runs again.
      return 'unreadable ${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  Future<String> _hashSources(Package package) async {
    final storedFingerprintsPath = p.join(package.path, fingerprintsDirectory);
    final paths = <String>{};

    for (final pattern in sources) {
      // A glob that matches a directory also matches the files inside of it.
      final glob = createGlob(
        pattern,
        currentDirectoryPath: package.path,
        recursive: true,
      );
      await for (final entity in glob.list(root: package.path)) {
        if (entity is File &&
            !p.isWithin(storedFingerprintsPath, entity.path)) {
          paths.add(p.normalize(entity.path));
          _matchedSources.add(pattern);
        }
      }
    }

    final sortedPaths = paths.toList()..sort();
    final digests = await Future.wait(
      sortedPaths.map(
        (path) => _hashingPool.withResource(
          () => sha256.bind(File(path).openRead()).first,
        ),
      ),
    );

    final buffer = StringBuffer();
    for (final (index, path) in sortedPaths.indexed) {
      final relativePath = p.relative(path, from: package.path);
      buffer
        ..write(p.split(relativePath).join('/'))
        ..write(' ')
        ..writeln(digests[index]);
    }

    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }
}
