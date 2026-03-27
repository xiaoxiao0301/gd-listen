import 'enums.dart';

/// Immutable domain model for a music track.
class Song {
  const Song({
    required this.id,
    required this.source,
    required this.name,
    required this.artists,
    required this.album,
    required this.picId,
    required this.lyricId,
  });

  final String id;
  final MusicSource source;

  /// Display name of the track.
  final String name;

  /// List of artist names.
  final List<String> artists;
  final String album;

  /// Used to build the album-art URL.
  final String picId;

  /// Used to fetch the lyrics (usually equals [id]).
  final String lyricId;

  /// Comma-separated artist names for display.
  String get artistDisplay => artists.join(' / ');

  Song copyWith({
    String? id,
    MusicSource? source,
    String? name,
    List<String>? artists,
    String? album,
    String? picId,
    String? lyricId,
  }) {
    return Song(
      id: id ?? this.id,
      source: source ?? this.source,
      name: name ?? this.name,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      picId: picId ?? this.picId,
      lyricId: lyricId ?? this.lyricId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          source == other.source;

  @override
  int get hashCode => Object.hash(id, source);

  @override
  String toString() => 'Song(id: $id, source: $source, name: $name)';
}
