import 'package:drift/drift.dart';

/// Key-value settings store.
///
/// Keys are defined in the design doc (default_source, audio_quality, etc.)
class SettingsTable extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
