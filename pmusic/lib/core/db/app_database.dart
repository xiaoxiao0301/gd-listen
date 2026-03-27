import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/songs_table.dart';
import 'tables/settings_table.dart';
import 'tables/play_queue_table.dart';
import 'daos/songs_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/play_queue_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [SongsTable, SettingsTable, PlayQueueTable],
  daos: [SongsDao, SettingsDao, PlayQueueDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
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

