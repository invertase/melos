/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

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
    );
  }
}
