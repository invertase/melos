import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../logging.dart';
import 'retry_backoff.dart';
import 'retry_notice.dart';

@visibleForTesting
http.Client internalHttpClient = http.Client();

http.Client get httpClient => internalHttpClient;

/// Callback invoked before a retry attempt is scheduled.
typedef RetryNoticeCallback = FutureOr<void> Function(RetryNotice notice);

/// Issue a GET request with retry/backoff applied for transient errors.
Future<http.Response> getWithRetry(
  Uri url, {
  Map<String, String>? headers,
  http.Client? client,
  Duration? timeout,
  RetryNoticeCallback? onRetry,
  RetryBackoff backoff = const RetryBackoff(),
  MelosLogger? logger,
}) {
  return _withRetry(
    method: 'GET',
    url: url,
    timeout: timeout,
    onRetry: onRetry,
    backoff: backoff,
    logger: logger,
    request: () => (client ?? httpClient).get(url, headers: headers),
  );
}

/// Issue a POST request with retry/backoff applied for transient errors.
Future<http.Response> postWithRetry(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
  http.Client? client,
  Duration? timeout,
  RetryNoticeCallback? onRetry,
  RetryBackoff backoff = const RetryBackoff(),
  MelosLogger? logger,
}) {
  return _withRetry(
    method: 'POST',
    url: url,
    timeout: timeout,
    onRetry: onRetry,
    backoff: backoff,
    logger: logger,
    request: () => (client ?? httpClient).post(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    ),
  );
}

Future<http.Response> _withRetry({
  required String method,
  required Uri url,
  required Future<http.Response> Function() request,
  Duration? timeout,
  RetryNoticeCallback? onRetry,
  RetryBackoff backoff = const RetryBackoff(),
  MelosLogger? logger,
}) async {
  var attempt = 1;

  while (true) {
    try {
      final pendingResponse = request();
      final response = timeout == null
          ? await pendingResponse
          : await pendingResponse.timeout(
              timeout,
              onTimeout: () => throw TimeoutException(
                '$method $url timed out after ${timeout.inSeconds}s',
              ),
            );

      if (!_shouldRetryResponse(response) || attempt >= backoff.maxAttempts) {
        return response;
      }

      final notice = _noticeFromResponse(
        method: method,
        url: url,
        attempt: attempt,
        backoff: backoff,
        response: response,
      );
      await _handleRetryNotice(notice, onRetry, logger);
      await Future.delayed(notice.delay, () {});
    } catch (error, stackTrace) {
      if (!_shouldRetryError(error) || attempt >= backoff.maxAttempts) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      final notice = _noticeFromError(
        method: method,
        url: url,
        attempt: attempt,
        backoff: backoff,
        error: error,
      );
      await _handleRetryNotice(notice, onRetry, logger);
      await Future.delayed(notice.delay, () {});
    }

    attempt += 1;
  }
}

Future<void> _handleRetryNotice(
  RetryNotice notice,
  RetryNoticeCallback? onRetry,
  MelosLogger? logger,
) async {
  await Future.sync(() => onRetry?.call(notice));

  if (logger != null && logger.isVerbose) {
    final delayDescription = _formatDelay(notice.delay);
    logger.trace(
      '[HTTP] Retrying ${notice.method} ${notice.url} '
      '(${notice.attempt}/${notice.maxAttempts}) in $delayDescription '
      'because ${notice.reason}.',
    );
  }
}

RetryNotice _noticeFromResponse({
  required String method,
  required Uri url,
  required int attempt,
  required RetryBackoff backoff,
  required http.Response response,
}) {
  return RetryNotice(
    url: url,
    method: method,
    attempt: attempt + 1,
    maxAttempts: backoff.maxAttempts,
    delay: backoff.delay(attempt),
    reason: _reasonForStatusCode(response.statusCode),
    statusCode: response.statusCode,
  );
}

RetryNotice _noticeFromError({
  required String method,
  required Uri url,
  required int attempt,
  required RetryBackoff backoff,
  required Object error,
}) {
  return RetryNotice(
    url: url,
    method: method,
    attempt: attempt + 1,
    maxAttempts: backoff.maxAttempts,
    delay: backoff.delay(attempt),
    reason: _reasonForError(error),
    error: error,
  );
}

bool _shouldRetryResponse(http.Response response) {
  final status = response.statusCode;
  if (status == 408 || status == 429) {
    return true;
  }

  return status >= 500 && status < 600;
}

bool _shouldRetryError(Object error) {
  return error is TimeoutException ||
      error is SocketException ||
      error is HttpException ||
      error is TlsException ||
      error is http.ClientException ||
      error is IOException;
}

String _reasonForStatusCode(int statusCode) {
  return switch (statusCode) {
    408 => 'request timed out (HTTP 408)',
    429 => 'rate limited (HTTP 429)',
    _ when statusCode >= 500 && statusCode < 600 =>
      'server error (HTTP $statusCode)',
    _ => 'HTTP $statusCode',
  };
}

String _reasonForError(Object error) {
  if (error is TimeoutException) {
    return 'request timeout';
  }

  return error.toString();
}

String _formatDelay(Duration delay) {
  if (delay.inSeconds >= 1) {
    return '${delay.inSeconds}s';
  }

  return '${delay.inMilliseconds}ms';
}
