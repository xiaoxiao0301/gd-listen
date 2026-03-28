import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/api/app_error.dart';
import '../../core/api/models/song_dto.dart';
import '../../core/api/music_api_client.dart';
import '../../core/db/daos/settings_dao.dart';
import '../../core/db/daos/songs_dao.dart';
import '../../core/models/song.dart';
import '../../core/models/enums.dart';

// ─── Repository interface ────────────────────────────────────────────────────

abstract class SearchRepository {
  Future<List<Song>> search({
    required MusicSource source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
    bool albumMode = false,
  });

  Future<List<String>> loadHistory();
  Future<void> addHistory(String keyword);

  /// Remove a single [keyword] from history.
  Future<void> removeHistory(String keyword);

  Future<void> clearHistory();
}

// ─── API + Drift implementation ──────────────────────────────────────────────

class ApiSearchRepository implements SearchRepository {
  ApiSearchRepository({
    required MusicApiClient apiClient,
    required SettingsDao settingsDao,
    required SongsDao songsDao,
  })  : _api = apiClient,
        _settings = settingsDao,
        _songs = songsDao;

  final MusicApiClient _api;
  final SettingsDao _settings;
  final SongsDao _songs;

  static const _historyKey = 'search_history';
  static const _maxHistory = 20;

  @override
  Future<List<Song>> search({
    required MusicSource source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
    bool albumMode = false,
  }) async {
    // Offline guard — throw immediately, don't attempt network call.
    final offlineRaw = await _settings.get(SettingKeys.offlineMode);
    if (offlineRaw == 'true') throw const OfflineError();

    try {
      final dtos = await _api.searchSongs(
        source: source.param,
        keyword: keyword,
        page: page,
        pageSize: pageSize,
        albumMode: albumMode,
      );
      final songs = dtos.map((dto) => dto.toDomain()).toList();
      // Cache search results locally for offline access.
      await _songs.upsertAll(songs);
      return songs;
    } on DioException catch (e) {
      // ErrorInterceptor attaches a typed AppError to DioException.error.
      if (e.error is AppError) throw e.error! as AppError;
      throw NetworkError(e.message ?? '搜索失败，请稍后再试');
    }
  }

  @override
  Future<List<String>> loadHistory() async {
    final raw = await _settings.get(_historyKey);
    if (raw == null || raw.isEmpty || raw == '[]') return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<String>();
  }

  @override
  Future<void> addHistory(String keyword) async {
    final current = await loadHistory();
    final updated = [
      keyword,
      ...current.where((k) => k != keyword),
    ];
    if (updated.length > _maxHistory) updated.removeLast();
    await _settings.set(_historyKey, jsonEncode(updated));
  }

  @override
  Future<void> removeHistory(String keyword) async {
    final current = await loadHistory();
    final updated = current.where((k) => k != keyword).toList();
    await _settings.set(_historyKey, jsonEncode(updated));
  }

  @override
  Future<void> clearHistory() async {
    await _settings.set(_historyKey, '[]');
  }
}

// ─── In-memory fallback ───────────────────────────────────────────────────────

class StubSearchRepository implements SearchRepository {
  final List<String> _history = [];

  @override
  Future<List<Song>> search({
    required MusicSource source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
    bool albumMode = false,
  }) async =>
      const [];

  @override
  Future<List<String>> loadHistory() async => List.unmodifiable(_history);

  @override
  Future<void> addHistory(String keyword) async {
    _history
      ..remove(keyword)
      ..insert(0, keyword);
    if (_history.length > 20) _history.removeLast();
  }

  @override
  Future<void> removeHistory(String keyword) async {
    _history.remove(keyword);
  }

  @override
  Future<void> clearHistory() async => _history.clear();
}

// ─── DTO → domain mapper ──────────────────────────────────────────────────────

extension SongDtoMapper on SongDto {
  Song toDomain() => Song(
        id: id,
        source: MusicSource.values.firstWhere(
          (s) => s.param == source,
          orElse: () => MusicSource.netease,
        ),
        name: name,
        artists: artist,
        album: album,
        picId: picId,
        lyricId: lyricId,
      );
}
