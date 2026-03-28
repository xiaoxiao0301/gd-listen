import '../../core/db/app_database.dart';
import '../../core/db/daos/favorites_dao.dart';
import '../../core/models/song.dart';

// ─── Repository interface ────────────────────────────────────────────────────

abstract class FavoriteRepository {
  Future<List<Song>> getAll();
  Stream<List<Song>> watchAll();
  Future<bool> isFavorite(String songId, String source);
  Future<void> add(Song song);
  Future<void> remove(String songId, String source);
}

// ─── Drift implementation ─────────────────────────────────────────────────────

class DriftFavoriteRepository implements FavoriteRepository {
  DriftFavoriteRepository(AppDatabase db) : _dao = db.favoritesDao;

  final FavoritesDao _dao;

  @override
  Future<List<Song>> getAll() => _dao.getAll();

  @override
  Stream<List<Song>> watchAll() => _dao.watchAll();

  @override
  Future<bool> isFavorite(String songId, String source) =>
      _dao.isFavorite(songId, source);

  @override
  Future<void> add(Song song) => _dao.add(song);

  @override
  Future<void> remove(String songId, String source) =>
      _dao.remove(songId, source);
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
  Stream<List<Song>> watchAll() =>
      Stream.fromFuture(getAll());

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
