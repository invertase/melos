import 'dart:async';

import 'package:meta/meta.dart';
import 'package:platform/platform.dart';

@visibleForTesting
const currentPlatformZoneKey = #currentPlatform;

/// The system's platform. Should be used in place of `dart:io`'s [Platform].
///
/// Can be stubbed during tests by setting a the [currentPlatformZoneKey] zone
/// value a [Platform] instance.
Platform get currentPlatform =>
    Zone.current[currentPlatformZoneKey] as Platform? ?? const LocalPlatform();
