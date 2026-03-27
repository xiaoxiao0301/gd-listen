import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/play_queue_table.dart';
import '../tables/songs_table.dart';
import '../../models/song.dart';
import '../../models/enums.dart';
import 'dart:convert';

part 'play_queue_dao.g.dart';

@DriftAccessor(tables: [PlayQueueTable, SongsTable])
class PlayQueueDao extends DatabaseAccessor<AppDatabase>
    with _$PlayQueueDaoMixin {
  PlayQueueDao(super.db);

  /// Returns the full queue in position order, with joined song data.
  Future<List<Song>> getQueue() async {
    // Load queue positions.
    final queueRows = await (select(playQueueTable)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    if (queueRows.isEmpty) return const [];

    // Load corresponding songs.
    final results = <Song>[];
    for (final qr in queueRows) {
      final songQuery = select(songsTable)
        ..where((t) =>
            t.id.equals(qr.songId) & t.source.equals(qr.source));
      final row = await songQuery.getSingleOrNull();
      if (row != null) results.add(_rowToSong(row));
    }
    return results;
  }

  /// Replaces the entire queue with [songs].
  Future<void> replaceQueue(List<Song> songs) async {
    await transaction(() async {
      await delete(playQueueTable).go();
      if (songs.isEmpty) return;

      // Upsert all referenced songs first so the join works.
      await batch((b) {
        for (final song in songs) {
          b.insertAllOnConflictUpdate(songsTable, [
            SongsTableCompanion(
              id: Value(song.id),
              source: Value(song.source.param),
              name: Value(song.name),
              artist: Value(jsonEncode(song.artists)),
              album: Value(song.album),
              picId: Value(song.picId),
              lyricId: Value(song.lyricId),
            ),
          ]);
        }
      });

      // Insert queue rows.
      await batch((b) {
        for (var i = 0; i < songs.length; i++) {
          b.insert(
            playQueueTable,
            PlayQueueTableCompanion(
              position: Value(i),
              songId: Value(songs[i].id),
              source: Value(songs[i].source.param),
            ),
          );
        }
      });
    });
  }

  /// Removes a single entry at [position].
  Future<void> removeAt(int position) async {
    await (delete(playQueueTable)
          ..where((t) => t.position.equals(position)))
        .go();
  }

  /// Clears the entire queue.
  Future<void> clear() async => delete(playQueueTable).go();

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
