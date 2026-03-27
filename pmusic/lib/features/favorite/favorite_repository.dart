import '../../core/models/song.dart';

// ─── Repository interface ────────────────────────────────────────────────────

abstract class FavoriteRepository {
  Future<List<Song>> getAll();
  Future<bool> isFavorite(String songId, String source);
  Future<void> add(Song song);
  Future<void> remove(String songId, String source);
}

// ─── Stub ─────────────────────────────────────────────────────────────────────

class InMemoryFavoriteRepository implements FavoriteRepository {
  // Key: "${songId}_${source}"
  final Map<String, Song> _map = {};

  String _key(String id, String source) => '${id}_$source';

  @override
  Future<List<Song>> getAll() async =>
      _map.values.toList().reversed.toList();

  @override
  Future<bool> isFavorite(String songId, String source) async =>
      _map.containsKey(_key(songId, source));

  @override
  Future<void> add(Song song) async {
    _map[_key(song.id, song.source.param)] = song;
  }

  @override
  Future<void> remove(String songId, String source) async {
    _map.remove(_key(songId, source));
  }
}
