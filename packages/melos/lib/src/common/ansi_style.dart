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

import 'dart:io' as io;

class AnsiStyle {
  final String open;
  final String close;
  AnsiStyle._(this.open, this.close);

  // Modifiers.
  static AnsiStyle get reset => AnsiStyle(0, 0);
  static AnsiStyle get bold => AnsiStyle(1, 22);
  static AnsiStyle get dim => AnsiStyle(2, 22);
  static AnsiStyle get italic => AnsiStyle(3, 23);
  static AnsiStyle get underline => AnsiStyle(4, 24);
  static AnsiStyle get inverse => AnsiStyle(7, 27);
  static AnsiStyle get hidden => AnsiStyle(8, 28);
  static AnsiStyle get strikethrough => AnsiStyle(9, 29);

  // Text colors.
  static AnsiStyle get black => AnsiStyle(30, 39);
  static AnsiStyle get red => AnsiStyle(31, 39);
  static AnsiStyle get green => AnsiStyle(32, 39);
  static AnsiStyle get yellow => AnsiStyle(33, 39);
  static AnsiStyle get blue => AnsiStyle(34, 39);
  static AnsiStyle get magenta => AnsiStyle(35, 39);
  static AnsiStyle get cyan => AnsiStyle(36, 39);
  static AnsiStyle get white => AnsiStyle(37, 39);
  static AnsiStyle get blackBright => AnsiStyle(90, 39);
  static AnsiStyle get redBright => AnsiStyle(91, 39);
  static AnsiStyle get greenBright => AnsiStyle(92, 39);
  static AnsiStyle get yellowBright => AnsiStyle(93, 39);
  static AnsiStyle get blueBright => AnsiStyle(94, 39);
  static AnsiStyle get magentaBright => AnsiStyle(95, 39);
  static AnsiStyle get cyanBright => AnsiStyle(96, 39);
  static AnsiStyle get whiteBright => AnsiStyle(97, 39);

  // Background colors.
  static AnsiStyle get bgBlack => AnsiStyle(40, 49);
  static AnsiStyle get bgRed => AnsiStyle(41, 49);
  static AnsiStyle get bgGreen => AnsiStyle(42, 49);
  static AnsiStyle get bgYellow => AnsiStyle(43, 49);
  static AnsiStyle get bgBlue => AnsiStyle(44, 49);
  static AnsiStyle get bgMagenta => AnsiStyle(45, 49);
  static AnsiStyle get bgCyan => AnsiStyle(46, 49);
  static AnsiStyle get bgWhite => AnsiStyle(47, 49);
  static AnsiStyle get bgBlackBright => AnsiStyle(100, 49);
  static AnsiStyle get bgRedBright => AnsiStyle(101, 49);
  static AnsiStyle get bgGreenBright => AnsiStyle(102, 49);
  static AnsiStyle get bgYellowBright => AnsiStyle(103, 49);
  static AnsiStyle get bgBlueBright => AnsiStyle(104, 49);
  static AnsiStyle get bgMagentaBright => AnsiStyle(105, 49);
  static AnsiStyle get bgCyanBright => AnsiStyle(106, 49);
  static AnsiStyle get bgWhiteBright => AnsiStyle(107, 49);

  // Aliases.
  static AnsiStyle get grey => AnsiStyle.blackBright;
  static AnsiStyle get bgGrey => AnsiStyle.bgBlackBright;
  static AnsiStyle get gray => AnsiStyle.blackBright;
  static AnsiStyle get bgGray => AnsiStyle.bgBlackBright;

  factory AnsiStyle(int openCode, int closeCode) {
    return AnsiStyle._('\u001B[${openCode}m', '\u001B[${closeCode}m');
  }

  String call(String input) {
    if (io.stdout.supportsAnsiEscapes &&
        io.stdioType(io.stdout) == io.StdioType.terminal) {
      return '$open$input$close';
    }
    return input;
  }
}
