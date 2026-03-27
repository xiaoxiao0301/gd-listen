/// Playback mode for the queue.
enum PlayMode {
  /// Play songs in order; stop at end.
  sequence,

  /// Randomly pick songs from the queue; reshuffle when exhausted.
  shuffle,

  /// Loop the full queue indefinitely.
  repeatAll,

  /// Repeat the current song indefinitely.
  repeatOne,
}

/// Audio bitrate preference (kbps). 740 and 999 are lossless.
enum AudioQuality {
  q128(128),
  q192(192),
  q320(320),
  q740(740),
  q999(999);

  const AudioQuality(this.bitrate);
  final int bitrate;
}

/// Supported music source providers.
enum MusicSource {
  netease,
  kuwo,
  joox,
  bilibili,

  // Less stable – available but not recommended as default.
  tencent,
  tidal,
  spotify,
  ytmusic,
  qobuz,
  deezer,
  migu,
  kugou,
  ximalaya,
  apple;

  /// The API query-param value for this source.
  String get param => name;
}
