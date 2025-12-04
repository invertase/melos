import 'package:meta/meta.dart';

import 'retry_backoff.dart';
import 'validation.dart';

/// HTTP retry configuration for talking to pub (or alternate registries).
///
/// Values map to the `melos.pub` section in the root `pubspec.yaml`, allowing
/// CLI users to tune timeouts and retry behaviour without code changes.
@immutable
class PubClientConfig {
  const PubClientConfig({
    this.requestTimeout,
    this.retryBackoff = const RetryBackoff(),
  });

  factory PubClientConfig.fromYaml(Object? yaml) {
    if (yaml == null) {
      return const PubClientConfig();
    }

    if (yaml is! Map<Object?, Object?>) {
      throw MelosConfigException('pub must be a map if provided.');
    }

    final timeoutSeconds = assertKeyIsA<int?>(
      key: 'timeoutSeconds',
      map: yaml,
    );
    final retryMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'retry',
      map: yaml,
    );

    final retry = retryMap == null
        ? const RetryBackoff()
        : _retryFromYaml(retryMap);

    return PubClientConfig(
      requestTimeout: _timeoutFromSeconds(timeoutSeconds),
      retryBackoff: retry,
    );
  }

  static Duration? _timeoutFromSeconds(int? timeoutSeconds) {
    if (timeoutSeconds == null || timeoutSeconds <= 0) {
      return null;
    }

    return Duration(seconds: timeoutSeconds);
  }

  static RetryBackoff _retryFromYaml(Map<Object?, Object?> retryMap) {
    final delayFactorMillis = assertKeyIsA<num?>(
      key: 'delayFactorMillis',
      map: retryMap,
      path: 'pub/retry',
    );
    final randomizationFactor = assertKeyIsA<num?>(
      key: 'randomizationFactor',
      map: retryMap,
      path: 'pub/retry',
    );
    final maxDelaySeconds = assertKeyIsA<num?>(
      key: 'maxDelaySeconds',
      map: retryMap,
      path: 'pub/retry',
    );
    final maxAttempts = assertKeyIsA<int?>(
      key: 'maxAttempts',
      map: retryMap,
      path: 'pub/retry',
    );

    return RetryBackoff(
      delayFactor: delayFactorMillis == null
          ? const Duration(milliseconds: 200)
          : Duration(milliseconds: delayFactorMillis.round()),
      randomizationFactor: randomizationFactor?.toDouble() ?? 0.25,
      maxDelay: maxDelaySeconds == null
          ? const Duration(seconds: 30)
          : Duration(milliseconds: (maxDelaySeconds * 1000).round()),
      maxAttempts: maxAttempts ?? 8,
    );
  }

  /// Timeout applied to registry HTTP requests. `null` (default) means no
  /// timeout is applied.
  final Duration? requestTimeout;

  /// Retry/backoff settings applied to registry HTTP requests.
  final RetryBackoff retryBackoff;

  Map<String, Object?> toJson() {
    return {
      if (requestTimeout != null) 'timeoutSeconds': requestTimeout!.inSeconds,
      'retry': {
        'delayFactorMillis': retryBackoff.delayFactor.inMilliseconds,
        'randomizationFactor': retryBackoff.randomizationFactor,
        'maxDelaySeconds': retryBackoff.maxDelay.inSeconds,
        'maxAttempts': retryBackoff.maxAttempts,
      },
    };
  }

  @override
  bool operator ==(Object other) {
    return other is PubClientConfig &&
        other.requestTimeout == requestTimeout &&
        other.retryBackoff == retryBackoff;
  }

  @override
  int get hashCode => requestTimeout.hashCode ^ retryBackoff.hashCode;

  @override
  String toString() {
    return '''
PubClientConfig(requestTimeout: $requestTimeout, retryBackoff: $retryBackoff)''';
  }
}
