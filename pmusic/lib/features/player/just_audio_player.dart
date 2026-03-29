import 'package:just_audio/just_audio.dart' as ja;

/// Thin wrapper around [ja.AudioPlayer] that exposes only what
/// [PlayerNotifier] needs.
class JustAudioPlayer {
  JustAudioPlayer() : _player = ja.AudioPlayer();

  final ja.AudioPlayer _player;

  // ── Playback control ──────────────────────────────────────────────────────

  /// Set the audio source.  Accepts both HTTP(S) URLs and local file paths.
  Future<void> setSource(String urlOrPath) async {
    if (urlOrPath.startsWith('http://') ||
        urlOrPath.startsWith('https://')) {
      await _player.setUrl(urlOrPath);
    } else {
      await _player.setFilePath(urlOrPath);
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seekTo(Duration position) => _player.seek(position);
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Emits the actual playing state from just_audio so the UI stays in sync
  /// when the OS interrupts or resumes playback.
  Stream<bool> get playingStream => _player.playingStream;

  /// Emits [ja.PlayerState] events from just_audio.
  Stream<ja.PlayerState> get playerStateStream => _player.playerStateStream;

  /// Emits `true` each time the current track naturally reaches its end
  /// (ProcessingState.completed while not sought).
  Stream<void> get completionStream => _player.playerStateStream
      .where((s) =>
          s.processingState == ja.ProcessingState.completed && s.playing == false)
      .map((_) {});

  // ── State accessors ───────────────────────────────────────────────────────

  bool get playing => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  ja.ProcessingState get processingState => _player.processingState;
  double get volume => _player.volume;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> dispose() => _player.dispose();
}
