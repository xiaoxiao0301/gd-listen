import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/api/app_error.dart';
import '../../core/api/models/song_dto.dart';
import '../../core/api/music_api_client.dart';
import '../../core/db/daos/settings_dao.dart';
import '../../core/models/song.dart';
import '../../core/models/enums.dart';

// ─── Repository interface ────────────────────────────────────────────────────

abstract class SearchRepository {
  Future<List<Song>> search({
    required MusicSource source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
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
  })  : _api = apiClient,
        _settings = settingsDao;

  final MusicApiClient _api;
  final SettingsDao _settings;

  static const _historyKey = 'search_history';
  static const _maxHistory = 20;

  @override
  Future<List<Song>> search({
    required MusicSource source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final dtos = await _api.searchSongs(
        source: source.param,
        keyword: keyword,
        page: page,
        pageSize: pageSize,
      );
      return dtos.map((dto) => dto.toDomain()).toList();
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
