import '../../core/models/song.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class HistoryEntry {
  const HistoryEntry({
    required this.song,
    required this.playedAt,
    this.playCount = 1,
  });

  final Song song;

  /// Unix milliseconds of the most-recent play.
  final int playedAt;
  final int playCount;

  HistoryEntry copyWith({Song? song, int? playedAt, int? playCount}) {
    return HistoryEntry(
      song: song ?? this.song,
      playedAt: playedAt ?? this.playedAt,
      playCount: playCount ?? this.playCount,
    );
  }
}

/// A date-labelled group of [HistoryEntry] items for section display.
class HistoryGroup {
  const HistoryGroup({required this.label, required this.entries});

  /// Human-readable label: "今天" / "昨天" / "更早".
  final String label;
  final List<HistoryEntry> entries;
}

// ─── Repository interface ────────────────────────────────────────────────────

abstract class HistoryRepository {
  Future<List<HistoryEntry>> getAll();
  Future<void> addEntry(Song song);
  Future<void> clear();
}

// ─── Stub ─────────────────────────────────────────────────────────────────────

class InMemoryHistoryRepository implements HistoryRepository {
  // Key: "${songId}_${source}"
  final Map<String, HistoryEntry> _map = {};

  @override
  Future<List<HistoryEntry>> getAll() async {
    final list = _map.values.toList();
    list.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return list;
  }

  @override
  Future<void> addEntry(Song song) async {
    final key = '${song.id}_${song.source.param}';
    final existing = _map[key];
    _map[key] = HistoryEntry(
      song: song,
      playedAt: DateTime.now().millisecondsSinceEpoch,
      playCount: (existing?.playCount ?? 0) + 1,
    );
  }

  @override
  Future<void> clear() async => _map.clear();
}
