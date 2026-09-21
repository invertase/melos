import '../commands/runner.dart';
import 'base.dart';

class CherryPickCommand extends MelosCommand {
  CherryPickCommand(super.config) {
    argParser.addFlag(
      'record-origin',
      abbr: 'x',
      defaultsTo: true,
      help:
          'Append a line that says "(cherry picked from commit ...)" to the '
          'message of each picked commit, to record which commit it '
          'originates from.',
    );
    argParser.addOption(
      'mainline',
      abbr: 'm',
      valueHelp: 'parent-number',
      help:
          'The number of the parent, starting from 1, that a picked merge '
          'commit is compared against. Required when picking merge commits.',
    );
  }

  @override
  final String name = 'cherry-pick';

  @override
  final String description =
      'Cherry-pick commits onto the current branch without the release '
      'changes they contain. Changes to changelogs and to the versions of '
      'packages are left out, so that "melos version" can release the picked '
      'commits from this branch, for example a hot-fix branch.';

  @override
  final String invocation = 'melos cherry-pick <commit>...';

  @override
  Future<void> run() async {
    final commits = argResults!.rest;
    if (commits.isEmpty) {
      usageException(
        'The cherry-pick command needs at least one commit or range of '
        'commits to pick.',
      );
    }

    final mainlineArgument = argResults!['mainline'] as String?;
    final mainline = mainlineArgument == null
        ? null
        : int.tryParse(mainlineArgument);
    if (mainlineArgument != null && (mainline == null || mainline < 1)) {
      usageException(
        'The --mainline option needs a parent number starting from 1, but '
        '"$mainlineArgument" was given.',
      );
    }

    final melos = Melos(logger: logger, config: config);

    await melos.cherryPick(
      commits: commits,
      global: global,
      recordOrigin: argResults!['record-origin'] as bool,
      mainline: mainline,
    );
  }
}
