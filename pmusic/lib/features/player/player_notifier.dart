import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../history/history_notifier.dart';
import '../settings/settings_notifier.dart';
import 'just_audio_player.dart';
import 'player_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

/// Application-level player state.
///
/// Named [AppPlayerState] to avoid collision with [just_audio]'s own
/// `PlayerState` type.
class AppPlayerState {
  const AppPlayerState({
    this.currentSong,
    this.playMode = PlayMode.sequence,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentIndex = 0,
    this.isBuffering = false,
    this.errorMessage,
  });

  final Song? currentSong;
  final PlayMode playMode;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<Song> queue;
  final int currentIndex;
  final bool isBuffering;
  final String? errorMessage;

  bool get hasQueue => queue.isNotEmpty;
  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex < queue.length - 1;

  AppPlayerState copyWith({
    Song? currentSong,
    PlayMode? playMode,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<Song>? queue,
    int? currentIndex,
    bool? isBuffering,
    String? errorMessage,
    bool clearError = false,
    bool clearSong = false,
  }) {
    return AppPlayerState(
      currentSong: clearSong ? null : (currentSong ?? this.currentSong),
      playMode: playMode ?? this.playMode,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isBuffering: isBuffering ?? this.isBuffering,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return DriftPlayerRepository(db);
});

final playerNotifierProvider =
    AsyncNotifierProvider<PlayerNotifier, AppPlayerState>(
  PlayerNotifier.new,
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class PlayerNotifier extends AsyncNotifier<AppPlayerState> {
  late PlayerRepository _playerRepo;
  late JustAudioPlayer _audioPlayer;

  @override
  Future<AppPlayerState> build() async {
    _playerRepo = ref.read(playerRepositoryProvider);
    _audioPlayer = JustAudioPlayer();
    ref.onDispose(_audioPlayer.dispose);

    // Restore last queue from persistence.
    final saved = await _playerRepo.loadQueue();

    // Subscribe to position ticks.
    _audioPlayer.positionStream.listen((pos) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(position: pos));
      }
    });

    // Subscribe to duration.
    _audioPlayer.durationStream.listen((dur) {
      final current = state.valueOrNull;
      if (current != null && dur != null) {
        state = AsyncValue.data(current.copyWith(duration: dur));
      }
    });

    final settings = await ref.read(settingsNotifierProvider.future);
    return AppPlayerState(
      queue: saved.queue,
      currentIndex: saved.index,
      currentSong:
          saved.queue.isNotEmpty ? saved.queue[saved.index] : null,
      playMode: settings.playMode,
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> playSong(Song song) async {
    final current = state.valueOrNull ?? const AppPlayerState();
    state = AsyncValue.data(
      current.copyWith(
        currentSong: song,
        isBuffering: true,
        clearError: true,
      ),
    );
    try {
      final settings = await ref.read(settingsNotifierProvider.future);
      final localPath =
          await _playerRepo.getLocalPath(song.id, song.source.param);
      final source = localPath ??
          await _playerRepo.getPlayUrl(
            song.id,
            song.source.param,
            settings.audioQuality,
          );
      await _audioPlayer.setSource(source);
      await _audioPlayer.play();
      state = AsyncValue.data(
        current.copyWith(
          currentSong: song,
          isPlaying: true,
          isBuffering: false,
        ),
      );
      ref.read(historyRepositoryProvider).addEntry(song);
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(
          isBuffering: false,
          isPlaying: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> togglePlay() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.isPlaying) {
      await _audioPlayer.pause();
      state = AsyncValue.data(current.copyWith(isPlaying: false));
    } else {
      await _audioPlayer.play();
      state = AsyncValue.data(current.copyWith(isPlaying: true));
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seekTo(position);
  }

  Future<void> skipToNext() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasNext) return;
    await playSong(current.queue[current.currentIndex + 1]);
    state = AsyncValue.data(
      state.valueOrNull?.copyWith(
            currentIndex: current.currentIndex + 1,
          ) ??
          current,
    );
  }

  Future<void> skipToPrevious() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasPrevious) return;
    await playSong(current.queue[current.currentIndex - 1]);
    state = AsyncValue.data(
      state.valueOrNull?.copyWith(
            currentIndex: current.currentIndex - 1,
          ) ??
          current,
    );
  }

  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    await _playerRepo.saveQueue(songs, startIndex);
    state = AsyncValue.data(
      (state.valueOrNull ?? const AppPlayerState()).copyWith(
        queue: songs,
        currentIndex: startIndex,
      ),
    );
    if (songs.isNotEmpty) await playSong(songs[startIndex]);
  }

  Future<void> setPlayMode(PlayMode mode) async {
    state = AsyncValue.data(
      (state.valueOrNull ?? const AppPlayerState()).copyWith(playMode: mode),
    );
  }
}
