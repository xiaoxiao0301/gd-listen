import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/cache_entry.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/enums.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../cache/cache_manager.dart';
import '../cache/cache_notifier.dart';
import '../cache/cache_repository.dart';
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
  final api = ref.read(musicApiClientProvider);
  return DriftPlayerRepository(db: db, apiClient: api);
});

final playerNotifierProvider =
    AsyncNotifierProvider<PlayerNotifier, AppPlayerState>(
  PlayerNotifier.new,
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class PlayerNotifier extends AsyncNotifier<AppPlayerState> {
  late PlayerRepository _playerRepo;
  late JustAudioPlayer _audioPlayer;
  late CacheManager _cacheManager;
  late CacheRepository _cacheRepo;
  late Dio _downloadDio;

  // Shuffle order: list of queue indices in the order they should be played.
  List<int> _shuffleOrder = [];

  @override
  Future<AppPlayerState> build() async {
    _playerRepo = ref.read(playerRepositoryProvider);
    _audioPlayer = JustAudioPlayer();
    _cacheRepo = ref.read(cacheRepositoryProvider);
    _cacheManager = ref.read(cacheManagerProvider);
    _downloadDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ));
    ref.onDispose(_audioPlayer.dispose);
    ref.onDispose(_downloadDio.close);

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

    // Auto-advance when track completes.
    _audioPlayer.completionStream.listen((_) => _onTrackCompleted());

    final settings = await ref.read(settingsNotifierProvider.future);
    return AppPlayerState(
      queue: saved.queue,
      currentIndex: saved.index,
      currentSong:
          saved.queue.isNotEmpty ? saved.queue[saved.index] : null,
      playMode: settings.playMode,
    );
  }

  // ── Track completion handler ───────────────────────────────────────────────

  void _onTrackCompleted() {
    final current = state.valueOrNull;
    if (current == null || current.queue.isEmpty) return;

    switch (current.playMode) {
      case PlayMode.repeatOne:
        _audioPlayer.seekTo(Duration.zero);
        _audioPlayer.play();
        break;
      case PlayMode.shuffle:
        _playNextShuffled(current);
        break;
      case PlayMode.sequence:
        if (current.hasNext) {
          _playAtIndex(current, current.currentIndex + 1);
        }
        // else: stop at end
        break;
      case PlayMode.repeatAll:
        final nextIndex = (current.currentIndex + 1) % current.queue.length;
        _playAtIndex(current, nextIndex);
        break;
    }
  }

  void _playNextShuffled(AppPlayerState current) {
    if (_shuffleOrder.isEmpty) _rebuildShuffleOrder(current.queue.length);
    final pos = _shuffleOrder.indexOf(current.currentIndex);
    final nextPos = (pos + 1) % _shuffleOrder.length;
    if (nextPos == 0) _rebuildShuffleOrder(current.queue.length);
    final nextIndex = _shuffleOrder[nextPos];
    _playAtIndex(current, nextIndex);
  }

  void _rebuildShuffleOrder(int length) {
    _shuffleOrder = List.generate(length, (i) => i)..shuffle(Random());
  }

  void _playAtIndex(AppPlayerState current, int index) {
    final song = current.queue[index];
    // Fire and forget — errors handled inside playSong
    playSong(song, queue: current.queue, startIndex: index);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Play [song], optionally replacing the queue.
  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    int? startIndex,
  }) async {
    final current = state.valueOrNull ?? const AppPlayerState();
    final newQueue = queue ?? (current.queue.isEmpty ? [song] : current.queue);
    final newIndex = startIndex ??
        newQueue.indexWhere((s) => s.id == song.id && s.source == song.source);
    final effectiveIndex = newIndex.clamp(0, newQueue.length - 1);

    state = AsyncValue.data(
      current.copyWith(
        currentSong: song,
        queue: newQueue,
        currentIndex: effectiveIndex,
        isBuffering: true,
        isPlaying: false,
        position: Duration.zero,
        clearError: true,
      ),
    );

    try {
      final settings = await ref.read(settingsNotifierProvider.future);
      final localPath =
          await _playerRepo.getLocalPath(song.id, song.source.param);

      // Offline guard: if offline and no local cache, skip this song.
      if (settings.offlineMode && localPath == null) {
        state = AsyncValue.data(
          (state.valueOrNull ?? current).copyWith(
            isBuffering: false,
            isPlaying: false,
            errorMessage: '当前离线，「${song.name}」未缓存',
          ),
        );
        return;
      }

      final playSource = localPath ??
          await _playerRepo.getPlayUrl(
            song.id,
            song.source.param,
            settings.audioQuality,
          );
      await _audioPlayer.setSource(playSource);
      await _audioPlayer.play();
      // Persist queue
      unawaited(_playerRepo.saveQueue(newQueue, effectiveIndex));
      // Record history
      unawaited(ref.read(historyRepositoryProvider).addEntry(song));
      // Background: cache audio file if we used a remote URL
      if (localPath == null) {
        unawaited(_downloadAndCacheSong(song, playSource, settings));
      }

      state = AsyncValue.data(
        (state.valueOrNull ?? current).copyWith(
          currentSong: song,
          isPlaying: true,
          isBuffering: false,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        (state.valueOrNull ?? current).copyWith(
          isBuffering: false,
          isPlaying: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Downloads [remoteUrl] to the local audio cache directory and records the
  /// entry in the database. Uses a temporary file to ensure atomicity: the
  /// final path is only written to the DB after a successful rename.
  Future<void> _downloadAndCacheSong(
    Song song,
    String remoteUrl,
    AppSettings settings,
  ) async {
    final base = await getApplicationCacheDirectory();
    final audioDir = Directory('${base.path}/audio');
    await audioDir.create(recursive: true);

    final destPath =
        '${audioDir.path}/${song.source.param}_${song.id}.mp3';
    final tmpPath = '$destPath.tmp';

    // Skip if already cached on disk (e.g. concurrent play calls).
    if (await File(destPath).exists()) return;

    try {
      await _downloadDio.download(remoteUrl, tmpPath);

      final tmpFile = File(tmpPath);
      final sizeKb = ((await tmpFile.length()) / 1024).ceil();

      // Ensure LRU eviction before committing the new file.
      await _cacheManager.ensureSpace(sizeKb, settings.cacheMaxMb);

      // Atomic rename: only the final path is registered in the DB.
      await tmpFile.rename(destPath);

      await _cacheRepo.add(CacheEntry(
        filePath: destPath,
        songId: song.id,
        source: song.source.param,
        fileSizeKb: sizeKb,
        lastAccessed: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (_) {
      // Best-effort caching; clean up temp file silently.
      try {
        await File(tmpPath).delete();
      } catch (_) {}
    }
  }

  Future<void> togglePlay() async {
    final current = state.valueOrNull;
    if (current == null || current.currentSong == null) return;
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
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(position: position));
    }
  }

  Future<void> skipToNext() async {
    final current = state.valueOrNull;
    if (current == null || current.queue.isEmpty) return;
    if (current.playMode == PlayMode.shuffle) {
      _playNextShuffled(current);
      return;
    }
    if (!current.hasNext) {
      if (current.playMode == PlayMode.repeatAll) {
        _playAtIndex(current, 0);
      }
      return;
    }
    _playAtIndex(current, current.currentIndex + 1);
  }

  Future<void> skipToPrevious() async {
    final current = state.valueOrNull;
    if (current == null || current.queue.isEmpty) return;
    // If more than 3s into a track, restart it; otherwise go to previous.
    if (current.position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    if (!current.hasPrevious) return;
    _playAtIndex(current, current.currentIndex - 1);
  }

  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    final idx = startIndex.clamp(0, songs.isEmpty ? 0 : songs.length - 1);
    unawaited(_playerRepo.saveQueue(songs, idx));
    state = AsyncValue.data(
      (state.valueOrNull ?? const AppPlayerState()).copyWith(
        queue: songs,
        currentIndex: idx,
      ),
    );
    if (songs.isNotEmpty) await playSong(songs[idx]);
  }

  Future<void> setPlayMode(PlayMode mode) async {
    final current = state.valueOrNull ?? const AppPlayerState();
    if (mode == PlayMode.shuffle && _shuffleOrder.isEmpty) {
      _rebuildShuffleOrder(current.queue.length);
    }
    state = AsyncValue.data(current.copyWith(playMode: mode));
  }

  Future<void> addToQueue(Song song) async {
    final current = state.valueOrNull ?? const AppPlayerState();
    final newQueue = [...current.queue, song];
    state = AsyncValue.data(current.copyWith(queue: newQueue));
    unawaited(_playerRepo.saveQueue(newQueue, current.currentIndex));
  }

  Future<void> insertNext(Song song) async {
    final current = state.valueOrNull ?? const AppPlayerState();
    final newQueue = List<Song>.from(current.queue);
    final at = (current.currentIndex + 1).clamp(0, newQueue.length);
    newQueue.insert(at, song);
    state = AsyncValue.data(current.copyWith(queue: newQueue));
    unawaited(_playerRepo.saveQueue(newQueue, current.currentIndex));
  }

  Future<void> removeFromQueue(int index) async {
    final current = state.valueOrNull ?? const AppPlayerState();
    if (index < 0 || index >= current.queue.length) return;
    final newQueue = List<Song>.from(current.queue)..removeAt(index);
    var ci = current.currentIndex;
    if (index < ci) ci--;
    ci = ci.clamp(0, newQueue.isEmpty ? 0 : newQueue.length - 1);
    state = AsyncValue.data(current.copyWith(queue: newQueue, currentIndex: ci));
    unawaited(_playerRepo.saveQueue(newQueue, ci));
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final current = state.valueOrNull ?? const AppPlayerState();
    final newQueue = List<Song>.from(current.queue);
    final song = newQueue.removeAt(oldIndex);
    final at = newIndex > oldIndex ? newIndex - 1 : newIndex;
    newQueue.insert(at, song);
    var ci = current.currentIndex;
    if (oldIndex == ci) {
      ci = at;
    } else if (oldIndex < ci && at >= ci) {
      ci--;
    } else if (oldIndex > ci && at <= ci) {
      ci++;
    }
    state = AsyncValue.data(current.copyWith(queue: newQueue, currentIndex: ci));
    unawaited(_playerRepo.saveQueue(newQueue, ci));
  }

  Future<void> clearQueue() async {
    await _audioPlayer.stop();
    await _playerRepo.saveQueue(const [], 0);
    state = AsyncValue.data(const AppPlayerState());
  }

  /// Jump to a specific index in the current queue.
  Future<void> skipToIndex(int index) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (index < 0 || index >= current.queue.length) return;
    final song = current.queue[index];
    await playSong(song, queue: current.queue, startIndex: index);
  }
}

// ── Fire-and-forget helper ─────────────────────────────────────────────────
void unawaited(Future<void> future) => future.catchError((_) {});
