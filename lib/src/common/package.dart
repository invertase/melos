import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'logger.dart';
import 'utils.dart';

class MelosPackage {
  final Map _yamlContents;

  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

  MelosPackage._(this._name, this._path, this._yamlContents);

  static Future<MelosPackage> fromPubspecPath(
      FileSystemEntity pubspecPath) async {
    final yamlFileContents = await loadYamlFile(pubspecPath.path);
    final pluginName = yamlFileContents['name'] as String;
    return MelosPackage._(
        pluginName, pubspecPath.parent.path, yamlFileContents);
  }

  /// Execute a command from this packages root directory.
  Future<void> exec(List<String> execArgs,
      {stream = false, prefix = true}) async {
    final process = await Process.start(execArgs[0], execArgs.sublist(1),
        workingDirectory: _path,
        runInShell: true,
        environment: {
          'MELOS_PACKAGE_NAME': _name,
          'MELOS_PACKAGE_PATH': _path,
          'MELOS_ROOT_PATH': _path,
        });

    final pluginPrefixTransformer =
        StreamTransformer<String, String>.fromHandlers(
            handleData: (String data, EventSink sink) {
      final lineSplitter = LineSplitter();
      final pluginPrefix =
          logger.ansi.blue + logger.ansi.emphasized(_name) + logger.ansi.none;
      var lines = lineSplitter.convert(data);
      if (prefix == true) {
        lines = lines.map((line) => '[$pluginPrefix]: $line').toList();
      }
      sink.add(lines.join('\n'));
    });

    final stdoutStream = process.stdout
        .transform<String>(utf8.decoder)
        .transform<String>(pluginPrefixTransformer);

    final stderrStream = process.stderr
        .transform<String>(utf8.decoder)
        .transform<String>(pluginPrefixTransformer);

    var stdoutSub;
    var stdoutLogs = [];
    var stderrSub;
    var stderrLogs = [];

    if (stream == true) {
      stdoutSub =
          stdoutStream.transform<List<int>>(utf8.encoder).listen(stdout.add);
      stderrSub =
          stderrStream.transform<List<int>>(utf8.encoder).listen(stderr.add);
    } else {
      stdoutSub = stdoutStream.listen(stdoutLogs.add);
      stderrSub = stderrStream.listen(stderrLogs.add);
    }

    await process.exitCode;
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
}
