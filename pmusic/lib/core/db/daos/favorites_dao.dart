import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/favorites_table.dart';
import '../tables/songs_table.dart';
import '../../models/song.dart';
import '../../models/enums.dart';

part 'favorites_dao.g.dart';

@DriftAccessor(tables: [FavoritesTable, SongsTable])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  FavoritesDao(super.db);

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Returns all favourites ordered by most-recently added first.
  Future<List<Song>> getAll() async {
    final query = select(favoritesTable).join([
      innerJoin(
        songsTable,
        songsTable.id.equalsExp(favoritesTable.songId) &
            songsTable.source.equalsExp(favoritesTable.source),
      ),
    ])
      ..orderBy([OrderingTerm.desc(favoritesTable.addedAt)]);

    final rows = await query.get();
    return rows.map((r) => _rowToSong(r.readTable(songsTable))).toList();
  }

  /// Stream of all favourites — emits whenever the table changes.
  Stream<List<Song>> watchAll() {
    final query = select(favoritesTable).join([
      innerJoin(
        songsTable,
        songsTable.id.equalsExp(favoritesTable.songId) &
            songsTable.source.equalsExp(favoritesTable.source),
      ),
    ])
      ..orderBy([OrderingTerm.desc(favoritesTable.addedAt)]);

    return query.watch().map(
          (rows) =>
              rows.map((r) => _rowToSong(r.readTable(songsTable))).toList(),
        );
  }

  Future<bool> isFavorite(String songId, String source) async {
    final query = select(favoritesTable)
      ..where(
          (t) => t.songId.equals(songId) & t.source.equals(source))
      ..limit(1);
    return (await query.getSingleOrNull()) != null;
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> add(Song song) async {
    await transaction(() async {
      // Upsert the song metadata first.
      await (db.into(songsTable)).insertOnConflictUpdate(
        SongsTableCompanion(
          id: Value(song.id),
          source: Value(song.source.param),
          name: Value(song.name),
          artist: Value(jsonEncode(song.artists)),
          album: Value(song.album),
          picId: Value(song.picId),
          lyricId: Value(song.lyricId),
        ),
      );
      // Insert favourite row (or update addedAt on conflict).
      await into(favoritesTable).insertOnConflictUpdate(
        FavoritesTableCompanion(
          songId: Value(song.id),
          source: Value(song.source.param),
          addedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
  }

  Future<void> remove(String songId, String source) async {
    await (delete(favoritesTable)
          ..where(
              (t) => t.songId.equals(songId) & t.source.equals(source)))
        .go();
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  Song _rowToSong(SongsTableData row) {
    final List<dynamic> rawArtists =
        jsonDecode(row.artist) as List<dynamic>;
    return Song(
      id: row.id,
      source: MusicSource.values.firstWhere(
        (s) => s.param == row.source,
        orElse: () => MusicSource.netease,
      ),
      name: row.name,
      artists: rawArtists.cast<String>(),
      album: row.album,
      picId: row.picId,
      lyricId: row.lyricId,
    );
  }
}
