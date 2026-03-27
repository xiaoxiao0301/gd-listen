import 'package:drift/drift.dart';

/// Persisted play queue.
///
/// Each row is one position in the queue.  The composite primary key is
/// (position, song_id, source) so the same song can appear multiple times
/// at different positions (e.g. repeat-all queue expansion).
class PlayQueueTable extends Table {
  @override
  String get tableName => 'play_queue';

  /// 0-based position in the queue.
  IntColumn get position => integer()();

  TextColumn get songId => text().named('song_id')();
  TextColumn get source => text()();

  @override
  Set<Column> get primaryKey => {position};
}
