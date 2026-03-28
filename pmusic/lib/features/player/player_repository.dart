import 'dart:io';

import '../../core/api/app_error.dart';
import '../../core/api/music_api_client.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/cache_dao.dart';
import '../../core/db/daos/play_queue_dao.dart';
import '../../core/models/enums.dart';
import '../../core/models/song.dart';

// ─── Repository interface ────────────────────────────────────────────────────

abstract class PlayerRepository {
  /// Returns the local cache path for [songId]+[source], or `null` if not cached.
  Future<String?> getLocalPath(String songId, String source);

  /// Resolves the remote streaming URL via the API.
  Future<String> getPlayUrl(
    String songId,
    String source,
    AudioQuality quality,
  );

  /// Persists the play queue so it can survive app restarts.
  Future<void> saveQueue(List<Song> queue, int currentIndex);

  /// Loads the last-saved queue. Returns an empty queue on first run.
  Future<({List<Song> queue, int index})> loadQueue();
}

// ─── Drift implementation ────────────────────────────────────────────────────

class DriftPlayerRepository implements PlayerRepository {
  DriftPlayerRepository({
    required AppDatabase db,
    required MusicApiClient apiClient,
  })  : _dao = db.playQueueDao,
        _cacheDao = db.cacheDao,
        _api = apiClient;

  final PlayQueueDao _dao;
  final CacheDao _cacheDao;
  final MusicApiClient _api;
  int _savedIndex = 0;

  @override
  Future<String?> getLocalPath(String songId, String source) async {
    final entry = await _cacheDao.getEntry(songId, source);
    if (entry == null) return null;

    // Verify the file still exists on disk.
    if (!await File(entry.filePath).exists()) {
      await _cacheDao.remove(entry.filePath);
      return null;
    }

    // Touch lastAccessed so LRU ordering stays accurate.
    await _cacheDao.upsert(
      entry.copyWith(lastAccessed: DateTime.now().millisecondsSinceEpoch),
    );

    return entry.filePath;
  }

  @override
  Future<String> getPlayUrl(
    String songId,
    String source,
    AudioQuality quality,
  ) async {
    final dto = await _api.getSongUrl(
      source: source,
      id: songId,
      quality: quality.bitrate.toString(),
    );
    if (dto.url.isEmpty) {
      throw const NotFoundError(resource: '播放地址');
    }
    return dto.url;
  }

  @override
  Future<void> saveQueue(List<Song> queue, int currentIndex) async {
    _savedIndex = currentIndex;
    await _dao.replaceQueue(queue);
  }

  @override
  Future<({List<Song> queue, int index})> loadQueue() async {
    final queue = await _dao.getQueue();
    final idx = _savedIndex.clamp(0, queue.isEmpty ? 0 : queue.length - 1);
    return (queue: queue, index: idx);
  }
}

// ─── Stub fallback ────────────────────────────────────────────────────────────

class StubPlayerRepository implements PlayerRepository {
  @override
  Future<String?> getLocalPath(String songId, String source) async => null;

  @override
  Future<String> getPlayUrl(
    String songId,
    String source,
    AudioQuality quality,
  ) async {
    throw UnimplementedError('getPlayUrl not yet implemented');
  }

  @override
  Future<void> saveQueue(List<Song> queue, int currentIndex) async {}

  @override
  Future<({List<Song> queue, int index})> loadQueue() async =>
      (queue: const <Song>[], index: 0);
}
