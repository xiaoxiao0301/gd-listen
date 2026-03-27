import '../../core/db/app_database.dart';
import '../../core/db/daos/settings_dao.dart';
import '../../core/models/app_settings.dart';

export '../../core/models/app_settings.dart';

// ─── Repository interface ────────────────────────────────────────────────────

abstract class SettingsRepository {
  Future<AppSettings> loadSettings();
  Future<void> setSetting(String key, String value);
  Future<void> saveSettings(AppSettings settings);
}

// ─── Drift implementation ────────────────────────────────────────────────────

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(AppDatabase db) : _dao = db.settingsDao;

  final SettingsDao _dao;

  @override
  Future<AppSettings> loadSettings() => _dao.loadSettings();

  @override
  Future<void> setSetting(String key, String value) => _dao.set(key, value);

  @override
  Future<void> saveSettings(AppSettings settings) =>
      _dao.saveSettings(settings);
}

// ─── In-memory fallback (used in tests / before DB is ready) ─────────────────

class InMemorySettingsRepository implements SettingsRepository {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}
