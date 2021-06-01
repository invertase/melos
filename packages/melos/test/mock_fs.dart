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
 */

// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:melos/src/common/platform.dart';

/// Overrides the body of a test so that I/O is run against an in-memory
/// file system, not the host's disk.
///
/// The I/O override is applied only to the code running within [testBody].
FutureOr<void> Function() withMockFs(FutureOr<void> Function() testBody) {
  return () {
    return IOOverrides.runWithIOOverrides(testBody, MockFs());
  };
}

/// Used to override file I/O with an in-memory file system for testing.
///
/// Usage:
///
/// ```dart
/// test('My FS test', withMockFs(() {
///   File('foo').createSync(); // File created in memory
/// }));
/// ```
///
/// Alternatively, set [IOOverrides.global] to a [MockFs] instance in your
/// test's `setUp`, and to `null` in the `tearDown`.
class MockFs extends IOOverrides {
  /// Note that we only support [MemoryFileSystem]s, because a local file system
  /// would create infinite loops IOOverride -> FS -> IOOverride -> FS...
  final MemoryFileSystem fs = MemoryFileSystem(
    // Match the platform pathing style
    style: currentPlatform.isWindows
        ? FileSystemStyle.windows
        : FileSystemStyle.posix,
  );

  @override
  Directory createDirectory(String path) => fs.directory(path);

  @override
  File createFile(String path) => fs.file(path);

  @override
  Link createLink(String path) => fs.link(path);

  @override
  Stream<FileSystemEvent> fsWatch(String path, int events, bool recursive) =>
      fs.file(path).watch(events: events, recursive: recursive);

  @override
  bool fsWatchIsSupported() => fs.isWatchSupported;

  @override
  Future<FileSystemEntityType> fseGetType(String path, bool followLinks) =>
      fs.type(path, followLinks: followLinks);

  @override
  FileSystemEntityType fseGetTypeSync(String path, bool followLinks) =>
      fs.typeSync(path, followLinks: followLinks);

  @override
  Future<bool> fseIdentical(String path1, String path2) =>
      fs.identical(path1, path2);

  @override
  bool fseIdenticalSync(String path1, String path2) =>
      fs.identicalSync(path1, path2);

  @override
  Directory getCurrentDirectory() => fs.currentDirectory;

  @override
  Directory getSystemTempDirectory() => fs.systemTempDirectory;

  @override
  void setCurrentDirectory(String path) {
    fs.currentDirectory = path;
  }

  @override
  Future<FileStat> stat(String path) => fs.stat(path);

  @override
  FileStat statSync(String path) => fs.statSync(path);
}
