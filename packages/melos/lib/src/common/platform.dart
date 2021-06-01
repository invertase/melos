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

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:platform/platform.dart';

@visibleForTesting
const currentPlatformZoneKey = #currentPlatform;

/// The system's platform. Should be used in place of `dart:io`'s [Platform].
///
/// Can be stubbed during tests by setting a the [currentPlatformZoneKey] zone value
/// a [Platform] instance.
Platform get currentPlatform =>
    Zone.current[currentPlatformZoneKey] as Platform? ?? const LocalPlatform();
