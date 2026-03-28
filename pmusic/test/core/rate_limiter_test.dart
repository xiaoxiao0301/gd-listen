import 'package:flutter_test/flutter_test.dart';
import 'package:pmusic/core/utils/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    // ── Basic allow/deny ───────────────────────────────────────────────────

    test('allows requests under the limit', () {
      final limiter = RateLimiter(maxRequests: 5, windowMs: 60000);
      for (var i = 0; i < 5; i++) {
        expect(limiter.tryAcquire(), isTrue,
            reason: 'Request ${i + 1} should be allowed');
      }
    });

    test('rejects the request exactly at the limit boundary', () {
      final limiter = RateLimiter(maxRequests: 3, windowMs: 60000);
      limiter.tryAcquire();
      limiter.tryAcquire();
      limiter.tryAcquire();
      // 4th request exceeds the limit
      expect(limiter.tryAcquire(), isFalse);
    });

    test('continues to reject once limit is reached', () {
      final limiter = RateLimiter(maxRequests: 2, windowMs: 60000);
      limiter.tryAcquire();
      limiter.tryAcquire();
      expect(limiter.tryAcquire(), isFalse);
      expect(limiter.tryAcquire(), isFalse);
    });

    // ── remaining counter ──────────────────────────────────────────────────

    test('remaining reports max before any request', () {
      final limiter = RateLimiter(maxRequests: 5, windowMs: 60000);
      expect(limiter.remaining, 5);
    });

    test('remaining decrements correctly', () {
      final limiter = RateLimiter(maxRequests: 5, windowMs: 60000);
      limiter.tryAcquire();
      expect(limiter.remaining, 4);
      limiter.tryAcquire();
      expect(limiter.remaining, 3);
    });

    test('remaining does not go below 0', () {
      final limiter = RateLimiter(maxRequests: 1, windowMs: 60000);
      limiter.tryAcquire();
      limiter.tryAcquire(); // over limit, no-op
      expect(limiter.remaining, 0);
    });

    // ── Sliding-window expiry ──────────────────────────────────────────────

    test('allows requests again after the window expires', () async {
      // 50ms window for a fast test
      final limiter = RateLimiter(maxRequests: 2, windowMs: 50);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isFalse); // limit hit

      // Wait for window to expire
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(limiter.tryAcquire(), isTrue); // window reset, allowed again
    });

    test('sliding window only evicts old entries', () async {
      final limiter = RateLimiter(maxRequests: 3, windowMs: 100);
      limiter.tryAcquire(); // t=0
      await Future<void>.delayed(const Duration(milliseconds: 60));
      limiter.tryAcquire(); // t≈60ms
      limiter.tryAcquire(); // t≈60ms
      // All 3 requests are within the 100ms window
      expect(limiter.tryAcquire(), isFalse);

      // Wait for the first request (t=0) to expire
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Now only 2 requests are in the window → one slot free
      expect(limiter.tryAcquire(), isTrue);
    });

    // ── Default parameters ─────────────────────────────────────────────────

    test('default maxRequests is 45 and windowMs is 5 minutes', () {
      final limiter = RateLimiter();
      expect(limiter.maxRequests, 45);
      expect(limiter.windowMs, 5 * 60 * 1000);
    });

    test('allows 45 requests with default configuration', () {
      final limiter = RateLimiter(); // maxRequests=45
      for (var i = 0; i < 45; i++) {
        expect(limiter.tryAcquire(), isTrue,
            reason: 'Request ${i + 1} of 45 should be allowed');
      }
      expect(limiter.tryAcquire(), isFalse,
          reason: '46th request must be rejected');
    });
  });
}
