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

import 'src/supports_ansi.dart'
    if (dart.library.io) 'src/supports_ansi_io.dart';

final RegExp _stripRegex = RegExp(
  [
    r'[\u001B\u009B][[\]()#;?]*(?:(?:(?:[a-zA-Z\d]*(?:;[-a-zA-Z\d\/#&.:=?%@~_]*)*)?\u0007)',
    r'(?:(?:\d{1,4}(?:;\\d{0,4})*)?[\dA-PR-TZcf-ntqry=><~]))'
  ].join('|'),
);

void _assertRGBValue(num value) {
  assert(value >= 0);
  assert(value <= 255);
}

num _getRGBColor({num r = 255, num g = 255, num b = 255}) {
  _assertRGBValue(r);
  _assertRGBValue(g);
  _assertRGBValue(b);
  return (((r.clamp(0, 255) / 255) * 5).toInt() * 36 +
          ((g.clamp(0, 255) / 255) * 5).toInt() * 6 +
          ((b.clamp(0, 255) / 255) * 5).toInt() +
          16)
      .clamp(0, 256);
}

class _AnsiStyles {
  factory _AnsiStyles(List<List<String>> styles) {
    return _AnsiStyles._(styles);
  }
  const _AnsiStyles._(this.styles);
  final List<List<String>> styles;

  /// Removes any ANSI styling from any input.
  String strip(String input) {
    return input.replaceAll(_stripRegex, '');
  }

  _AnsiStyles _cloneWithStyles(int openCode, int closeCode) {
    return _AnsiStyles(
      List.from(styles)..add(['\u001B[${openCode}m', '\u001B[${closeCode}m']),
    );
  }

  // Modifiers.
  _AnsiStyles get reset => _cloneWithStyles(0, 0);
  _AnsiStyles get bold => _cloneWithStyles(1, 22);
  _AnsiStyles get dim => _cloneWithStyles(2, 22);
  _AnsiStyles get italic => _cloneWithStyles(3, 23);
  _AnsiStyles get underline => _cloneWithStyles(4, 24);
  _AnsiStyles get blink => _cloneWithStyles(5, 25);
  _AnsiStyles get inverse => _cloneWithStyles(7, 27);
  _AnsiStyles get hidden => _cloneWithStyles(8, 28);
  _AnsiStyles get strikethrough => _cloneWithStyles(9, 29);

  // Text colors.
  _AnsiStyles get black => _cloneWithStyles(30, 39);
  _AnsiStyles get red => _cloneWithStyles(31, 39);
  _AnsiStyles get green => _cloneWithStyles(32, 39);
  _AnsiStyles get yellow => _cloneWithStyles(33, 39);
  _AnsiStyles get blue => _cloneWithStyles(34, 39);
  _AnsiStyles get magenta => _cloneWithStyles(35, 39);
  _AnsiStyles get cyan => _cloneWithStyles(36, 39);
  _AnsiStyles get white => _cloneWithStyles(37, 39);
  _AnsiStyles get blackBright => _cloneWithStyles(90, 39);
  _AnsiStyles get redBright => _cloneWithStyles(91, 39);
  _AnsiStyles get greenBright => _cloneWithStyles(92, 39);
  _AnsiStyles get yellowBright => _cloneWithStyles(93, 39);
  _AnsiStyles get blueBright => _cloneWithStyles(94, 39);
  _AnsiStyles get magentaBright => _cloneWithStyles(95, 39);
  _AnsiStyles get cyanBright => _cloneWithStyles(96, 39);
  _AnsiStyles get whiteBright => _cloneWithStyles(97, 39);

  // Background colors.
  _AnsiStyles get bgBlack => _cloneWithStyles(40, 49);
  _AnsiStyles get bgRed => _cloneWithStyles(41, 49);
  _AnsiStyles get bgGreen => _cloneWithStyles(42, 49);
  _AnsiStyles get bgYellow => _cloneWithStyles(43, 49);
  _AnsiStyles get bgBlue => _cloneWithStyles(44, 49);
  _AnsiStyles get bgMagenta => _cloneWithStyles(45, 49);
  _AnsiStyles get bgCyan => _cloneWithStyles(46, 49);
  _AnsiStyles get bgWhite => _cloneWithStyles(47, 49);
  _AnsiStyles get bgBlackBright => _cloneWithStyles(100, 49);
  _AnsiStyles get bgRedBright => _cloneWithStyles(101, 49);
  _AnsiStyles get bgGreenBright => _cloneWithStyles(102, 49);
  _AnsiStyles get bgYellowBright => _cloneWithStyles(103, 49);
  _AnsiStyles get bgBlueBright => _cloneWithStyles(104, 49);
  _AnsiStyles get bgMagentaBright => _cloneWithStyles(105, 49);
  _AnsiStyles get bgCyanBright => _cloneWithStyles(106, 49);
  _AnsiStyles get bgWhiteBright => _cloneWithStyles(107, 49);

  // Aliases.
  _AnsiStyles get grey => blackBright;
  _AnsiStyles get bgGrey => bgBlackBright;
  _AnsiStyles get gray => blackBright;
  _AnsiStyles get bgGray => bgBlackBright;

  _AnsiStyles rgb(num? r, num? g, num? b) {
    final color = _getRGBColor(r: r ?? 255, g: g ?? 255, b: b ?? 255);
    return _AnsiStyles(
      List.from(styles)..add(['\x1B[38;5;${color}m', '\x1B[0m']),
    );
  }

  _AnsiStyles bgRgb(num? r, num? g, num? b) {
    final color = _getRGBColor(r: r ?? 255, g: g ?? 255, b: b ?? 255);
    return _AnsiStyles(
      List.from(styles)..add(['\x1B[48;5;${color}m', '\x1B[0m']),
    );
  }

  String get bullet => call(!ansiStylesDisabled ? '•' : '-');

  String call(String? input) {
    if (input != null && styles.isNotEmpty && !ansiStylesDisabled) {
      var output = input;
      for (final style in styles) {
        output = '${style[0]}$output${style[1]}';
      }
      return output;
    }

    return input ?? '';
  }
}

/// The entry point to using ansi styling.
///
/// Different styles can be chained successively, and once satisfied called:
///
/// ```dart
/// print(AnsiStyles.red.underline('Underlined red text'));
/// print(AnsiStyles.inverse.italic.green('Inverted italic green text'));
/// print(AnsiStyles.cyan('Cyan text'));
/// print(AnsiStyles.bgYellowBright.bold('Text bold with a yellow background'));
/// ```
// ignore: constant_identifier_names
const AnsiStyles = _AnsiStyles._([]);

/// Flag used to enabled/disable styling support.
///
/// This is mainly used for environments where the raw output is required but is
/// not supported (e.g. testing).
bool ansiStylesDisabled = !supportsAnsiColor;
