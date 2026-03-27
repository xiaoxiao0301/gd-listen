import '../../core/models/playlist.dart';
import '../../core/models/song.dart';

// ─── Repository interface ────────────────────────────────────────────────────

abstract class PlaylistRepository {
  Future<List<Playlist>> getAll();
  Future<Playlist> create(String name);
  Future<void> rename(int id, String newName);
  Future<void> delete(int id);
  Future<List<Song>> getSongs(int playlistId);
  Future<void> addSong(int playlistId, Song song);
  Future<void> removeSong(int playlistId, String songId);
  Future<void> reorderSongs(int playlistId, int oldIndex, int newIndex);
}

// ─── Stub ─────────────────────────────────────────────────────────────────────

class InMemoryPlaylistRepository implements PlaylistRepository {
  final Map<int, Playlist> _playlists = {};
  final Map<int, List<Song>> _songs = {};
  int _nextId = 1;

  @override
  Future<List<Playlist>> getAll() async =>
      _playlists.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Playlist> create(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = Playlist(id: _nextId++, name: name, createdAt: now, updatedAt: now);
    _playlists[p.id] = p;
    _songs[p.id] = [];
    return p;
  }

  @override
  Future<void> rename(int id, String newName) async {
    final p = _playlists[id];
    if (p == null) return;
    _playlists[id] = p.copyWith(
      name: newName,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> delete(int id) async {
    _playlists.remove(id);
    _songs.remove(id);
  }

  @override
  Future<List<Song>> getSongs(int playlistId) async =>
      List.unmodifiable(_songs[playlistId] ?? []);

  @override
  Future<void> addSong(int playlistId, Song song) async {
    _songs[playlistId]?.add(song);
    _playlists[playlistId] = _playlists[playlistId]?.copyWith(
      songCount: (_songs[playlistId]?.length ?? 0),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ) ?? _playlists[playlistId]!;
  }

  @override
  Future<void> removeSong(int playlistId, String songId) async {
    _songs[playlistId]?.removeWhere((s) => s.id == songId);
  }

  @override
  Future<void> reorderSongs(
    int playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final list = _songs[playlistId];
    if (list == null) return;
    final song = list.removeAt(oldIndex);
    list.insert(newIndex, song);
  }
}
