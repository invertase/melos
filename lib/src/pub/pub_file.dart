import 'dart:io';

class PubFile {
  final String _file;

  final String _directory;

  String get filePath => '$_directory${Platform.pathSeparator}$_file';

  PubFile(this._directory, this._file);

  Future<void> write() async {
    if (_file.contains(Platform.pathSeparator)) {
      await File(filePath).create(recursive: true);
    }

    return File(filePath).writeAsString(toString());
  }

  void delete() {
    if (_file.contains(Platform.pathSeparator)) {
      try {
        File(filePath).parent.deleteSync(recursive: true);
      } catch (e) {
        // noop
      }
    } else {
      try {
        File(filePath).deleteSync(recursive: false);
      } catch (e) {
        // noop
      }
    }
  }
}
