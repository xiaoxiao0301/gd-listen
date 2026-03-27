// Data-transfer objects for GD Studio Music API responses.
// These are thin wrappers around the raw JSON – conversion to domain
// models happens in the repository layer.

/// Search result / song summary returned by `types=search`.
class SongDto {
  const SongDto({
    required this.id,
    required this.name,
    required this.artist,
    required this.album,
    required this.picId,
    required this.lyricId,
    required this.source,
  });

  final String id;
  final String name;

  /// Artist names as a list.
  final List<String> artist;
  final String album;
  final String picId;
  final String lyricId;
  final String source;

  factory SongDto.fromJson(Map<String, dynamic> json) {
    final artists = json['artist'];
    return SongDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      artist: switch (artists) {
        List l => l.cast<String>(),
        String s => s.split('/'),
        _ => const [],
      },
      album: json['album'] as String? ?? '',
      picId: json['pic_id'] as String? ?? '',
      lyricId: json['lyric_id'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}
