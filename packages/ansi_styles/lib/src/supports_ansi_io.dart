import 'dart:io' as io;

/// Whether the current environment supports styling via ansi escapes.
bool get supportsAnsiColor => io.stdout.supportsAnsiEscapes;
