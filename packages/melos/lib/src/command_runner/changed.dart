import '../commands/runner.dart';
import '../common/git.dart';
import 'base.dart';
import 'list.dart';

class ChangedCommand extends MelosCommand with PackageListOutputOptions {
  ChangedCommand(super.config) {
    setupPackageFilterParser(diff: false);
    setupPackageListOutputParser();
  }

  @override
  final String name = 'changed';

  @override
  final String description =
      'List local packages that have changed since a git commit or tag, by '
      'default since the latest release tag of each package. Supports all '
      'package filtering options, except --diff, which is given as the '
      'argument of this command.';

  @override
  final String invocation = 'melos changed [ref]';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length > 1) {
      usageException(
        'The changed command takes at most one revision (commit, tag, or range) '
        'to compare against, but ${rest.length} were given.',
      );
    }
    final diff = rest.isEmpty ? gitDiffSinceLatestTag : rest.first;

    final melos = Melos(logger: logger, config: config);

    return melos.list(
      long: long,
      global: global,
      packageFilters: parsePackageFilters(
        config.path,
        diffEnabled: false,
      ).copyWithDiff(diff),
      relativePaths: relativePaths,
      kind: outputKind,
    );
  }
}
