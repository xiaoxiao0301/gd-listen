/// Metadata for a locally-cached audio file.
///
/// Used by the cache manager for LRU eviction and storage accounting.
class CacheEntry {
  const CacheEntry({
    required this.filePath,
    required this.songId,
    required this.source,
    required this.fileSizeKb,
    required this.lastAccessed,
  });

  /// Absolute local path to the cached audio file.
  final String filePath;

  final String songId;

  /// Music source identifier (e.g. "netease").
  final String source;

  /// File size in kilobytes.
  final int fileSizeKb;

  /// Unix milliseconds of the last access — used for LRU ordering.
  final int lastAccessed;

  CacheEntry copyWith({
    String? filePath,
    String? songId,
    String? source,
    int? fileSizeKb,
    int? lastAccessed,
  }) {
    return CacheEntry(
      filePath: filePath ?? this.filePath,
      songId: songId ?? this.songId,
      source: source ?? this.source,
      fileSizeKb: fileSizeKb ?? this.fileSizeKb,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheEntry &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath;

  @override
  int get hashCode => filePath.hashCode;

  @override
  String toString() =>
      'CacheEntry(songId: $songId, source: $source, ${fileSizeKb}KB)';
}
