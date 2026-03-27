import 'dart:math';

import 'package:dio/dio.dart';

import '../../utils/rate_limiter.dart';

/// Dio interceptor that enforces the API rate limit (45 req / 5 min).
///
/// If [RateLimiter.tryAcquire] returns `false` the request is rejected
/// immediately with a [DioException] so the upstream error interceptor
/// can convert it to [RateLimitError].
///
/// Full implementation delivered in **P1-05**.
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor(this._limiter);

  final RateLimiter _limiter;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (!_limiter.tryAcquire()) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'rate_limit',
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
}

/// Dio interceptor that retries transient network failures with
/// truncated-exponential back-off.
///
/// Full implementation delivered in **P1-05**.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({this.maxRetries = 3});

  final int maxRetries;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt =
        (err.requestOptions.extra['_retryCount'] as int?) ?? 0;
    final isRetryable = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;

    if (isRetryable && attempt < maxRetries) {
      final backoff =
          Duration(milliseconds: (200 * pow(2, attempt)).toInt());
      await Future<void>.delayed(backoff);
      err.requestOptions.extra['_retryCount'] = attempt + 1;
      // Retry via a new Dio instance is deferred to the full P1-05 impl.
    }
    handler.next(err);
  }
}

/// Dio interceptor that normalises raw [DioException]s into typed
/// [AppError] objects.
///
/// Full implementation delivered in **P1-05**.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Conversion to AppError subtypes happens in P1-05.
    handler.next(err);
  }
}
