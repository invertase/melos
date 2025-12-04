import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:melos/src/common/http.dart';
import 'package:melos/src/common/retry_backoff.dart';
import 'package:melos/src/common/retry_notice.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  setUp(() {
    addTearDown(() {
      internalHttpClient = http.Client();
    });
  });

  group('getWithRetry', () {
    test('retries on retriable status codes', () async {
      var attempts = 0;
      internalHttpClient = HttpClientMock((request) async {
        attempts += 1;
        if (attempts < 3) {
          return http.Response('rate limited', 429);
        }

        return http.Response('ok', 200);
      });

      final notices = <RetryNotice>[];
      final response = await getWithRetry(
        Uri.parse('https://pub.dev/api/packages/melos'),
        onRetry: notices.add,
        backoff: const RetryBackoff(
          delayFactor: Duration.zero,
          randomizationFactor: 0,
          maxDelay: Duration.zero,
          maxAttempts: 4,
        ),
      );

      expect(response.statusCode, 200);
      expect(attempts, 3);
      expect(notices.map((notice) => notice.attempt), [2, 3]);
      expect(notices.every((notice) => notice.statusCode == 429), isTrue);
    });

    test('retries on network errors', () async {
      var attempts = 0;
      internalHttpClient = MockClient((request) async {
        attempts += 1;
        if (attempts == 1) {
          throw const SocketException('connection problem');
        }

        return http.Response('ok', 200);
      });

      final notices = <RetryNotice>[];
      final response = await getWithRetry(
        Uri.parse('https://pub.dev/api/packages/melos'),
        onRetry: notices.add,
        backoff: const RetryBackoff(
          delayFactor: Duration.zero,
          randomizationFactor: 0,
          maxDelay: Duration.zero,
          maxAttempts: 3,
        ),
      );

      expect(response.statusCode, 200);
      expect(attempts, 2);
      expect(notices.single.reason, contains('SocketException'));
    });

    test('does not retry on 404', () async {
      var attempts = 0;
      internalHttpClient = HttpClientMock((request) async {
        attempts += 1;
        return http.Response('missing', 404);
      });

      final notices = <RetryNotice>[];
      final response = await getWithRetry(
        Uri.parse('https://pub.dev/api/packages/melos'),
        onRetry: notices.add,
        backoff: const RetryBackoff(
          delayFactor: Duration.zero,
          randomizationFactor: 0,
          maxDelay: Duration.zero,
          maxAttempts: 3,
        ),
      );

      expect(response.statusCode, 404);
      expect(attempts, 1);
      expect(notices, isEmpty);
    });
  });

  group('RetryBackoff', () {
    test('computes exponential backoff without jitter', () {
      const backoff = RetryBackoff(
        randomizationFactor: 0,
      );

      expect(backoff.delay(1), const Duration(milliseconds: 400));
      expect(backoff.delay(2), const Duration(milliseconds: 800));
      expect(backoff.delay(3), const Duration(milliseconds: 1600));
      expect(backoff.delay(4), const Duration(milliseconds: 3200));
      expect(backoff.delay(5), const Duration(milliseconds: 6400));
      expect(backoff.delay(6), const Duration(milliseconds: 12800));
      expect(backoff.delay(7), const Duration(milliseconds: 25600));
    });

    test('caps at maxDelay', () {
      const maxDelay = Duration(seconds: 60);
      const backoff = RetryBackoff(
        randomizationFactor: 0,
        maxDelay: maxDelay,
      );

      expect(backoff.delay(10), maxDelay);
      expect(backoff.delay(30), maxDelay);
    });
  });
}
