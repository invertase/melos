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

import 'dart:convert';

import 'package:args/command_runner.dart' show Command;
import 'package:ansi_styles/ansi_styles.dart';

import '../common/logger.dart';
import '../common/utils.dart';
import '../common/workspace.dart';

class ListCommand extends Command {
  @override
  final String name = 'list';

  @override
  final List<String> aliases = ['ls'];

  @override
  final String description = 'List local packages.';

  @override
  final String invocation = 'melos list';

  ListCommand() {
    argParser.addFlag('long',
        abbr: 'l',
        defaultsTo: false,
        negatable: false,
        help: 'Show extended information.');
    argParser.addFlag('all',
        abbr: 'a',
        defaultsTo: false,
        negatable: false,
        help: 'Show private packages that are hidden by default.');
    argParser.addFlag('parsable',
        abbr: 'p',
        defaultsTo: false,
        negatable: false,
        help: 'Show parsable output instead of columnified view.');
    argParser.addFlag('json',
        defaultsTo: false,
        negatable: false,
        help: 'Show information as a JSON array.');
    argParser.addFlag('graph',
        defaultsTo: false,
        negatable: false,
        help: 'Show dependency graph as a JSON-formatted adjacency list.');
  }

  void printGraphFormat({bool all = false}) {
    Map<String, List<String>> jsonGraph = {};
    currentWorkspace.packages.forEach((package) {
      if (!all && package.isPrivate) return;
      jsonGraph[package.name] =
          package.dependenciesInWorkspace.map((_) => _.name).toList();
    });

    JsonEncoder encoder = JsonEncoder.withIndent('  ');
    print(encoder.convert(jsonGraph));
  }

  void printJsonFormat({bool all = false, bool long = false}) {
    List<Map<String, dynamic>> jsonArrayItems = [];
    currentWorkspace.packages.forEach((package) {
      if (!all && package.isPrivate) return;
      Map<String, dynamic> jsonObject = {
        'name': package.name,
        'version': package.version.toString(),
        'private': package.isPrivate,
        'location': package.path,
        'type': package.type.index
      };
      if (long) {
        jsonObject.addAll({
          'flutter_package': package.isFlutterPackage,
          'flutter_app': package.isFlutterApp,
          'flutter_plugin': package.isFlutterPlugin,
          'dependencies':
              package.dependenciesInWorkspace.map((_) => _.name).toList(),
          'dependents':
              package.dependentsInWorkspace.map((_) => _.name).toList(),
        });
        if (package.isFlutterApp) {
          jsonObject.addAll({
            'flutter_app_supports_android': package.flutterAppSupportsAndroid,
            'flutter_app_supports_linux': package.flutterAppSupportsLinux,
            'flutter_app_supports_macos': package.flutterAppSupportsMacos,
            'flutter_app_supports_ios': package.flutterAppSupportsIos,
            'flutter_app_supports_web': package.flutterAppSupportsWeb,
            'flutter_app_supports_windows': package.flutterAppSupportsWindows,
          });
        }
        if (package.isFlutterPlugin) {
          jsonObject.addAll({
            'flutter_plugin_supports_android':
                package.flutterPluginSupportsAndroid,
            'flutter_plugin_supports_linux': package.flutterPluginSupportsLinux,
            'flutter_plugin_supports_macos': package.flutterPluginSupportsMacos,
            'flutter_plugin_supports_ios': package.flutterPluginSupportsIos,
            'flutter_plugin_supports_web': package.flutterPluginSupportsWeb,
            'flutter_plugin_supports_windows':
                package.flutterPluginSupportsWindows,
          });
        }
      }
      jsonArrayItems.add(jsonObject);
    });

    JsonEncoder encoder = JsonEncoder.withIndent('  ');
    print(encoder.convert(jsonArrayItems));
  }

  void printDefaultFormat({bool all = false, bool long = false}) {
    if (long) {
      String table = listAsPaddedTable(currentWorkspace.packages
          .map((package) => package.isPrivate && !all
              ? null
              : [
                  package.name,
                  AnsiStyles.green(package.version.toString()),
                  AnsiStyles.gray(package.pathRelativeToWorkspace),
                  all && package.isPrivate ? AnsiStyles.red('PRIVATE') : ''
                ])
          .where((element) => element != null)
          .toList());
      print(table);
    } else {
      currentWorkspace.packages.forEach((package) {
        if (!all && package.isPrivate) return;
        print('${package.name}');
      });
    }
  }

  void printParsableFormat({bool all = false, bool long = false}) {
    if (long) {
      currentWorkspace.packages.forEach((package) {
        if (package.isPrivate && !all) return;
        print([
          package.path,
          package.name,
          package.version ?? '',
          all && package.isPrivate ? 'PRIVATE' : null
        ].where((element) => element != null).join(':'));
      });
    } else {
      currentWorkspace.packages.forEach((package) {
        if (!all && package.isPrivate) return;
        print('${package.path}');
      });
    }
  }

  @override
  void run() async {
    bool long = argResults['long'] as bool;
    bool all = argResults['all'] as bool;
    bool parsable = argResults['parsable'] as bool;
    bool json = argResults['json'] as bool;
    bool graph = argResults['graph'] as bool;

    if (graph) {
      printGraphFormat(all: all);
    } else if (json) {
      printJsonFormat(long: long, all: all);
    } else if (parsable) {
      printParsableFormat(long: long, all: all);
    } else {
      if (currentWorkspace.packages.isEmpty) {
        logger.stdout(AnsiStyles.yellow(
            'No packages were found with the current filters.'));
        logger.stdout(AnsiStyles.gray(
            'Hint: if this is unexpected, try running the command again with a reduced number of filters applied.'));
        return;
      }
      printDefaultFormat(long: long, all: all);
    }
  }
}
