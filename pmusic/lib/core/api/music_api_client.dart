import 'package:dio/dio.dart';

import 'models/lyric_dto.dart';
import 'models/song_dto.dart';
import 'models/song_url_dto.dart';

/// An HTTP client wrapping the GD Studio Music API.
///
/// Base URL: `https://music-api.gdstudio.xyz/api.php`
/// All query parameters are appended by each method.
///
/// Full implementation delivered in **P1-04**.
/// This skeleton defines the interface so providers can be wired now.
class MusicApiClient {
  MusicApiClient(this._dio);

  final Dio _dio;

  static const String _baseUrl =
      'https://music-api.gdstudio.xyz/api.php';

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Search for songs.
  ///
  /// [source] – e.g. "netease"; [keyword] – UTF-8 search term;
  /// [page] – 1-based page index; [pageSize] – results per page.
  Future<List<SongDto>> searchSongs({
    required String source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _dio.get<dynamic>(_baseUrl, queryParameters: {
      'types': 'search',
      'source': source,
      'name': keyword,
      'page': page,
      'count': pageSize,
    });
    final data = resp.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(SongDto.fromJson)
          .toList();
    }
    return const [];
  }

  // ---------------------------------------------------------------------------
  // URL resolution
  // ---------------------------------------------------------------------------

  /// Resolves the audio stream URL for a song at a given quality.
  Future<SongUrlDto> getSongUrl({
    required String source,
    required String id,
    required String quality, // e.g. "320", "128"
  }) async {
    final resp = await _dio.get<dynamic>(_baseUrl, queryParameters: {
      'types': 'url',
      'source': source,
      'id': id,
      'br': quality,
    });
    return SongUrlDto.fromJson(resp.data as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Cover art
  // ---------------------------------------------------------------------------

  /// Returns the cover-art URL for a given [picId].
  /// No network call is needed – the URL is constructed locally.
  String getPicUrl(String source, String picId, {int size = 300}) {
    return '$_baseUrl?types=pic&source=$source&id=$picId&size=$size';
  }

  // ---------------------------------------------------------------------------
  // Lyrics
  // ---------------------------------------------------------------------------

  /// Fetches LRC lyric data for a song.
  Future<LyricDto> getLyric({
    required String source,
    required String id,
  }) async {
    final resp = await _dio.get<dynamic>(_baseUrl, queryParameters: {
      'types': 'lyric',
      'source': source,
      'id': id,
    });
    return LyricDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
