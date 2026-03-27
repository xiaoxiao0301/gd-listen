import 'enums.dart';

/// User-configurable app settings.
class AppSettings {
  const AppSettings({
    this.defaultSource = MusicSource.netease,
    this.audioQuality = AudioQuality.q320,
    this.cacheMaxMb = 512,
    this.playMode = PlayMode.sequence,
    this.lyricTranslation = true,
    this.offlineMode = false,
  });

  final MusicSource defaultSource;
  final AudioQuality audioQuality;

  /// Maximum local cache size in megabytes.
  final int cacheMaxMb;
  final PlayMode playMode;

  /// Whether to show lyric translations when available.
  final bool lyricTranslation;

  /// When `true` only locally-cached tracks are played.
  final bool offlineMode;

  AppSettings copyWith({
    MusicSource? defaultSource,
    AudioQuality? audioQuality,
    int? cacheMaxMb,
    PlayMode? playMode,
    bool? lyricTranslation,
    bool? offlineMode,
  }) {
    return AppSettings(
      defaultSource: defaultSource ?? this.defaultSource,
      audioQuality: audioQuality ?? this.audioQuality,
      cacheMaxMb: cacheMaxMb ?? this.cacheMaxMb,
      playMode: playMode ?? this.playMode,
      lyricTranslation: lyricTranslation ?? this.lyricTranslation,
      offlineMode: offlineMode ?? this.offlineMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          defaultSource == other.defaultSource &&
          audioQuality == other.audioQuality &&
          cacheMaxMb == other.cacheMaxMb &&
          playMode == other.playMode &&
          lyricTranslation == other.lyricTranslation &&
          offlineMode == other.offlineMode;

  @override
  int get hashCode => Object.hash(
        defaultSource,
        audioQuality,
        cacheMaxMb,
        playMode,
        lyricTranslation,
        offlineMode,
      );
}
