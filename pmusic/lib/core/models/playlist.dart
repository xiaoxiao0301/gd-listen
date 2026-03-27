/// Immutable domain model for a playlist.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.songCount = 0,
  });

  final int id;
  final String name;

  /// Creation timestamp as Unix milliseconds.
  final int createdAt;

  /// Last-modified timestamp as Unix milliseconds.
  final int updatedAt;

  /// Cached song count (denormalized for display).
  final int songCount;

  Playlist copyWith({
    int? id,
    String? name,
    int? createdAt,
    int? updatedAt,
    int? songCount,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      songCount: songCount ?? this.songCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Playlist(id: $id, name: $name)';
}
