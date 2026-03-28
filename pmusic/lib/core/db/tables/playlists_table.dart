import 'package:drift/drift.dart';

/// User-created playlists.
class PlaylistsTable extends Table {
  @override
  String get tableName => 'playlists';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Creation timestamp as Unix milliseconds.
  IntColumn get createdAt => integer().named('created_at')();

  /// Last-modified timestamp as Unix milliseconds.
  IntColumn get updatedAt => integer().named('updated_at')();
}
