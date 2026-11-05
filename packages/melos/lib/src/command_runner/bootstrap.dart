import 'dart:async';

import '../commands/runner.dart';
import '../common/utils.dart';
import 'base.dart';

class BootstrapCommand extends MelosCommand {
  BootstrapCommand(super.config) {
    setupPackageFilterParser();
    argParser.addFlag(
      'no-example',
      negatable: false,
      help: 'Run pub get with/without example pub get',
    );
    argParser.addFlag(
      'enforce-lockfile',
      help:
          'Run pub get with --enforce-lockfile to enforce versions from '
          '.lock files, ensure .lockfile exist for all packages.\n'
          '--no-enforce-lockfile can be used to temporarily disregard the '
          'lockfile versions.',
    );
    argParser.addFlag(
      'offline',
      negatable: false,
      help:
          'Run pub get with --offline to resolve dependencies from local '
          'cache.',
    );
    argParser.addFlag(
      'no-pub',
      negatable: false,
      help:
          'Skip running pub get. Shared dependencies, dependency overrides '
          'and IDE files are still applied.',
    );
  }

  @override
  final String name = 'bootstrap';

  @override
  final List<String> aliases = ['bs', 'bullshit'];

  @override
  final String description =
      'Initialize the workspace, link local packages together and install '
      'remaining package dependencies. Supports all package filtering options.';

  @override
  FutureOr<void>? run() {
    final melos = Melos(logger: logger, config: config);
    return melos.bootstrap(
      global: global,
      packageFilters: parsePackageFilters(config.path),
      enforceLockfile: argResults!.optional('enforce-lockfile') as bool?,
      noExample: argResults!.optional('no-example') as bool?,
      offline: argResults!.optional('offline') as bool?,
      noPub: argResults!.optional('no-pub') as bool?,
    );
  }
}
