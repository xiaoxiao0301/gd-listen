import 'package:drift/drift.dart';

/// Songs the user has marked as favourite.
///
/// Composite primary key: (song_id, source).
class FavoritesTable extends Table {
  @override
  String get tableName => 'favorites';

  TextColumn get songId => text().named('song_id')();
  TextColumn get source => text()();

  /// Unix milliseconds when the song was added to favourites.
  IntColumn get addedAt => integer().named('added_at')();

  @override
  Set<Column> get primaryKey => {songId, source};
}
