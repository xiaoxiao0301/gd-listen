import 'dart:math';

import 'package:dio/dio.dart';

import '../../utils/rate_limiter.dart';
import '../app_error.dart';

// ─── Rate-limit interceptor ───────────────────────────────────────────────────

/// Rejects requests immediately when the sliding-window quota is exhausted
/// (45 requests / 5-minute window, enforced by [RateLimiter.tryAcquire]).
///
/// On rejection, a [DioException] with `message = 'rate_limit'` is forwarded
/// to the error chain so [ErrorInterceptor] can convert it to [RateLimitError].
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor(this._limiter);

  final RateLimiter _limiter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_limiter.tryAcquire()) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'rate_limit',
        ),
        true, // callFollowingErrorInterceptor = true → ErrorInterceptor runs
      );
      return;
    }
    handler.next(options);
  }
}

// ─── Retry interceptor ────────────────────────────────────────────────────────

/// Retries transient connection failures with truncated-exponential back-off.
///
/// Retryable error types:
///   [DioExceptionType.connectionTimeout], [DioExceptionType.receiveTimeout],
///   [DioExceptionType.connectionError]
///
/// Back-off formula: `200 * 2^attempt` ms (200ms, 400ms, 800ms, …).
///
/// [maxRetries] defaults to 1 (one retry per request, per API spec).
///
/// The [backoffStrategy] parameter allows tests to inject a zero-delay
/// strategy so tests run instantly.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 1,
    Future<void> Function(int attempt)? backoffStrategy,
  }) : _backoff = backoffStrategy ??
            ((int attempt) => Future<void>.delayed(
                  Duration(milliseconds: (200 * pow(2, attempt)).toInt()),
                ));

  final Dio _dio;
  final int maxRetries;
  final Future<void> Function(int attempt) _backoff;

  static const _kRetryKey = '_retryCount';

  static bool _isRetryable(DioExceptionType type) =>
      type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.receiveTimeout ||
      type == DioExceptionType.connectionError;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_kRetryKey] as int?) ?? 0;

    if (_isRetryable(err.type) && attempt < maxRetries) {
      await _backoff(attempt);

      final options = err.requestOptions;
      options.extra[_kRetryKey] = attempt + 1;

      try {
        final response = await _dio.fetch<dynamic>(options);
        handler.resolve(response);
      } on DioException catch (retryErr) {
        handler.next(retryErr);
      }
      return;
    }

    handler.next(err);
  }
}

// ─── Error interceptor ────────────────────────────────────────────────────────

/// Converts every [DioException] into a typed [AppError] so that higher layers
/// only need to handle [AppError] subtypes.
///
/// Conversion table:
///
/// | DioExceptionType          | AppError subtype                |
/// |---------------------------|---------------------------------|
/// | cancel + message=rate_limit | [RateLimitError]              |
/// | connectionTimeout         | [NetworkError]                  |
/// | sendTimeout               | [NetworkError]                  |
/// | receiveTimeout            | [NetworkError]                  |
/// | connectionError           | [NetworkError]                  |
/// | badResponse 404           | [NotFoundError]                 |
/// | badResponse other         | [NetworkError]                  |
/// | badCertificate            | [NetworkError]                  |
/// | cancel (other)            | [UnknownError]                  |
/// | unknown                   | [UnknownError]                  |
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Already converted — avoid double-wrapping (e.g. on retry paths).
    if (err.error is AppError) {
      handler.next(err);
      return;
    }
    final appError = _convert(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        message: err.message,
        error: appError,
      ),
    );
  }

  static AppError _convert(DioException err) {
    // Rate-limit cancellation flagged by RateLimitInterceptor
    if (err.type == DioExceptionType.cancel &&
        err.message == 'rate_limit') {
      return const RateLimitError();
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkError('连接超时，请检查网络');
      case DioExceptionType.connectionError:
        return NetworkError(err.message ?? '网络连接失败');
      case DioExceptionType.badCertificate:
        return const NetworkError('SSL 证书验证失败');
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        if (code == 404) return const NotFoundError(resource: '请求的资源');
        return NetworkError('服务器错误 ($code)');
      case DioExceptionType.cancel:
        return const UnknownError('请求已取消');
      case DioExceptionType.unknown:
        return UnknownError(err.error ?? err);
    }
  }
}
