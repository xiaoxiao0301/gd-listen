import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'settings_repository.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return DriftSettingsRepository(db);
});

final settingsNotifierProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  late SettingsRepository _repo;

  @override
  Future<AppSettings> build() async {
    _repo = ref.read(settingsRepositoryProvider);
    return _repo.loadSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _repo.saveSettings(settings);
    state = AsyncValue.data(settings);
  }
}
