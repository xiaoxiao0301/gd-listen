import 'dart:io';

import '../../core/db/app_database.dart';
import '../../core/db/daos/cache_dao.dart';
import '../../core/models/cache_entry.dart';

// ─── Repository interface ─────────────────────────────────────────────────────

abstract class CacheRepository {
  /// All entries sorted by [lastAccessed] ascending (oldest first for LRU).
  Future<List<CacheEntry>> getAll();
  Future<void> add(CacheEntry entry);

  /// Remove an entry from the DB and delete the corresponding file from disk.
  Future<void> remove(String filePath);

  /// Clear all entries and delete all cached files from disk.
  Future<void> clear();

  /// Total cached size in megabytes.
  Future<int> totalSizeMb();
}

// ─── Drift implementation ─────────────────────────────────────────────────────

class DriftCacheRepository implements CacheRepository {
  DriftCacheRepository(AppDatabase db) : _dao = db.cacheDao;

  final CacheDao _dao;

  @override
  Future<List<CacheEntry>> getAll() => _dao.getAll();

  @override
  Future<void> add(CacheEntry entry) => _dao.upsert(entry);

  @override
  Future<void> remove(String filePath) async {
    await _dao.remove(filePath);
    try {
      await File(filePath).delete();
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    final entries = await _dao.getAll();
    for (final e in entries) {
      try {
        await File(e.filePath).delete();
      } catch (_) {}
    }
    await _dao.clear();
  }

  @override
  Future<int> totalSizeMb() => _dao.totalSizeMb();
}

// ─── In-memory stub (used in tests) ───────────────────────────────────────────

class InMemoryCacheRepository implements CacheRepository {
  final Map<String, CacheEntry> _entries = {};

  @override
  Future<List<CacheEntry>> getAll() async => _entries.values.toList()
    ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

  @override
  Future<void> add(CacheEntry entry) async {
    _entries[entry.filePath] = entry;
  }

  @override
  Future<void> remove(String filePath) async {
    _entries.remove(filePath);
    try {
      await File(filePath).delete();
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    for (final e in _entries.values) {
      try {
        await File(e.filePath).delete();
      } catch (_) {}
    }
    _entries.clear();
  }

  @override
  Future<int> totalSizeMb() async {
    final totalKb = _entries.values.fold<int>(0, (s, e) => s + e.fileSizeKb);
    return totalKb ~/ 1024;
  }
}
