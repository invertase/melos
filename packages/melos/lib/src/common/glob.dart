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

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Returns a [Glob] configured to work in both production and test
/// environments.
///
/// Workaround for https://github.com/dart-lang/glob/issues/52
Glob createGlob(
  String pattern, {
  p.Context? context,
  bool recursive = false,
  bool? caseSensitive,
  required String currentDirectoryPath,
}) {
  context ??= p.Context(
    style: p.context.style,
    // This ensures that IOOverrides are taken into account when determining the
    // current working directory used by the Glob.
    //
    // See https://github.com/dart-lang/glob/issues/52 for more information.
    current: currentDirectoryPath,
  );
  return Glob(
    pattern,
    context: context,
    recursive: recursive,
    caseSensitive: caseSensitive,
  );
}
