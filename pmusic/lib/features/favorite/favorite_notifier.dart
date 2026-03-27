import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
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
  return InMemoryFavoriteRepository();
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
    final songs = await _repo.getAll();
    return FavoriteState(songs: songs);
  }

  Future<void> toggle(Song song) async {
    final current = state.valueOrNull ?? const FavoriteState();
    if (current.isFavorite(song)) {
      await _repo.remove(song.id, song.source.param);
    } else {
      await _repo.add(song);
    }
    final songs = await _repo.getAll();
    state = AsyncValue.data(current.copyWith(songs: songs));
  }
}
