import 'package:path/path.dart' as p;

import '../logging.dart';
import '../workspace.dart';
import 'changelog.dart';
import 'io.dart';
import 'pending_package_update.dart';
import 'utils.dart';

class AggregateChangelog {
  AggregateChangelog(
    this.workspace,
    this.description,
    this.newEntryTitle,
    this.pendingPackageUpdates,
    this.logger,
    this.path,
  );

  final MelosWorkspace workspace;
  final String? description;
  final String newEntryTitle;
  final MelosLogger logger;
  final List<MelosPendingPackageUpdate> pendingPackageUpdates;
  final String path;

  String get _changelogFileHeader => '''
# Change Log

${description?.withoutTrailing('\n') ?? ''}
''';

  String _packageVersionTitle(MelosPendingPackageUpdate update) {
    return '`${update.package.name}` - `v${update.nextVersion}`';
  }

  String _packageVersionMarkdownAnchor(MelosPendingPackageUpdate update) {
    // ignore: prefer_interpolation_to_compose_strings
    return '#' +
        _packageVersionTitle(update)
            .replaceAll(' ', '-')
            .replaceAll(RegExp('[^a-zA-Z_0-9-]'), '');
  }

  String get markdown {
    final body = StringBuffer();
    final dependencyOnlyPackages = pendingPackageUpdates
        .where((update) => update.reason == PackageUpdateReason.dependency);
    final graduatedPackages = pendingPackageUpdates
        .where((update) => update.reason == PackageUpdateReason.graduate);
    final packagesWithBreakingChanges =
        pendingPackageUpdates.where((update) => update.hasBreakingChanges);
    final packagesWithOtherChanges =
        pendingPackageUpdates.where((update) => !update.hasBreakingChanges);

    body.writeln(_changelogFileHeader);
    body.writeln('## $newEntryTitle');
    body.writeln();
    body.writeln('### Changes');
    body.writeln();
    body.writeln('---');
    body.writeln();
    body.writeln('Packages with breaking changes:');
    body.writeln();
    if (packagesWithBreakingChanges.isEmpty) {
      body.writeln(' - There are no breaking changes in this release.');
    } else {
      for (final update in packagesWithBreakingChanges) {
        body.write(' - ');
        body.writeLink(
          _packageVersionTitle(update),
          uri: _packageVersionMarkdownAnchor(update),
        );
        body.writeln();
      }
    }
    body.writeln();
    body.writeln('Packages with other changes:');
    body.writeln();
    if (packagesWithOtherChanges.isEmpty) {
      body.writeln(' - There are no other changes in this release.');
    } else {
      for (final update in packagesWithOtherChanges) {
        body.write(' - ');
        body.writeLink(
          _packageVersionTitle(update),
          uri: _packageVersionMarkdownAnchor(update),
        );
        body.writeln();
      }
    }
    if (graduatedPackages.isNotEmpty) {
      body.writeln();
      body.writeln(
        'Packages graduated to a stable release (see pre-releases prior to the '
        'stable version for changelog entries):',
      );
      body.writeln();
      for (final update in graduatedPackages) {
        body.writeln(' - ${_packageVersionTitle(update)}');
      }
    }
    if (dependencyOnlyPackages.isNotEmpty) {
      body.writeln();
      body.writeln('Packages with dependency updates only:');
      body.writeln();
      body.writeln(
        '> Packages listed below depend on other packages in this workspace '
        'that have had changes. Their versions have been incremented to bump '
        'the minimum dependency versions of the packages they depend upon in '
        'this project.',
      );
      body.writeln();
      for (final update in dependencyOnlyPackages) {
        body.writeln(' - ${_packageVersionTitle(update)}');
      }
    }
    if (packagesWithOtherChanges.isNotEmpty ||
        packagesWithBreakingChanges.isNotEmpty) {
      final allChanges = packagesWithBreakingChanges.toList()
        ..addAll(packagesWithOtherChanges);
      body.writeln();
      body.writeln('---');
      body.writeln();

      for (final update in allChanges) {
        if (update.reason == PackageUpdateReason.dependency) {
          // Dependency only updates have no changelog entries
          // and are already listed in the previous
          // "Packages with dependency updates only" section.
          continue;
        }
        body.writeln('#### ${_packageVersionTitle(update)}');
        body.writeln();

        body.writePackageUpdateChanges(update);
      }
    }

    return body.toString();
  }

  String get absolutePath {
    return p.join(workspace.path, path);
  }

  @override
  String toString() {
    return markdown;
  }

  Future<String> read() async {
    if (fileExists(absolutePath)) {
      final contents = await readTextFileAsync(absolutePath);
      return contents.replaceFirst(_changelogFileHeader, '');
    }
    return '';
  }

  Future<void> write() async {
    var contents = await read();
    if (contents.contains(markdown)) {
      logger.trace(
        'Identical changelog content for ${workspace.name} already exists, '
        'skipping.',
      );
      return;
    }
    contents = '$markdown$contents';

    await writeTextFileAsync(absolutePath, contents);
  }
}
