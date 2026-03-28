import 'package:drift/drift.dart';

/// Play history — one row per unique (song_id, source) pair.
///
/// On replay, [playedAt] and [playCount] are updated in-place (upsert).
class PlayHistoryTable extends Table {
  @override
  String get tableName => 'play_history';

  /// Most-recent play timestamp as Unix milliseconds.
  IntColumn get playedAt => integer().named('played_at')();
  TextColumn get songId => text().named('song_id')();
  TextColumn get source => text()();

  /// Total number of times this song has been played.
  IntColumn get playCount =>
      integer().named('play_count').withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {songId, source};
}
