import '../packages/melos/bin/melos.dart' as melos;

// A copy of packages/melos/bin/melos.dart
// This allows us to use melos on itself during development.
void main(List<String> arguments) async {
  if (arguments.contains('-h') || arguments.contains('--help')) {
    // ignore_for_file: avoid_print
    print('---------------------------------------------------------');
    print('| You are running a local development version of melos. |');
    print('---------------------------------------------------------');
    print('');
  }
  await melos.main(arguments);
}
