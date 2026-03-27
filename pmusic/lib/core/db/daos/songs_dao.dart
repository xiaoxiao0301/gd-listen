import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/songs_table.dart';
import '../../models/song.dart';
import '../../models/enums.dart';

part 'songs_dao.g.dart';

@DriftAccessor(tables: [SongsTable])
class SongsDao extends DatabaseAccessor<AppDatabase> with _$SongsDaoMixin {
  SongsDao(super.db);

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<Song>> getAll() async {
    final rows = await select(songsTable).get();
    return rows.map(_rowToSong).toList();
  }

  Future<Song?> getById(String id, String source) async {
    final query = select(songsTable)
      ..where((t) => t.id.equals(id) & t.source.equals(source));
    final row = await query.getSingleOrNull();
    return row != null ? _rowToSong(row) : null;
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> upsert(Song song) async {
    await into(songsTable).insertOnConflictUpdate(
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
  }

  Future<void> upsertAll(List<Song> songs) async {
    await batch((b) {
      for (final song in songs) {
        b.insertAllOnConflictUpdate(
          songsTable,
          [
            SongsTableCompanion(
              id: Value(song.id),
              source: Value(song.source.param),
              name: Value(song.name),
              artist: Value(jsonEncode(song.artists)),
              album: Value(song.album),
              picId: Value(song.picId),
              lyricId: Value(song.lyricId),
            ),
          ],
        );
      }
    });
  }

  Future<void> deleteById(String id, String source) async {
    await (delete(songsTable)
          ..where((t) => t.id.equals(id) & t.source.equals(source)))
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
