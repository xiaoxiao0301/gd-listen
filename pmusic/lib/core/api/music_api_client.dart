import 'package:dio/dio.dart';

import 'models/lyric_dto.dart';
import 'models/song_dto.dart';
import 'models/song_url_dto.dart';

/// An HTTP client wrapping the GD Studio Music API.
///
/// Base URL: `https://music-api.gdstudio.xyz/api.php`
class MusicApiClient {
  MusicApiClient(this._dio);

  final Dio _dio;

  static const String _baseUrl =
      'https://music-api.gdstudio.xyz/api.php';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the cover-art URL for a given [picId].
  /// No network call — URL constructed locally.
  static String buildPicUrl(String source, String picId,
      {int size = 300}) {
    if (picId.isEmpty) return '';
    return '$_baseUrl?types=pic&source=$source&id=$picId&size=$size';
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Search for songs.
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
    required String quality,
  }) async {
    final resp = await _dio.get<dynamic>(_baseUrl, queryParameters: {
      'types': 'url',
      'source': source,
      'id': id,
      'br': quality,
    });
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return SongUrlDto.fromJson(data);
    }
    return const SongUrlDto(url: '', br: 0, size: 0);
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
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return LyricDto.fromJson(data);
    }
    return const LyricDto(lyric: '');
  }
}

