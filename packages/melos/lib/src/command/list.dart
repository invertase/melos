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
import 'dart:math';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:args/command_runner.dart' show Command;
import 'package:path/path.dart' show dirname;

import '../common/logger.dart';
import '../common/package.dart';
import '../common/utils.dart';
import '../common/workspace.dart';

class ListCommand extends Command {
  ListCommand() {
    argParser.addFlag('long',
        abbr: 'l', negatable: false, help: 'Show extended information.');
    argParser.addFlag('all',
        abbr: 'a',
        negatable: false,
        help: 'Show private packages that are hidden by default.');
    argParser.addFlag('parsable',
        abbr: 'p',
        negatable: false,
        help: 'Show parsable output instead of columnified view.');
    argParser.addFlag('json',
        negatable: false, help: 'Show information as a JSON array.');
    argParser.addFlag('graph',
        negatable: false,
        help: 'Show dependency graph as a JSON-formatted adjacency list.');
    argParser.addFlag('gviz',
        negatable: false,
        help: 'Show dependency graph in Graphviz DOT language.');
  }

  @override
  final String name = 'list';

  @override
  final List<String> aliases = ['ls'];

  @override
  final String description =
      'List local packages in various output formats. Supports all package filtering options.';

  @override
  final String invocation = 'melos list';

  void printGraphFormat({bool all = false}) {
    final jsonGraph = <String, List<String>>{};
    for (final package in currentWorkspace.packages) {
      if (!all && package.isPrivate) {
        continue;
      }
      jsonGraph[package.name] =
          package.dependenciesInWorkspace.map((_) => _.name).toList();
    }

    const encoder = JsonEncoder.withIndent('  ');
    logger.stdout(encoder.convert(jsonGraph));
  }

  void printGvizFormat() {
    String toHex(int color) {
      final colorString = color.toRadixString(16);

      return [if (colorString.length == 1) '0', colorString].join();
    }

    String getColor(String name) {
      final random = Random(name.hashCode);

      final r = random.nextInt(256);
      final g = random.nextInt(256);
      final b = random.nextInt(256);

      return [
        '#',
        toHex(r),
        toHex(g),
        toHex(b),
      ].join();
    }

    final buffer = <String>[];

    buffer.add('digraph packages {');
    buffer.add('  size="10"; ratio=fill;');

    for (final package in currentWorkspace.packages) {
      buffer.add(
          '  ${package.name} [shape="box"; color="${getColor(package.name)}"];');
    }

    for (final package in currentWorkspace.packages) {
      for (final dep in package.dependenciesInWorkspace) {
        buffer.add(
          '  ${package.name} -> ${dep.name} [style="filled"; color="${getColor(dep.name)}"];',
        );
      }

      for (final dep in package.devDependenciesInWorkspace) {
        buffer.add(
          '  ${package.name} -> ${dep.name} [style="dashed"; color="${getColor(dep.name)}"];',
        );
      }
    }

    final groupedPackages = currentWorkspace.packages
        .fold<Map<String, List<MelosPackage>>>({}, (grouped, package) {
      final namespace = dirname(package.pathRelativeToWorkspace);

      if (!grouped.containsKey(namespace)) {
        grouped[namespace] = [];
      }

      grouped[namespace].add(package);

      return grouped;
    });

    groupedPackages.forEach((namespace, packagesInGroup) {
      buffer.add('  subgraph "cluster $namespace" {');
      buffer.add('    label="$namespace";');
      buffer.add('    color="${getColor(namespace)}";');

      for (final package in packagesInGroup) {
        buffer.add('    ${package.name};');
      }

      buffer.add('  }');
    });

    buffer.add('}');

    logger.stdout(buffer.join('\n'));
  }

  void printJsonFormat({bool all = false, bool long = false}) {
    final jsonArrayItems = [];

    for (final package in currentWorkspace.packages) {
      if (!all && package.isPrivate) continue;

      final jsonObject = {
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
    }

    const encoder = JsonEncoder.withIndent('  ');
    logger.stdout(encoder.convert(jsonArrayItems));
  }

  void printDefaultFormat({bool all = false, bool long = false}) {
    if (long) {
      final table = listAsPaddedTable(currentWorkspace.packages
          .map((package) => package.isPrivate && !all
              ? null
              : [
                  package.name,
                  AnsiStyles.green(package.version.toString()),
                  AnsiStyles.gray(package.pathRelativeToWorkspace),
                  if (all && package.isPrivate)
                    AnsiStyles.red('PRIVATE')
                  else
                    ''
                ])
          .where((element) => element != null)
          .toList());
      logger.stdout(table);
    } else {
      for (final package in currentWorkspace.packages) {
        if (!all && package.isPrivate) continue;
        logger.stdout(package.name);
      }
    }
  }

  void printParsableFormat({bool all = false, bool long = false}) {
    for (final package in currentWorkspace.packages) {
      if (package.isPrivate && !all) continue;
      if (long) {
        logger.stdout([
          package.path,
          package.name,
          package.version ?? '',
          if (all && package.isPrivate) 'PRIVATE' else null
        ].where((element) => element != null).join(':'));
      } else {
        logger.stdout(package.path);
      }
    }
  }

  @override
  Future<void> run() async {
    final long = argResults['long'] as bool;
    final all = argResults['all'] as bool;
    final parsable = argResults['parsable'] as bool;
    final json = argResults['json'] as bool;
    final graph = argResults['graph'] as bool;
    final gviz = argResults['gviz'] as bool;

    if (graph) {
      printGraphFormat(all: all);
    } else if (gviz) {
      printGvizFormat();
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
