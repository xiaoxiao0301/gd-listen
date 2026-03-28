import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/playlists_table.dart';
import '../tables/playlist_songs_table.dart';
import '../tables/songs_table.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../models/enums.dart';

part 'playlists_dao.g.dart';

@DriftAccessor(tables: [PlaylistsTable, PlaylistSongsTable, SongsTable])
class PlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistsDaoMixin {
  PlaylistsDao(super.db);

  // ── Playlist queries ──────────────────────────────────────────────────────

  /// Returns all playlists ordered by most-recently updated first.
  Future<List<Playlist>> getAll() async {
    // Load playlists.
    final rows = await (select(playlistsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();

    // Load song counts separately.
    final playlists = <Playlist>[];
    for (final row in rows) {
      final count = await (select(playlistSongsTable)
            ..where((t) => t.playlistId.equals(row.id)))
          .get();
      playlists.add(Playlist(
        id: row.id,
        name: row.name,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        songCount: count.length,
      ));
    }
    return playlists;
  }

  /// Stream of all playlists — emits on any change.
  Stream<List<Playlist>> watchAll() {
    return (select(playlistsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch()
        .asyncMap((rows) async {
      final playlists = <Playlist>[];
      for (final row in rows) {
        final count = await (select(playlistSongsTable)
              ..where((t) => t.playlistId.equals(row.id)))
            .get();
        playlists.add(Playlist(
          id: row.id,
          name: row.name,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          songCount: count.length,
        ));
      }
      return playlists;
    });
  }

  // ── Playlist writes ───────────────────────────────────────────────────────

  Future<Playlist> create(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await into(playlistsTable).insert(
      PlaylistsTableCompanion(
        name: Value(name),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return Playlist(id: id, name: name, createdAt: now, updatedAt: now);
  }

  Future<void> rename(int id, String newName) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(playlistsTable)..where((t) => t.id.equals(id))).write(
      PlaylistsTableCompanion(
        name: Value(newName),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deletePlaylist(int id) async {
    await transaction(() async {
      await (delete(playlistSongsTable)
            ..where((t) => t.playlistId.equals(id)))
          .go();
      await (delete(playlistsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── Song queries ──────────────────────────────────────────────────────────

  /// Songs in a playlist ordered by [sortOrder].
  Future<List<Song>> getSongs(int playlistId) async {
    final query = select(playlistSongsTable).join([
      innerJoin(
        songsTable,
        songsTable.id.equalsExp(playlistSongsTable.songId) &
            songsTable.source.equalsExp(playlistSongsTable.source),
      ),
    ])
      ..where(playlistSongsTable.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistSongsTable.sortOrder)]);

    final rows = await query.get();
    return rows
        .map((r) => _rowToSong(r.readTable(songsTable)))
        .toList();
  }

  // ── Song writes ───────────────────────────────────────────────────────────

  Future<void> addSong(int playlistId, Song song) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await transaction(() async {
      // Persist song metadata.
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

      // Determine next sort order.
      final existing = await (select(playlistSongsTable)
            ..where((t) => t.playlistId.equals(playlistId))
            ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
            ..limit(1))
          .getSingleOrNull();
      final nextOrder = existing == null ? 0 : existing.sortOrder + 1;

      await into(playlistSongsTable).insertOnConflictUpdate(
        PlaylistSongsTableCompanion(
          playlistId: Value(playlistId),
          songId: Value(song.id),
          source: Value(song.source.param),
          sortOrder: Value(nextOrder),
          addedAt: Value(now),
        ),
      );

      // Touch updatedAt on the playlist.
      await (update(playlistsTable)
            ..where((t) => t.id.equals(playlistId)))
          .write(PlaylistsTableCompanion(
        updatedAt: Value(now),
      ));
    });
  }

  Future<void> removeSong(
      int playlistId, String songId, String source) async {
    await transaction(() async {
      await (delete(playlistSongsTable)
            ..where(
              (t) =>
                  t.playlistId.equals(playlistId) &
                  t.songId.equals(songId) &
                  t.source.equals(source),
            ))
          .go();

      final now = DateTime.now().millisecondsSinceEpoch;
      await (update(playlistsTable)
            ..where((t) => t.id.equals(playlistId)))
          .write(PlaylistsTableCompanion(updatedAt: Value(now)));
    });
  }

  /// Swaps sort orders so that the song at [oldIndex] moves to [newIndex].
  Future<void> reorderSongs(
      int playlistId, int oldIndex, int newIndex) async {
    final songs = await getSongs(playlistId);
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= songs.length ||
        newIndex >= songs.length) {
      return;
    }

    final song = songs.removeAt(oldIndex);
    songs.insert(newIndex, song);

    await transaction(() async {
      for (var i = 0; i < songs.length; i++) {
        await (update(playlistSongsTable)
              ..where(
                (t) =>
                    t.playlistId.equals(playlistId) &
                    t.songId.equals(songs[i].id) &
                    t.source.equals(songs[i].source.param),
              ))
            .write(PlaylistSongsTableCompanion(sortOrder: Value(i)));
      }
    });
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
