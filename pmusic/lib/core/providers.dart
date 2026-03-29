import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/interceptors/interceptors.dart';
import 'api/music_api_client.dart';
import 'db/app_database.dart';
import 'utils/rate_limiter.dart';

// ─── Database ────────────────────────────────────────────────────────────────

/// Singleton [AppDatabase] instance.
///
/// Opened once per app lifecycle via [LazyDatabase]; Drift handles the
/// underlying SQLite connection pool.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ─── Rate limiter ─────────────────────────────────────────────────────────────

/// Shared [RateLimiter] — 45 requests per 5-minute sliding window.
final rateLimiterProvider = Provider<RateLimiter>((ref) {
  return RateLimiter();
});

// ─── Dio ─────────────────────────────────────────────────────────────────────

/// Configured [Dio] instance with all interceptors attached.
final dioProvider = Provider<Dio>((ref) {
  final rateLimiter = ref.watch(rateLimiterProvider);

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'pmusic/1.0',
      },
    ),
  );

  dio.interceptors.addAll([
    RateLimitInterceptor(rateLimiter),
    RetryInterceptor(dio),  // maxRetries = 1 (one retry per spec)
    ErrorInterceptor(),
  ]);

  return dio;
});

// ─── API client ─────────────────────────────────────────────────────────────

/// Singleton [MusicApiClient] wrapping the configured [Dio].
final musicApiClientProvider = Provider<MusicApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return MusicApiClient(dio);
});

// ─── Cover-art URL resolver ──────────────────────────────────────────────────

/// Resolves the actual CDN image URL for a given `(source, picId, size)` triple.
///
/// The GD Studio API `types=pic` endpoint returns JSON `{"url":"..."}` rather
/// than image bytes, so we must resolve the URL before passing it to
/// [CachedNetworkImage]. Results are kept alive for the app session to avoid
/// redundant API calls.
final picUrlProvider =
    FutureProvider.family<String, (String, String, int)>((ref, args) async {
  final (source, picId, size) = args;
  if (picId.isEmpty) return '';
  // Some sources return a full URL as pic_id — use it directly.
  if (picId.startsWith('http')) return picId;
  final api = ref.read(musicApiClientProvider);
  return api.getPicUrl(source: source, picId: picId, size: size);
});
