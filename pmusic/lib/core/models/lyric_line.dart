/// A single parsed line from an LRC lyric file.
class LyricLine {
  const LyricLine({
    required this.timestamp,
    required this.original,
    this.translation,
  });

  /// Position in the track where this line starts.
  final Duration timestamp;

  /// Original-language text.
  final String original;

  /// Translation text, if present (e.g. Chinese ↔ English parallel lyrics).
  final String? translation;

  @override
  String toString() =>
      'LyricLine(${timestamp.inMilliseconds}ms, "$original")';
}
