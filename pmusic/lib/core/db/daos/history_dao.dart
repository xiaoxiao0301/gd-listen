import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/play_history_table.dart';
import '../tables/songs_table.dart';
import '../../models/song.dart';
import '../../models/enums.dart';

part 'history_dao.g.dart';

@DriftAccessor(tables: [PlayHistoryTable, SongsTable])
class HistoryDao extends DatabaseAccessor<AppDatabase>
    with _$HistoryDaoMixin {
  HistoryDao(super.db);

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Live stream of all history entries ordered by most-recently played first.
  Stream<List<({Song song, int playedAt, int playCount})>> watchAll() {
    final query = select(playHistoryTable).join([
      innerJoin(
        songsTable,
        songsTable.id.equalsExp(playHistoryTable.songId) &
            songsTable.source.equalsExp(playHistoryTable.source),
      ),
    ])
      ..orderBy([OrderingTerm.desc(playHistoryTable.playedAt)]);

    return query.watch().map((rows) => rows.map((r) {
      final h = r.readTable(playHistoryTable);
      return (
        song: _rowToSong(r.readTable(songsTable)),
        playedAt: h.playedAt,
        playCount: h.playCount,
      );
    }).toList());
  }

  /// All history entries ordered by most-recently played first.
  Future<List<({Song song, int playedAt, int playCount})>> getAll() async {
    final query = select(playHistoryTable).join([
      innerJoin(
        songsTable,
        songsTable.id.equalsExp(playHistoryTable.songId) &
            songsTable.source.equalsExp(playHistoryTable.source),
      ),
    ])
      ..orderBy([OrderingTerm.desc(playHistoryTable.playedAt)]);

    final rows = await query.get();
    return rows.map((r) {
      final h = r.readTable(playHistoryTable);
      return (
        song: _rowToSong(r.readTable(songsTable)),
        playedAt: h.playedAt,
        playCount: h.playCount,
      );
    }).toList();
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Records a play event.  If the song was played before, updates
  /// [playedAt] and increments [playCount]; otherwise inserts a new row.
  Future<void> upsert(Song song) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await transaction(() async {
      // Ensure song metadata is persisted.
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

      // Check if a row already exists.
      final existing = await (select(playHistoryTable)
            ..where(
              (t) =>
                  t.songId.equals(song.id) &
                  t.source.equals(song.source.param),
            ))
          .getSingleOrNull();

      if (existing == null) {
        await into(playHistoryTable).insert(
          PlayHistoryTableCompanion(
            songId: Value(song.id),
            source: Value(song.source.param),
            playedAt: Value(now),
            playCount: const Value(1),
          ),
        );
      } else {
        await (update(playHistoryTable)
              ..where(
                (t) =>
                    t.songId.equals(song.id) &
                    t.source.equals(song.source.param),
              ))
            .write(
          PlayHistoryTableCompanion(
            playedAt: Value(now),
            playCount: Value(existing.playCount + 1),
          ),
        );
      }
    });
  }

  Future<void> clear() async => delete(playHistoryTable).go();

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
