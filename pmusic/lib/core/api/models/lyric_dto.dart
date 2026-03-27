/// Response from `types=lyric` – raw LRC content for a song.
class LyricDto {
  const LyricDto({
    required this.lyric,
    this.tlyric,
  });

  /// Original-language LRC text.
  final String lyric;

  /// Translation LRC text, if available.
  final String? tlyric;

  factory LyricDto.fromJson(Map<String, dynamic> json) {
    return LyricDto(
      lyric: json['lyric'] as String? ?? '',
      tlyric: json['tlyric'] as String?,
    );
  }
}
