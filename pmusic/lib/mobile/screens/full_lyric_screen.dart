import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../features/player/player_notifier.dart';
import '../widgets/lyric_scroll_view.dart';

// ─── Design tokens (full_lyrics/code.html — dark mode) ───────────────────────

const _kBg = Color(0xFF2B1810);
const _kAmber = Color(0xFFE2A05B);
const _kBrown = Color(0xFF795548);
const _kOnSurfaceVariant = Color(0xFF514439);

/// Full-screen lyric viewer for mobile.
///
/// Design source: `picture/stitch/full_lyrics/code.html`
///
/// Layout:
///  • Sticky frosted header — back + song info + more button
///  • Scrollable lyric area using [LyricScrollView] (auto-scroll + seek)
///  • Top + bottom vignette gradients (dark #2B1810)
///  • Fixed bottom player pill — cover + title + artist + play/pause + skip
class FullLyricScreen extends ConsumerWidget {
  const FullLyricScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerNotifierProvider);
    final song = playerAsync.valueOrNull?.currentSong;

    if (song == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).maybePop();
      });
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kAmber)),
      );
    }

    final picUrl = MusicApiClient.buildPicUrl(
      song.source.param,
      song.picId,
      size: 200,
    );
    final isPlaying = playerAsync.valueOrNull?.isPlaying ?? false;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Scrollable lyric body ────────────────────────────────────────
          Positioned.fill(
            child: LyricScrollView(
              songId: song.id,
              source: song.source.param,
              textAlign: TextAlign.center,
            ),
          ),

          // ── Top vignette (behind header fade) ───────────────────────────
          Positioned(
            top: 72,
            left: 0,
            right: 0,
            height: 128,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _kBg,
                      _kBg.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom vignette (above pill) ────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 192,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      _kBg,
                      _kBg.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Sticky header ────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: _kBg.withValues(alpha: 0.80),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SafeArea(
                        bottom: false,
                        child: SizedBox(
                          height: 60,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                // Back button
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Icon(
                                    Icons.arrow_back,
                                    color: _kAmber,
                                    size: 24,
                                  ),
                                ),
                                // Center: song info
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        song.artistDisplay,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _kAmber,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        song.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: _kBrown,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // More button
                                const Icon(
                                  Icons.more_vert,
                                  color: _kAmber,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Separator
                      Container(
                        height: 1,
                        color: _kBrown.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom player pill ───────────────────────────────────────────
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1C19).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _kAmber.withValues(alpha: 0.10),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26865213),
                        blurRadius: 32,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Album cover
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: picUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 40,
                            height: 40,
                            color: _kOnSurfaceVariant.withValues(alpha: 0.3),
                            child: const Icon(Icons.music_note,
                                color: _kBrown, size: 18),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 40,
                            height: 40,
                            color: _kOnSurfaceVariant.withValues(alpha: 0.3),
                            child: const Icon(Icons.music_note,
                                color: _kBrown, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Song info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              song.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kAmber,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artistDisplay.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _kBrown,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Play / Pause
                      GestureDetector(
                        onTap: () => ref
                            .read(playerNotifierProvider.notifier)
                            .togglePlay(),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: _kAmber,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Skip next
                      GestureDetector(
                        onTap: () =>
                            ref.read(playerNotifierProvider.notifier).skipToNext(),
                        child: const Icon(
                          Icons.skip_next,
                          color: _kBrown,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
