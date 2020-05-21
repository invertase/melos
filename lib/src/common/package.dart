import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:melos_cli/src/common/workspace.dart';

import 'logger.dart';
import 'utils.dart';

class MelosPackage {
  final Map _yamlContents;

  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

  MelosPackage._(this._name, this._path, this._yamlContents);

  Set<String> get dependenciesSet {
    if (_yamlContents['dependencies'] != null) {
      // ignore: omit_local_variable_types
      Set<String> keysSet = <String>{};
      _yamlContents['dependencies'].keys.forEach((key) {
        keysSet.add(key as String);
      });
      return keysSet;
    }
    return {};
  }

  Map<String, dynamic> get devDependencies {
    if (_yamlContents['dev_dependencies'] != null) {
      // ignore: omit_local_variable_types
      Map<String, dynamic> devDeps = {};
      _yamlContents['dev_dependencies'].keys.forEach((key) {
        devDeps[key as String] = _yamlContents['dev_dependencies'][key];
      });
      return devDeps;
    }
    return {};
  }

  Set<String> get devDependenciesSet {
    if (_yamlContents['dev_dependencies'] != null) {
      // ignore: omit_local_variable_types
      Set<String> keysSet = <String>{};
      _yamlContents['dev_dependencies'].keys.forEach((key) {
        keysSet.add(key as String);
      });
      return keysSet;
    }
    return {};
  }

  static Future<MelosPackage> fromPubspecPath(
      FileSystemEntity pubspecPath) async {
    final yamlFileContents = await loadYamlFile(pubspecPath.path);
    final pluginName = yamlFileContents['name'] as String;
    return MelosPackage._(
        pluginName, pubspecPath.parent.path, yamlFileContents);
  }

  Set<String> getDependencyGraph({bool includeDev = true}) {
    var dependencyGraph = <String>{};
    var workspaceGraph = currentWorkspace.dependencyGraph();

    dependenciesSet.forEach((name) {
      dependencyGraph.add(name);
      var children = workspaceGraph[name];
      if (children != null && children.isNotEmpty) {
        dependencyGraph.addAll(children);
      }
    });

    if (includeDev) {
      devDependenciesSet.forEach((name) {
        dependencyGraph.add(name);
        var children = workspaceGraph[name];
        if (children != null && children.isNotEmpty) {
          dependencyGraph.addAll(children);
        }
      });
    }

    return dependencyGraph;
  }

  /// Execute a command from this packages root directory.
  Future<void> exec(List<String> execArgs,
      {stream = false, prefix = true}) async {
    final pluginPrefix =
        logger.ansi.blue + logger.ansi.emphasized(_name) + logger.ansi.none;

    final execProcess = await Process.start(execArgs[0], execArgs.sublist(1),
        workingDirectory: _path,
        runInShell: true,
        includeParentEnvironment: true,
        environment: {
          'MELOS_PACKAGE_NAME': _name,
          'MELOS_PACKAGE_PATH': _path,
          'MELOS_ROOT_PATH': currentWorkspace.path,
        });

    final pluginPrefixTransformer =
    StreamTransformer<String, String>.fromHandlers(
        handleData: (String data, EventSink sink) {
          final lineSplitter = LineSplitter();
          var lines = lineSplitter.convert(data);
          if (prefix == true) {
            lines = lines.map((line) => '[$pluginPrefix]: $line').toList();
          }
          sink.add(lines.join('\n'));
        });

    var stdoutSub;
    var stdoutLogs = [];
    var stderrSub;
    var stderrLogs = [];

    final stdoutStream = execProcess.stdout
        .transform<String>(utf8.decoder)
        .transform<String>(pluginPrefixTransformer);

    final stderrStream = execProcess.stderr
        .transform<String>(utf8.decoder)
        .transform<String>(pluginPrefixTransformer);

    var completeFuture = Completer();
    if (stream == true) {
      stdoutSub = stdoutStream
          .transform<List<int>>(utf8.encoder)
          .listen(stdout.add, onDone: completeFuture.complete);
      stderrSub =
          stderrStream.transform<List<int>>(utf8.encoder).listen(stderr.add);
    } else {
      stdoutSub =
          stdoutStream.listen(stdoutLogs.add, onDone: completeFuture.complete);
      stderrSub = stderrStream.listen(stderrLogs.add);
    }

    await completeFuture.future;
    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (stream == false) {
      if (stdoutLogs.isNotEmpty) {
        print(stdoutLogs.reduce((value, log) => value + '\n$value'));
      }
      if (stderrLogs.isNotEmpty) {
        print(stderrLogs.reduce((value, log) => value + '\n$value'));
      }
    }
  }

  void linkDependencies() {
    // TODO
  }
}
