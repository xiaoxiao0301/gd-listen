/// Response from `types=url` – resolves a song to its audio stream URL.
class SongUrlDto {
  const SongUrlDto({
    required this.url,
    required this.br,
    required this.size,
  });

  /// Resolved streaming / download URL.
  final String url;

  /// Actual bit-rate in kbps (e.g. 320, 128).
  final int br;

  /// File size in bytes.
  final int size;

  factory SongUrlDto.fromJson(Map<String, dynamic> json) {
    return SongUrlDto(
      url: json['url'] as String? ?? '',
      br: (json['br'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}
