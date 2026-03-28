import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/songs_table.dart';
import 'tables/settings_table.dart';
import 'tables/play_queue_table.dart';
import 'tables/playlists_table.dart';
import 'tables/playlist_songs_table.dart';
import 'tables/favorites_table.dart';
import 'tables/play_history_table.dart';
import 'tables/cache_entries_table.dart';
import 'daos/songs_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/play_queue_dao.dart';
import 'daos/playlists_dao.dart';
import 'daos/favorites_dao.dart';
import 'daos/history_dao.dart';
import 'daos/cache_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    SongsTable,
    SettingsTable,
    PlayQueueTable,
    PlaylistsTable,
    PlaylistSongsTable,
    FavoritesTable,
    PlayHistoryTable,
    CacheEntriesTable,
  ],
  daos: [
    SongsDao,
    SettingsDao,
    PlayQueueDao,
    PlaylistsDao,
    FavoritesDao,
    HistoryDao,
    CacheDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Schema v2: add playlists, playlist_songs, favorites,
            // play_history, cache_entries tables.
            await m.createTable(playlistsTable);
            await m.createTable(playlistSongsTable);
            await m.createTable(favoritesTable);
            await m.createTable(playHistoryTable);
            await m.createTable(cacheEntriesTable);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pmusic.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

