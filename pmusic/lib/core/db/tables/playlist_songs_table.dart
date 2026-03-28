import 'package:drift/drift.dart';

import 'playlists_table.dart';

/// Junction table linking songs to playlists with an explicit sort order.
class PlaylistSongsTable extends Table {
  @override
  String get tableName => 'playlist_songs';

  IntColumn get playlistId =>
      integer().named('playlist_id').references(PlaylistsTable, #id)();
  TextColumn get songId => text().named('song_id')();
  TextColumn get source => text()();

  /// 0-based manual sort position within the playlist.
  IntColumn get sortOrder => integer().named('sort_order')();

  /// Unix milliseconds when this song was added to the playlist.
  IntColumn get addedAt => integer().named('added_at')();

  @override
  Set<Column> get primaryKey => {playlistId, songId, source};
}
