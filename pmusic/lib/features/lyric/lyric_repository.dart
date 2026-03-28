import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/lyric_line.dart';

// ─── Repository interface ────────────────────────────────────────────────────

abstract class LyricRepository {
  /// Fetch and parse lyrics for [songId] from [source].
  ///
  /// Returns an empty list when no lyrics are available.
  Future<List<LyricLine>> getLyrics(String songId, String source);
}

// ─── API + file-cache implementation ────────────────────────────────────────

/// Fetches LRC lyrics via [MusicApiClient]; caches raw JSON to
/// `<app_cache_dir>/lyrics/<source>_<id>.json` to avoid repeat network calls.
class ApiLyricRepository implements LyricRepository {
  ApiLyricRepository(this._api);

  final MusicApiClient _api;
  Directory? _cacheDir;

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationCacheDirectory();
    _cacheDir = Directory('${base.path}/lyrics');
    await _cacheDir!.create(recursive: true);
    return _cacheDir!;
  }

  @override
  Future<List<LyricLine>> getLyrics(String songId, String source) async {
    final dir = await _getCacheDir();
    final file = File('${dir.path}/${source}_$songId.json');

    // Cache hit
    if (await file.exists()) {
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final lrc = json['lyric'] as String? ?? '';
        if (lrc.isNotEmpty) {
          return parseLrc(lrc, translationLrc: json['tlyric'] as String?);
        }
      } catch (_) {
        // Corrupted cache — delete and re-fetch.
        await file.delete();
      }
    }

    // Network fetch
    final dto = await _api.getLyric(source: source, id: songId);
    if (dto.lyric.isEmpty) return [];

    // Persist to cache (best-effort)
    try {
      await file.writeAsString(jsonEncode({
        'lyric': dto.lyric,
        'tlyric': dto.tlyric,
      }));
    } catch (_) {}

    return parseLrc(dto.lyric, translationLrc: dto.tlyric);
  }
}

// ─── Stub ─────────────────────────────────────────────────────────────────────

class StubLyricRepository implements LyricRepository {
  @override
  Future<List<LyricLine>> getLyrics(String songId, String source) async =>
      const [];
}

// ─── LRC parser helper ───────────────────────────────────────────────────────

/// Parses an LRC string into a sorted list of [LyricLine] objects.
///
/// Supports:
/// - Standard `[mm:ss.xx]` time tags
/// - Multiple time tags on a single line
List<LyricLine> parseLrc(String lrc, {String? translationLrc}) {
  final transMap = <Duration, String>{};
  if (translationLrc != null) {
    for (final line in translationLrc.split('\n')) {
      final parsed = _parseLine(line);
      for (final e in parsed) {
        transMap[e.timestamp] = e.original;
      }
    }
  }

  final lines = <LyricLine>[];
  for (final raw in lrc.split('\n')) {
    final parsed = _parseLine(raw);
    for (final e in parsed) {
      lines.add(LyricLine(
        timestamp: e.timestamp,
        original: e.original,
        translation: transMap[e.timestamp],
      ));
    }
  }
  lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return lines;
}

final _timeTagPattern = RegExp(r'\[(\d{1,3}):(\d{2})\.(\d{2,3})\]');

List<LyricLine> _parseLine(String line) {
  final matches = _timeTagPattern.allMatches(line).toList();
  if (matches.isEmpty) return const [];

  final text = line.replaceAll(_timeTagPattern, '').trim();
  return matches.map((m) {
    final minutes = int.parse(m.group(1)!);
    final seconds = int.parse(m.group(2)!);
    final centis = m.group(3)!;
    final ms = centis.length == 2
        ? int.parse(centis) * 10
        : int.parse(centis);
    final ts = Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: ms,
    );
    return LyricLine(timestamp: ts, original: text);
  }).toList();
}
