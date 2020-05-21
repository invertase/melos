import 'dart:io';

class PubFile {
  final String _file;

  final String _directory;

  String get filePath => '$_directory${Platform.pathSeparator}$_file';

  PubFile(this._directory, this._file);

  void write() {
    if (_file.contains(Platform.pathSeparator)) {
      File(filePath).createSync(recursive: true);
    }
    File(filePath).writeAsStringSync(toString());
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
