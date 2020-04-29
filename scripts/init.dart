import 'dart:async';
import 'dart:io';

Future<void> flutterPubGet(String workingDirectory) async {
  Process process = await Process.start('flutter', ['pub', 'get'],
      workingDirectory: workingDirectory);

  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);

  await process.exitCode;
}

Future<void> generateWorkspace() async {
  Process process = await Process.start('dart', [
    'scripts/workspace.dart',
  ]);

  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);

  await process.exitCode;
}

void main() async {
  await flutterPubGet(Directory.current.path);
  print("generate project time");
  await generateWorkspace();
  await flutterPubGet(Directory.current.path + Platform.pathSeparator + 'workspace');
}
