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

import 'dart:io';

import 'package:path/path.dart' show joinAll;

class PubFile {
  final String _file;

  final String _directory;

  String get filePath => joinAll([_directory, _file]);

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
