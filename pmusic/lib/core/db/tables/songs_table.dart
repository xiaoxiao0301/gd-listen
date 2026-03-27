import 'package:drift/drift.dart';

/// Drift table definition for cached song metadata.
///
/// Mirrors the SQL schema from the design doc:
///   id + source form the composite primary key.
class SongsTable extends Table {
  @override
  String get tableName => 'songs';

  TextColumn get id => text()();
  TextColumn get source => text()();

  /// Song title.
  TextColumn get name => text()();

  /// JSON-encoded array of artist name strings, e.g. '["周杰伦"]'.
  TextColumn get artist => text()();

  TextColumn get album => text()();
  TextColumn get picId => text().named('pic_id')();
  TextColumn get lyricId => text().named('lyric_id')();

  @override
  Set<Column> get primaryKey => {id, source};
}
