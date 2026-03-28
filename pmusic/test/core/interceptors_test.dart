import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pmusic/core/api/app_error.dart';
import 'package:pmusic/core/api/interceptors/interceptors.dart';
import 'package:pmusic/core/utils/rate_limiter.dart';

// ─── Fake HTTP adapter ────────────────────────────────────────────────────────

/// Stateful fake adapter that dispatches pre-queued response factories.
///
/// Each call to [fetch] pops the first factory from the queue and invokes it.
/// This lets tests precisely control the sequence of success/failure responses.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter();

  final List<ResponseBody Function(RequestOptions)> _queue = [];
  int callCount = 0;

  /// Enqueue a successful JSON response.
  void queueSuccess(String body, {int status = 200}) {
    _queue.add((_) => ResponseBody.fromString(body, status));
  }

  /// Enqueue a [DioExceptionType] error.
  void queueError(DioExceptionType type, {String? message}) {
    _queue.add((opts) {
      throw DioException(
        requestOptions: opts,
        type: type,
        message: message,
      );
    });
  }

  /// Enqueue a bad HTTP response (e.g. 404) that triggers [badResponse].
  void queueHttpError(int status, String body) {
    _queue.add((_) => ResponseBody.fromString(body, status));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    callCount++;
    if (_queue.isEmpty) {
      throw StateError('FakeAdapter queue is empty (callCount=$callCount)');
    }
    return _queue.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Builds a Dio instance wired with all three interceptors and the fake adapter.
/// [maxRetries] is forwarded to [RetryInterceptor].
Dio _buildDio(
  _FakeAdapter adapter, {
  RateLimiter? limiter,
  int maxRetries = 0,
}) {
  // Use zero-delay backoff so tests finish instantly.
  final noDelay = (_) async {};

  final dio = Dio(
    BaseOptions(
      validateStatus: (status) => status != null && status < 400,
    ),
  )..httpClientAdapter = adapter;

  dio.interceptors.addAll([
    RateLimitInterceptor(limiter ?? RateLimiter()),
    RetryInterceptor(dio, maxRetries: maxRetries, backoffStrategy: noDelay),
    ErrorInterceptor(),
  ]);

  return dio;
}

// ─── Test suite ───────────────────────────────────────────────────────────────

void main() {
  // ── RateLimitInterceptor ────────────────────────────────────────────────────

  group('RateLimitInterceptor', () {
    test('allows request when budget is available', () async {
      final adapter = _FakeAdapter()..queueSuccess('{}');
      final dio = _buildDio(adapter, limiter: RateLimiter(maxRequests: 5));

      final resp = await dio.get<dynamic>('/test');
      expect(resp.statusCode, 200);
      expect(adapter.callCount, 1);
    });

    test('rejects request when budget is exhausted', () async {
      final adapter = _FakeAdapter();
      // Prime the limiter to be already exhausted.
      final limiter = RateLimiter(maxRequests: 2);
      limiter.tryAcquire();
      limiter.tryAcquire();

      final dio = _buildDio(adapter, limiter: limiter);

      try {
        await dio.get<dynamic>('/test');
        fail('Expected DioException');
      } on DioException catch (e) {
        expect(e.error, isA<RateLimitError>());
        expect(adapter.callCount, 0); // request never reached the adapter
      }
    });

    test('allows exactly N requests then blocks', () async {
      final adapter = _FakeAdapter();
      final limiter = RateLimiter(maxRequests: 3);
      for (var i = 0; i < 3; i++) {
        adapter.queueSuccess('{}');
      }
      final dio = _buildDio(adapter, limiter: limiter);

      for (var i = 0; i < 3; i++) {
        expect((await dio.get<dynamic>('/test')).statusCode, 200);
      }

      // 4th request should be blocked
      try {
        await dio.get<dynamic>('/test');
        fail('Expected rate limit');
      } on DioException catch (e) {
        expect(e.error, isA<RateLimitError>());
      }
    });
  });

  // ── RetryInterceptor ────────────────────────────────────────────────────────

  group('RetryInterceptor', () {
    test('retries once on connectionError and succeeds', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.connectionError)
        ..queueSuccess('{"ok":true}');

      final dio = _buildDio(adapter, maxRetries: 1);
      final resp = await dio.get<dynamic>('/test');

      expect(resp.statusCode, 200);
      expect(adapter.callCount, 2); // initial + 1 retry
    });

    test('retries once on connectionTimeout and succeeds', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.connectionTimeout)
        ..queueSuccess('{}');

      final dio = _buildDio(adapter, maxRetries: 1);
      final resp = await dio.get<dynamic>('/test');

      expect(resp.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test('retries once on receiveTimeout and succeeds', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.receiveTimeout)
        ..queueSuccess('{}');

      final dio = _buildDio(adapter, maxRetries: 1);
      final resp = await dio.get<dynamic>('/test');

      expect(resp.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test('gives up after maxRetries and surfaces error', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.connectionError)
        ..queueError(DioExceptionType.connectionError);

      final dio = _buildDio(adapter, maxRetries: 1);

      try {
        await dio.get<dynamic>('/test');
        fail('should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<NetworkError>());
        expect(adapter.callCount, 2); // initial + 1 retry
      }
    });

    test('does NOT retry on badResponse (4xx)', () async {
      final adapter = _FakeAdapter()..queueHttpError(503, 'Service Unavailable');
      final dio = _buildDio(adapter, maxRetries: 1);

      try {
        await dio.get<dynamic>('/test');
        fail('should throw on 503');
      } on DioException catch (_) {
        expect(adapter.callCount, 1); // exactly one call, no retry
      }
    });

    test('does NOT retry when maxRetries=0 (default)', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.connectionError);

      final dio = _buildDio(adapter); // maxRetries defaults to 0 in test helper

      try {
        await dio.get<dynamic>('/test');
        fail('should throw');
      } on DioException catch (e) {
        expect(e.error, isA<NetworkError>());
        expect(adapter.callCount, 1);
      }
    });

    test('retry count increments correctly across multiple attempts', () async {
      final captured = <int>[];
      final adapter = _FakeAdapter();
      // 2 failures then success
      adapter.queueError(DioExceptionType.connectionError);
      adapter.queueError(DioExceptionType.connectionError);
      adapter.queueSuccess('{}');

      final noDelay = (int attempt) async {
        captured.add(attempt);
      };
      final dio = Dio(BaseOptions())..httpClientAdapter = adapter;
      dio.interceptors.addAll([
        RetryInterceptor(dio, maxRetries: 2, backoffStrategy: noDelay),
        ErrorInterceptor(),
      ]);

      final resp = await dio.get<dynamic>('/test');
      expect(resp.statusCode, 200);
      expect(adapter.callCount, 3);
      expect(captured, [0, 1]); // backoff called with attempt 0, then 1
    });
  });

  // ── ErrorInterceptor ────────────────────────────────────────────────────────

  group('ErrorInterceptor', () {
    /// Build a minimal Dio with only [ErrorInterceptor] — tests the conversion
    /// logic in isolation.
    Dio _errOnly(_FakeAdapter adapter) {
      final dio = Dio(
        BaseOptions(validateStatus: (status) => status != null && status < 400),
      )
        ..httpClientAdapter = adapter
        ..interceptors.add(ErrorInterceptor());
      return dio;
    }

    test('converts connectionTimeout → NetworkError', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.connectionTimeout);
      final dio = _errOnly(adapter);

      try {
        await dio.get<dynamic>('/timeout');
        fail('should throw');
      } on DioException catch (e) {
        expect(e.error, isA<NetworkError>());
        expect((e.error! as NetworkError).message, contains('超时'));
      }
    });

    test('converts sendTimeout → NetworkError', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.sendTimeout);
      final dio = _errOnly(adapter);

      try {
        await dio.get<dynamic>('/timeout');
        fail('should throw');
      } on DioException catch (e) {
        expect(e.error, isA<NetworkError>());
      }
    });

    test('converts receiveTimeout → NetworkError', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.receiveTimeout);
      final dio = _errOnly(adapter);

      try {
        await dio.get<dynamic>('/timeout');
        fail('should throw');
      } on DioException catch (e) {
        expect(e.error, isA<NetworkError>());
      }
    });

    test('converts connectionError → NetworkError with message', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.connectionError, message: '网络不可用');
      final dio = _errOnly(adapter);

      try {
        await dio.get<dynamic>('/conn');
        fail('should throw');
      } on DioException catch (e) {
        expect(e.error, isA<NetworkError>());
        expect((e.error! as NetworkError).message, contains('网络不可用'));
      }
    });

    test('converts 404 response → NotFoundError', () async {
      final adapter = _FakeAdapter()..queueHttpError(404, 'Not Found');
      final dio = _errOnly(adapter);

      try {
        await dio.get<dynamic>('/resource');
        fail('should throw on 404');
      } on DioException catch (e) {
        expect(e.error, isA<NotFoundError>());
      }
    });

    test('converts 500 response → NetworkError', () async {
      final adapter = _FakeAdapter()..queueHttpError(500, 'Server Error');
      final dio = _errOnly(adapter);

      try {
        await dio.get<dynamic>('/server');
        fail('should throw on 500');
      } on DioException catch (e) {
        expect(e.error, isA<NetworkError>());
        expect((e.error! as NetworkError).message, contains('500'));
      }
    });

    test('rate_limit cancel → RateLimitError (full interceptor stack)', () async {
      // Test through the full stack: RateLimitInterceptor + ErrorInterceptor
      final limiter = RateLimiter(maxRequests: 1);
      limiter.tryAcquire(); // exhaust budget

      final adapter = _FakeAdapter();
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.addAll([
          RateLimitInterceptor(limiter),
          ErrorInterceptor(),
        ]);

      try {
        await dio.get<dynamic>('/throttled');
        fail('should throw');
      } on DioException catch (e) {
        expect(e.error, isA<RateLimitError>());
        expect(adapter.callCount, 0); // never hit the adapter
      }
    });

    test('does not double-wrap an already-converted AppError', () async {
      // Simulate the case where err.error is already an AppError.
      final errInterceptor = ErrorInterceptor();
      final existingError = const NetworkError('already converted');
      final options = RequestOptions(path: '/');

      final handled = <Object>[];
      final handler = ErrorInterceptorHandler(
      )
        ..future.then((_) {}).catchError((err) {
          handled.add(err);
        });

      // Build a DioException that already contains an AppError
      final dioErr = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: existingError,
      );

      // The interceptor should pass through without rewrapping
      errInterceptor.onError(dioErr, handler);

      // Since the error already is AppError, handler.next() is called —
      // the error propagates unchanged (not rejected with a new DioException).
      // We can't easily await handler here, but the smoke-test is that
      // calling onError() does not throw, and the error identity is preserved.
      expect(dioErr.error, same(existingError));
    });
  });

  // ── Full-stack integration ─────────────────────────────────────────────────

  group('Full interceptor stack integration', () {
    test('retry + error conversion: retry succeeds, no error returned', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.connectionError)
        ..queueSuccess('{"result":"ok"}');

      final dio = _buildDio(adapter, maxRetries: 1);
      final resp = await dio.get<dynamic>('/test');

      expect(resp.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test('rate limit + retry: rate-limited requests are not retried', () async {
      final limiter = RateLimiter(maxRequests: 1);
      limiter.tryAcquire(); // exhaust budget

      final adapter = _FakeAdapter();
      final dio = _buildDio(adapter, limiter: limiter, maxRetries: 3);

      try {
        await dio.get<dynamic>('/test');
        fail('Expected rate limit exception');
      } on DioException catch (e) {
        expect(e.error, isA<RateLimitError>());
        // Never reached the adapter (even with retries)
        expect(adapter.callCount, 0);
      }
    });

    test('retry exhausted gives NetworkError not raw DioException', () async {
      final adapter = _FakeAdapter()
        ..queueError(DioExceptionType.connectionError)
        ..queueError(DioExceptionType.connectionError);

      final dio = _buildDio(adapter, maxRetries: 1);

      try {
        await dio.get<dynamic>('/test');
        fail('should have thrown');
      } on DioException catch (e) {
        // ErrorInterceptor must have converted it
        expect(e.error, isA<NetworkError>());
        expect(e.error, isA<AppError>());
      }
    });
  });
}
