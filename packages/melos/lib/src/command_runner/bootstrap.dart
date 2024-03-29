import 'dart:async';

import '../commands/runner.dart';
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
      negatable: false,
      help: 'Run pub get with --enforce-lockfile to enforce versions from .lock'
          ' files, ensure .lockfile exist for all packages.',
    );
    argParser.addFlag(
      'skip-linking',
      negatable: false,
      help: 'Skips locally linking workspace packages.',
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
      enforceLockfile: argResults?['enforce-lockfile'] as bool? ?? false,
      noExample: argResults?['no-example'] as bool,
      skipLinking: argResults?['skip-linking'] as bool,
    );
  }
}
