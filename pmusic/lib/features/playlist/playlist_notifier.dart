import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
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
  return InMemoryPlaylistRepository();
});

final playlistNotifierProvider =
    AsyncNotifierProvider<PlaylistNotifier, PlaylistState>(
  PlaylistNotifier.new,
);

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
}
