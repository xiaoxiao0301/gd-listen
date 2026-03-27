/// Sliding-window token-bucket rate limiter.
///
/// Keeps the last N request timestamps and rejects new requests once
/// [maxRequests] have been issued within the rolling [windowMs] window.
class RateLimiter {
  RateLimiter({
    this.windowMs = 5 * 60 * 1000, // 5 minutes
    this.maxRequests = 45,
  });

  final int windowMs;
  final int maxRequests;

  final List<int> _timestamps = [];

  /// Returns `true` if the request is allowed and records the timestamp.
  /// Returns `false` if the rate limit has been reached.
  bool tryAcquire() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - windowMs;

    // Remove timestamps outside the current window.
    _timestamps.removeWhere((ts) => ts < cutoff);

    if (_timestamps.length >= maxRequests) {
      return false;
    }
    _timestamps.add(now);
    return true;
  }

  /// Returns the number of requests remaining in the current window.
  int get remaining {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - windowMs;
    final active = _timestamps.where((ts) => ts >= cutoff).length;
    return (maxRequests - active).clamp(0, maxRequests);
  }
}
