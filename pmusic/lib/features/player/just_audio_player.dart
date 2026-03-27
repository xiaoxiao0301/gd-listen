import 'package:just_audio/just_audio.dart' as ja;

/// Thin wrapper around [ja.AudioPlayer] that exposes only what
/// [PlayerNotifier] needs.  The audio_session setup is deferred to P1-08.
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
  Future<void> seekTo(Duration position) => _player.seek(position);

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Emits [ja.PlayerState] events from just_audio.
  Stream<ja.PlayerState> get playerStateStream => _player.playerStateStream;

  // ── State accessors ───────────────────────────────────────────────────────

  bool get playing => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  ja.ProcessingState get processingState => _player.processingState;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> dispose() => _player.dispose();
}
