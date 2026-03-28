import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cache_entries_table.dart';
import '../../models/cache_entry.dart';

part 'cache_dao.g.dart';

@DriftAccessor(tables: [CacheEntriesTable])
class CacheDao extends DatabaseAccessor<AppDatabase> with _$CacheDaoMixin {
  CacheDao(super.db);

  // ── Queries ───────────────────────────────────────────────────────────────

  /// All entries sorted by [lastAccessed] ascending (oldest first for LRU).
  Future<List<CacheEntry>> getAll() async {
    final rows = await (select(cacheEntriesTable)
          ..orderBy([(t) => OrderingTerm.asc(t.lastAccessed)]))
        .get();
    return rows.map(_rowToEntry).toList();
  }

  Future<CacheEntry?> getEntry(String songId, String source) async {
    final row = await (select(cacheEntriesTable)
          ..where(
              (t) => t.songId.equals(songId) & t.source.equals(source)))
        .getSingleOrNull();
    return row != null ? _rowToEntry(row) : null;
  }

  /// Sum of all [fileSizeKb] values, converted to megabytes.
  Future<int> totalSizeMb() async {
    final rows = await select(cacheEntriesTable).get();
    final totalKb = rows.fold<int>(0, (sum, r) => sum + r.fileSizeKb);
    return totalKb ~/ 1024;
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> upsert(CacheEntry entry) async {
    await into(cacheEntriesTable).insertOnConflictUpdate(
      CacheEntriesTableCompanion(
        filePath: Value(entry.filePath),
        songId: Value(entry.songId),
        source: Value(entry.source),
        fileSizeKb: Value(entry.fileSizeKb),
        lastAccessed: Value(entry.lastAccessed),
      ),
    );
  }

  Future<void> remove(String filePath) async {
    await (delete(cacheEntriesTable)
          ..where((t) => t.filePath.equals(filePath)))
        .go();
  }

  Future<void> clear() async => delete(cacheEntriesTable).go();

  // ── Mapping ───────────────────────────────────────────────────────────────

  CacheEntry _rowToEntry(CacheEntriesTableData row) {
    return CacheEntry(
      filePath: row.filePath,
      songId: row.songId,
      source: row.source,
      fileSizeKb: row.fileSizeKb,
      lastAccessed: row.lastAccessed,
    );
  }
}
