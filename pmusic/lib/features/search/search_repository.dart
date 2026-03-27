import '../../core/api/models/song_dto.dart';
import '../../core/models/song.dart';
import '../../core/models/enums.dart';

// ─── Repository interface ────────────────────────────────────────────────────

abstract class SearchRepository {
  /// Issue a keyword search against the given [source].
  Future<List<Song>> search({
    required MusicSource source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  });

  /// Return locally-saved search history keywords (most recent first).
  Future<List<String>> loadHistory();

  /// Persist a keyword to the local search history.
  Future<void> addHistory(String keyword);

  /// Clear the entire search history.
  Future<void> clearHistory();
}

// ─── Stub (replaced in P1-04 / P1-03) ────────────────────────────────────────

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
    if (_history.length > 50) _history.removeLast();
  }

  @override
  Future<void> clearHistory() async => _history.clear();
}

// ─── DTO → domain mapper helper ───────────────────────────────────────────────

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
