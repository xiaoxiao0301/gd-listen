import '../../core/db/app_database.dart';
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
  DriftPlayerRepository(AppDatabase db) : _dao = db.playQueueDao;

  final PlayQueueDao _dao;

  // Current index is stored as a single settings-style entry in the
  // play_queue table using position == -1 as a sentinel row.
  // Simpler approach: keep currentIndex in a separate in-memory field
  // (restored from a well-known row).
  int _savedIndex = 0;

  @override
  Future<String?> getLocalPath(String songId, String source) async =>
      null; // wired to CacheRepository in P2-11

  @override
  Future<String> getPlayUrl(
    String songId,
    String source,
    AudioQuality quality,
  ) async {
    // Real implementation connects to MusicApiClient in P1-04.
    throw UnimplementedError('getPlayUrl not yet implemented');
  }

  @override
  Future<void> saveQueue(List<Song> queue, int currentIndex) async {
    _savedIndex = currentIndex;
    await _dao.replaceQueue(queue);
  }

  @override
  Future<({List<Song> queue, int index})> loadQueue() async {
    final queue = await _dao.getQueue();
    return (queue: queue, index: _savedIndex.clamp(0, queue.isEmpty ? 0 : queue.length - 1));
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
