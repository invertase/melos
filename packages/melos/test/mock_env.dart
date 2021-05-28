import 'dart:async';

import 'package:melos/src/common/platform.dart';
import 'package:platform/platform.dart';

/// Overrides the current platform in [testBody] with [platform] for the
/// duration of [testBody].
FutureOr<R> Function() withMockPlatform<R>(
  FutureOr<R> Function() testBody, {
  required Platform platform,
}) {
  return () async {
    return runZoned(
      testBody,
      zoneValues: {
        currentPlatformZoneKey: platform,
      },
    );
  };
}
