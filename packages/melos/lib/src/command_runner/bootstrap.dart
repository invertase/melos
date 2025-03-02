import 'dart:async';

import '../commands/runner.dart';
import 'base.dart';

class BootstrapCommand extends MelosCommand {
  BootstrapCommand(super.config) {
    setupPackageFilterParser();
    argParser.addOption(
      'mode',
      allowed: const ['get', 'upgrade', 'downgrade'],
      defaultsTo: 'get',
      help: 'Run pub get, pub upgrade, or pub downgrade',
    );
    argParser.addFlag(
      'no-example',
      negatable: false,
      help: 'Run with/without fetching example dependencies.',
    );
    argParser.addFlag(
      'enforce-lockfile',
      help: 'Run pub get with --enforce-lockfile to enforce versions from '
          '.lock files, ensure .lockfile exist for all packages.\n'
          '--no-enforce-lockfile can be used to temporarily disregard the '
          'lockfile versions.',
    );
    argParser.addFlag(
      'offline',
      negatable: false,
      help: 'Run with --offline to resolve dependencies from local cache.',
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
      mode: BootstrapMode.fromString(argResults?['mode'] as String? ?? 'get'),
      global: global,
      packageFilters: parsePackageFilters(config.path),
      enforceLockfile: argResults?['enforce-lockfile'] as bool?,
      noExample: argResults?['no-example'] as bool,
      offline: argResults?['offline'] as bool,
    );
  }
}
