import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import 'playlist_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class PlaylistState {
  const PlaylistState({
    this.playlists = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Playlist> playlists;
  final bool isLoading;
  final String? errorMessage;

  PlaylistState copyWith({
    List<Playlist>? playlists,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlaylistState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return DriftPlaylistRepository(db);
});

final playlistNotifierProvider =
    AsyncNotifierProvider<PlaylistNotifier, PlaylistState>(
  PlaylistNotifier.new,
);

/// Returns the first song in a playlist for cover-art display.
/// Automatically disposed when all listeners detach.
final playlistFirstSongProvider =
    FutureProvider.autoDispose.family<Song?, int>((ref, playlistId) async {
  final songs =
      await ref.read(playlistRepositoryProvider).getSongs(playlistId);
  return songs.isNotEmpty ? songs.first : null;
});

/// Returns all songs in a playlist.
/// Automatically disposed when all listeners detach.
/// Invalidate with `ref.invalidate(playlistSongsProvider(playlistId))` after
/// mutations (remove / reorder) to trigger a fresh fetch.
final playlistSongsProvider =
    FutureProvider.autoDispose.family<List<Song>, int>((ref, playlistId) async {
  return ref.read(playlistRepositoryProvider).getSongs(playlistId);
});

// ─── Notifier ────────────────────────────────────────────────────────────────

class PlaylistNotifier extends AsyncNotifier<PlaylistState> {
  late PlaylistRepository _repo;

  @override
  Future<PlaylistState> build() async {
    _repo = ref.read(playlistRepositoryProvider);
    final playlists = await _repo.getAll();
    return PlaylistState(playlists: playlists);
  }

  Future<void> create(String name) async {
    await _repo.create(name);
    final playlists = await _repo.getAll();
    state = AsyncValue.data(
      state.valueOrNull?.copyWith(playlists: playlists) ??
          PlaylistState(playlists: playlists),
    );
  }

  Future<void> rename(int id, String newName) async {
    await _repo.rename(id, newName);
    final playlists = await _repo.getAll();
    state = AsyncValue.data(
      (state.valueOrNull ?? const PlaylistState())
          .copyWith(playlists: playlists),
    );
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    final playlists = await _repo.getAll();
    state = AsyncValue.data(
      (state.valueOrNull ?? const PlaylistState())
          .copyWith(playlists: playlists),
    );
  }

  Future<void> addSong(int playlistId, Song song) async {
    await _repo.addSong(playlistId, song);
    final playlists = await _repo.getAll();
    state = AsyncValue.data(
      (state.valueOrNull ?? const PlaylistState())
          .copyWith(playlists: playlists),
    );
  }

  Future<void> removeSong(int playlistId, String songId) async {
    await _repo.removeSong(playlistId, songId);
    final playlists = await _repo.getAll();
    state = AsyncValue.data(
      (state.valueOrNull ?? const PlaylistState())
          .copyWith(playlists: playlists),
    );
  }

  Future<void> reorderSongs(
      int playlistId, int oldIndex, int newIndex) async {
    await _repo.reorderSongs(playlistId, oldIndex, newIndex);
  }
}
