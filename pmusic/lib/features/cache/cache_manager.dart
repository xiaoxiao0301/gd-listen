import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_notifier.dart';
import 'cache_repository.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager(ref.read(cacheRepositoryProvider));
});

// ─── CacheManager ─────────────────────────────────────────────────────────────

/// Manages on-disk audio cache using an LRU eviction strategy.
///
/// Call [ensureSpace] before writing a new audio file to guarantee the total
/// cache stays within the user-configured [maxMb] limit.
class CacheManager {
  CacheManager(this._repo);

  final CacheRepository _repo;

  /// Evicts the least-recently-used entries until at least [neededKb] KB of
  /// free space exists within the [maxMb] MB budget.
  ///
  /// [getAll()] returns entries sorted by [lastAccessed] ASC (oldest first).
  /// If the cache is already within budget this is a no-op.
  Future<void> ensureSpace(int neededKb, int maxMb) async {
    final entries = await _repo.getAll();
    final currentKb = entries.fold<int>(0, (sum, e) => sum + e.fileSizeKb);
    final maxKb = maxMb * 1024;

    if (currentKb + neededKb <= maxKb) return;

    var usedKb = currentKb;
    for (final entry in entries) {
      if (usedKb + neededKb <= maxKb) break;
      await _repo.remove(entry.filePath);
      usedKb -= entry.fileSizeKb;
    }
  }
}
