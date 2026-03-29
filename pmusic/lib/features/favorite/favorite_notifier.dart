import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../player/player_notifier.dart';
import 'favorite_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class FavoriteState {
  const FavoriteState({
    this.songs = const [],
    this.isLoading = false,
  });

  final List<Song> songs;
  final bool isLoading;

  bool isFavorite(Song song) =>
      songs.any((s) => s.id == song.id && s.source == song.source);

  FavoriteState copyWith({List<Song>? songs, bool? isLoading}) {
    return FavoriteState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return DriftFavoriteRepository(db);
});

final favoriteNotifierProvider =
    AsyncNotifierProvider<FavoriteNotifier, FavoriteState>(
  FavoriteNotifier.new,
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class FavoriteNotifier extends AsyncNotifier<FavoriteState> {
  late FavoriteRepository _repo;

  @override
  Future<FavoriteState> build() async {
    _repo = ref.read(favoriteRepositoryProvider);
    // Subscribe to the Drift stream so any change propagates instantly.
    final sub = _repo.watchAll().listen((songs) {
      state = AsyncValue.data(FavoriteState(songs: songs));
    });
    ref.onDispose(sub.cancel);
    // Return initial snapshot (stream may not emit synchronously).
    final initialSongs = await _repo.getAll();
    return FavoriteState(songs: initialSongs);
  }

  Future<void> toggle(Song song) async {
    final current = state.valueOrNull ?? const FavoriteState();
    if (current.isFavorite(song)) {
      await _repo.remove(song.id, song.source.param);
    } else {
      await _repo.add(song);
    }
    // The watchAll() stream will push the updated list automatically.
  }

  /// Removes multiple songs from favorites at once (batch operation).
  Future<void> batchRemove(List<Song> songs) async {
    for (final song in songs) {
      await _repo.remove(song.id, song.source.param);
    }
    // The watchAll() stream will push the updated list automatically.
  }

  /// Appends multiple songs to the play queue.
  Future<void> batchAddToQueue(List<Song> songs) async {
    final player = ref.read(playerNotifierProvider.notifier);
    for (final song in songs) {
      await player.addToQueue(song);
    }
  }
}
