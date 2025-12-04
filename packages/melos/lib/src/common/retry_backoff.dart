import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Backoff configuration for retrying HTTP requests.
///
/// Defaults mirror the strategy used by the `retry` package, which is also
/// leveraged by `dart pub`: exponential backoff with jitter across 8 attempts
/// starting at ~400ms and capping at 30s.
@immutable
class RetryBackoff {
  const RetryBackoff({
    this.delayFactor = const Duration(milliseconds: 200),
    this.randomizationFactor = 0.25,
    this.maxDelay = const Duration(seconds: 30),
    this.maxAttempts = 8,
  }) : assert(maxAttempts > 0, 'maxAttempts must be greater than 0');

  final Duration delayFactor;
  final double randomizationFactor;
  final Duration maxDelay;
  final int maxAttempts;

  /// Compute the backoff delay for the given 1-based [attempt].
  Duration delay(int attempt) {
    assert(attempt >= 1, 'attempt must be at least 1');

    final exponential = math.pow(2.0, math.min(attempt, 31)).toDouble();
    final randomizedMultiplier = randomizationFactor == 0
        ? 1.0
        : (1 - randomizationFactor) +
              (_random.nextDouble() * randomizationFactor * 2);
    final rawDelayMicros =
        delayFactor.inMicroseconds * exponential * randomizedMultiplier;
    final cappedDelayMicros = math.min<double>(
      rawDelayMicros,
      maxDelay.inMicroseconds.toDouble(),
    );

    return Duration(microseconds: cappedDelayMicros.round());
  }

  @override
  bool operator ==(Object other) {
    return other is RetryBackoff &&
        other.delayFactor == delayFactor &&
        other.randomizationFactor == randomizationFactor &&
        other.maxDelay == maxDelay &&
        other.maxAttempts == maxAttempts;
  }

  @override
  int get hashCode => Object.hash(
    delayFactor,
    randomizationFactor,
    maxDelay,
    maxAttempts,
  );
}

final _random = math.Random();
