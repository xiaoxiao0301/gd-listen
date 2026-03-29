import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../settings/settings_notifier.dart';
import 'cache_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class CacheStatus {
  const CacheStatus({required this.usedMb, required this.maxMb});

  final int usedMb;
  final int maxMb;

  double get usageRatio =>
      maxMb == 0 ? 0.0 : (usedMb / maxMb).clamp(0.0, 1.0);
}

// ─── Providers ────────────────────────────────────────────────────────────────

final cacheRepositoryProvider = Provider<CacheRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return DriftCacheRepository(db);
});

final cacheNotifierProvider =
    AsyncNotifierProvider<CacheNotifier, CacheStatus>(CacheNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CacheNotifier extends AsyncNotifier<CacheStatus> {
  late CacheRepository _repo;

  @override
  Future<CacheStatus> build() async {
    _repo = ref.read(cacheRepositoryProvider);
    final settings = await ref.read(settingsNotifierProvider.future);
    final usedMb = await _repo.totalSizeMb();
    return CacheStatus(usedMb: usedMb, maxMb: settings.cacheMaxMb);
  }

  /// Delete all cached audio files and clear the DB table.
  Future<void> clearAll() async {
    await _repo.clear();
    final settings = await ref.read(settingsNotifierProvider.future);
    state = AsyncValue.data(
      CacheStatus(usedMb: 0, maxMb: settings.cacheMaxMb),
    );
  }

  /// Refresh the displayed usage (call after a new file is cached).
  Future<void> refresh() async {
    final settings = await ref.read(settingsNotifierProvider.future);
    final usedMb = await _repo.totalSizeMb();
    state = AsyncValue.data(
      CacheStatus(usedMb: usedMb, maxMb: settings.cacheMaxMb),
    );
  }
}
