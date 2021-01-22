// @dart=2.9
import 'dart:io' show Directory, Platform, Process;

// Workaround for 'pubspec.yaml file has changed' issue when using melos on itself.
Future<void> main() async {
  final melosPackageDirectory = [Directory.current.path, 'packages', 'melos']
      .join(Platform.pathSeparator);
  Process.runSync('dart', ['pub', 'get'],
      workingDirectory: melosPackageDirectory);
}
