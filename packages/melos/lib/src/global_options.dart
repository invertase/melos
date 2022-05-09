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

/// Global options that apply to all Melos commands.
class GlobalOptions {
  const GlobalOptions({
    this.verbose = false,
    this.sdkPath,
  });

  /// Whether to print verbose output.
  final bool verbose;

  /// Path to the Dart/Flutter SDK that should be used.
  final String? sdkPath;

  Map<String, Object?> toJson() {
    return {
      'verbose': verbose,
      'sdkPath': sdkPath,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalOptions &&
          other.runtimeType == runtimeType &&
          other.verbose == verbose &&
          other.sdkPath == sdkPath;

  @override
  int get hashCode => verbose.hashCode ^ sdkPath.hashCode;

  @override
  String toString() {
    return '''
GlobalOptions(
  verbose: $verbose,
  sdkPath: $sdkPath,
)''';
  }
}
