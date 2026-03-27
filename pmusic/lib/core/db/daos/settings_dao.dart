import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/settings_table.dart';
import '../../models/enums.dart';
import '../../models/app_settings.dart';

part 'settings_dao.g.dart';

// ─── Setting key constants ────────────────────────────────────────────────────

abstract class SettingKeys {
  static const defaultSource = 'default_source';
  static const audioQuality = 'audio_quality';
  static const cacheMaxMb = 'cache_max_mb';
  static const playMode = 'play_mode';
  static const lyricTranslation = 'lyric_translation';
  static const offlineMode = 'offline_mode';
  static const searchHistory = 'search_history';
}

@DriftAccessor(tables: [SettingsTable])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  // ── Raw key-value access ──────────────────────────────────────────────────

  Future<String?> get(String key) async {
    final query = select(settingsTable)
      ..where((t) => t.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await into(settingsTable).insertOnConflictUpdate(
      SettingsTableCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  Future<void> remove(String key) async {
    await (delete(settingsTable)..where((t) => t.key.equals(key))).go();
  }

  // ── Typed AppSettings load / save ─────────────────────────────────────────

  Future<AppSettings> loadSettings() async {
    final rows = await select(settingsTable).get();
    final map = {for (final r in rows) r.key: r.value};

    return AppSettings(
      defaultSource: MusicSource.values.firstWhere(
        (s) => s.param == map[SettingKeys.defaultSource],
        orElse: () => MusicSource.netease,
      ),
      audioQuality: AudioQuality.values.firstWhere(
        (q) => q.name == map[SettingKeys.audioQuality],
        orElse: () => AudioQuality.q320,
      ),
      cacheMaxMb:
          int.tryParse(map[SettingKeys.cacheMaxMb] ?? '') ?? 512,
      playMode: PlayMode.values.firstWhere(
        (m) => m.name == map[SettingKeys.playMode],
        orElse: () => PlayMode.sequence,
      ),
      lyricTranslation:
          (map[SettingKeys.lyricTranslation] ?? 'true') == 'true',
      offlineMode: (map[SettingKeys.offlineMode] ?? 'false') == 'true',
    );
  }

  Future<void> saveSettings(AppSettings s) async {
    await batch((b) {
      final pairs = {
        SettingKeys.defaultSource: s.defaultSource.param,
        SettingKeys.audioQuality: s.audioQuality.name,
        SettingKeys.cacheMaxMb: s.cacheMaxMb.toString(),
        SettingKeys.playMode: s.playMode.name,
        SettingKeys.lyricTranslation: s.lyricTranslation.toString(),
        SettingKeys.offlineMode: s.offlineMode.toString(),
      };
      for (final e in pairs.entries) {
        b.insertAllOnConflictUpdate(
          settingsTable,
          [
            SettingsTableCompanion(
              key: Value(e.key),
              value: Value(e.value),
            ),
          ],
        );
      }
    });
  }
}
