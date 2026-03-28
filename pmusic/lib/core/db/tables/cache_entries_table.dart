import 'package:drift/drift.dart';

/// Metadata for locally-cached audio files.
///
/// Primary key is the absolute [filePath]; used for LRU eviction.
class CacheEntriesTable extends Table {
  @override
  String get tableName => 'cache_entries';

  /// Absolute path to the cached audio file on the device.
  TextColumn get filePath => text().named('file_path')();
  TextColumn get songId => text().named('song_id')();
  TextColumn get source => text()();

  /// File size in kilobytes.
  IntColumn get fileSizeKb => integer().named('file_size_kb')();

  /// Unix milliseconds of the last access — drives LRU ordering.
  IntColumn get lastAccessed => integer().named('last_accessed')();

  @override
  Set<Column> get primaryKey => {filePath};
}
