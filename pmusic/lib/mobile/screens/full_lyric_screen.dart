import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/player/player_notifier.dart';
import '../widgets/lyric_scroll_view.dart';

// ─── Design tokens (full_lyrics/code.html — dark mode) ───────────────────────

const _kBg = Color(0xFF2B1810);
const _kAmber = Color(0xFFE2A05B);
const _kBrown = Color(0xFF795548);

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
                                // right side: spacer to balance the back button
                                const SizedBox(width: 24),
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

          // ── Bottom player pill removed ───────────────────────────────────
        ],
      ),
    );
  }
}
