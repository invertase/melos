import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:melos_workspace/models/package_dependency.dart';
import 'package:melos_workspace/models/workspace.dart';
import 'package:melos_workspace/models/workspace_folder.dart';
import 'package:path/path.dart' as path;

const kArgPackageName = 'package';
const kArgumentOutputPath = 'output';
const kOutputIndentation = '\t';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      kArgPackageName,
      help: 'Name of the target project to generate the workspace for.',
      mandatory: true,
      abbr: 'p',
    )
    ..addOption(
      kArgumentOutputPath,
      help: ''' 
          Output directory path for the generated workspace file. 
          Defaults to the current working directory.
          ''',
      mandatory: false,
      abbr: 'o',
    );

  final argResults = parser.parse(arguments);

  final packageName = argResults[kArgPackageName] as String;
  final outputDirPath =
      argResults[kArgumentOutputPath] as String? ?? Directory.current.path;

  final melosCmdArgs = [
    'list',
    '--all',
    '--include-dependencies',
    '--json',
    '--scope=$packageName',
  ];

  final result = await Process.run(
    'melos',
    melosCmdArgs,
  ).then((result) => result.stdout);

  /// Generate Models
  final List folderJsons = json.decode(result);

  final packages = folderJsons.map(
    (json) => PackageDependency.fromJson(json),
  );
  final workspace = Workspace(
    folders: packages
        .map(
          (package) => WorkspaceFolder(
            name: package.name,
            path: package.location,
          ),
        )
        .toList(),
  );

  /// Prettify output
  final prettyJson = const JsonEncoder.withIndent(kOutputIndentation).convert(
    workspace.toJson(),
  );

  /// Write file to disk
  final fileName = '$packageName.code-workspace';

  final relativeFilePath = path.relative('$outputDirPath/$fileName');
  final file = File(relativeFilePath);
  await file.writeAsString(prettyJson);

  print('Workspace file written to $relativeFilePath');
}
