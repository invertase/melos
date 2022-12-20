import 'dart:convert';
import 'dart:io';

import 'package:pool/pool.dart';

import 'exception.dart';

/// The pool used for restricting access to asynchronous operations that consume
/// file descriptors.
///
/// The maximum number of allocated descriptors is based on empirical tests that
/// indicate that beyond 32, additional file reads don't provide substantial
/// additional throughput.
final _descriptorPool = Pool(32);

/// Determines if a file or directory exists at [path].
bool entryExists(String path) =>
    dirExists(path) || fileExists(path) || linkExists(path);

/// Returns whether [link] exists on the file system.
///
/// This returns `true` for any symlink, regardless of what it points at or
/// whether it's broken.
bool linkExists(String link) => Link(link).existsSync();

/// Returns whether [file] exists on the file system.
///
/// This returns `true` for a symlink only if that symlink is unbroken and
/// points to a file.
bool fileExists(String file) => File(file).existsSync();

/// Returns whether [dir] exists on the file system.
///
/// This returns `true` for a symlink only if that symlink is unbroken and
/// points to a directory.
bool dirExists(String dir) => Directory(dir).existsSync();

/// Reads the contents of the text file [file].
String readTextFile(String file) => File(file).readAsStringSync();

/// Reads the contents of the text file [file].
Future<String> readTextFileAsync(String file) =>
    _descriptorPool.withResource(() => File(file).readAsString());

/// Creates [file] and writes [contents] to it.
///
/// If [dontLogContents] is `true`, the contents of the file will never be
/// logged.
void writeTextFile(
  String file,
  String contents, {
  bool dontLogContents = false,
  Encoding encoding = utf8,
  bool recursive = false,
}) {
  deleteIfLink(file);
  final fileObject = File(file);
  if (recursive) {
    fileObject.createSync(recursive: true);
  }
  fileObject.writeAsStringSync(contents, encoding: encoding);
}

/// Creates [file] and writes [contents] to it.
///
/// If [dontLogContents] is `true`, the contents of the file will never be
/// logged.
Future<void> writeTextFileAsync(
  String file,
  String contents, {
  bool dontLogContents = false,
  Encoding encoding = utf8,
  bool recursive = false,
}) async {
  deleteIfLink(file);
  final fileObject = File(file);
  if (recursive) {
    await fileObject.create(recursive: true);
  }
  await fileObject.writeAsString(contents, encoding: encoding);
}

/// Ensures that [dir] and all its parent directories exist.
///
/// If they don't exist, creates them.
String ensureDir(String dir) {
  Directory(dir).createSync(recursive: true);
  return dir;
}

/// Creates a temp directory in [base], whose name will be [prefix] with
/// characters appended to it to make a unique name.
///
/// Returns the path of the created directory.
String createTempDir(String base, [String? prefix]) =>
    Directory(base).createTempSync(prefix).path;

/// Copies a file [from] the source file [to] the destination file.
void copyFile(String from, String to, {bool recursive = false}) {
  if (recursive) {
    File(to).createSync(recursive: true);
  }
  File(from).copySync(to);
}

/// Deletes [file] if it's a symlink.
///
/// The [File] class overwrites the symlink targets when writing to a file,
/// which is never what we want, so this delete the symlink first if necessary.
void deleteIfLink(String file) {
  if (!linkExists(file)) return;
  Link(file).deleteSync();
}

/// Deletes whatever's at [path], whether it's a file, directory, or symlink.
///
/// If it's a directory, it will be deleted recursively.
void deleteEntry(String path) {
  _attempt('delete entry', () {
    if (linkExists(path)) {
      Link(path).deleteSync();
    } else if (dirExists(path)) {
      Directory(path).deleteSync(recursive: true);
    } else if (fileExists(path)) {
      File(path).deleteSync();
    }
  });
}

extension FileSystemEntityUtils on FileSystemEntity {
  /// Tries to resolve the path of this [FileSystemEntity] through
  /// [resolveSymbolicLinks] and returns `null` if the path cannot be resolved.
  ///
  /// For example, a path cannot be resolved when it is a link to a non-existing
  /// file.
  Future<String?> tryResolveSymbolicLinks() async {
    try {
      return await resolveSymbolicLinks();
    } on FileSystemException {
      return null;
    }
  }
}

/// Tries to resiliently perform [operation].
///
/// Some file system operations can intermittently fail on Windows because other
/// processes are locking a file. We've seen this with virus scanners when we
/// try to delete or move something while it's being scanned. To mitigate that,
/// on Windows, this will retry the operation a few times if it fails.
///
/// For some operations it makes sense to handle ERROR_DIR_NOT_EMPTY
/// differently. They can pass [ignoreEmptyDir] = `true`.
void _attempt(
  String description,
  void Function() operation, {
  bool ignoreEmptyDir = false,
}) {
  if (!Platform.isWindows) {
    operation();
    return;
  }

  String? getErrorReason(FileSystemException error) {
    // ERROR_ACCESS_DENIED
    if (error.osError?.errorCode == 5) {
      return 'access was denied';
    }

    // ERROR_SHARING_VIOLATION
    if (error.osError?.errorCode == 32) {
      return 'it was in use by another process';
    }

    // ERROR_DIR_NOT_EMPTY
    if (!ignoreEmptyDir && _isDirectoryNotEmptyException(error)) {
      return 'of dart-lang/sdk#25353';
    }

    return null;
  }

  const maxRetries = 50;
  for (var i = 0; i < maxRetries; i++) {
    try {
      operation();
      break;
    } on FileSystemException catch (error) {
      final reason = getErrorReason(error);
      if (reason == null) rethrow;

      if (i < maxRetries - 1) {
        sleep(const Duration(milliseconds: 50));
      } else {
        throw IOException(
          'Melos failed to $description because $reason.\n'
          'This may be caused by a virus scanner or having a file\n'
          'in the directory open in another application.\n'
          'Path: ${error.path}\n',
        );
      }
    }
  }
}

bool _isDirectoryNotEmptyException(FileSystemException e) {
  final errorCode = e.osError?.errorCode;
  return
      // On Linux rename will fail with NONEMPTY if directory exists:
      // https://man7.org/linux/man-pages/man2/rename.2.html
      // #define	ENOTEMPTY	39	/* Directory not empty */
      // https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/asm-generic/errno.h#n20
      (Platform.isLinux && errorCode == 39) ||
          // On Windows this may fail with ERROR_DIR_NOT_EMPTY or
          // ERROR_ALREADY_EXISTS
          // https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-
          (Platform.isWindows && (errorCode == 145 || errorCode == 183)) ||
          // On MacOS rename will fail with ENOTEMPTY if directory exists.
          // #define ENOTEMPTY       66              /* Directory not empty */
          // https://github.com/apple-oss-distributions/xnu/blob/bb611c8fecc755a0d8e56e2fa51513527c5b7a0e/bsd/sys/errno.h#L190
          (Platform.isMacOS && errorCode == 66);
}

class IOException extends MelosException {
  IOException(this.message);

  final String message;

  @override
  String toString() => 'IOException: $message';
}
