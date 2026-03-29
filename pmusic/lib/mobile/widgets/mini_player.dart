import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../features/player/player_notifier.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kGlass = Color(0xF0F5F3EE);       // #f5f3ee / 90% opacity
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kPrimary = Color(0xFFE2A05B);
const _kBrand = Color(0xFF865213);
const double kMiniPlayerHeight = 72.0;   // total slot height incl. margins

/// Glassmorphism mini player that floats above the bottom navigation bar.
///
/// Shows the currently playing song — hidden when no song is loaded.
/// Tapping the player body will eventually navigate to FullPlayerScreen (P1-09).
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key, this.onTap});

  /// Callback invoked when user taps the player body — used by AppShell
  /// to open the full player screen.
  final VoidCallback? onTap;

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(playerNotifierProvider);

    return playerAsync.when(
      data: (state) {
        if (state.currentSong == null) return const SizedBox.shrink();

        if (state.isPlaying) {
          _rotation.repeat();
        } else {
          _rotation.stop();
        }

        final song = state.currentSong!;
        final progress = state.duration.inMilliseconds > 0
            ? (state.position.inMilliseconds /
                    state.duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

        final picUrl =
            MusicApiClient.buildPicUrl(song.source.param, song.picId);

        return GestureDetector(
            onTap: widget.onTap,
            // Up-swipe navigates to full player screen.
            onVerticalDragEnd: (details) {
              if (details.velocity.pixelsPerSecond.dy < -200) {
                widget.onTap?.call();
              }
            },
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: kMiniPlayerHeight,
                  decoration: const BoxDecoration(
                    color: _kGlass,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A865213),
                        blurRadius: 24,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // ── Progress bar (thin bottom line) ────────────────
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.15),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(color: _kPrimary),
                          ),
                        ),
                      ),

                      // ── Content row ────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Rotating circular cover
                            RotationTransition(
                              turns: _rotation,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _kPrimary
                                        .withValues(alpha: 0.20),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: picUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: picUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) =>
                                              _MusicDisc(),
                                          errorWidget: (_, _, _) =>
                                              _MusicDisc(),
                                        )
                                      : _MusicDisc(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Song info
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _kOnSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    song.artistDisplay,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _kOnSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Play / Pause button
                            GestureDetector(
                              onTap: () => ref
                                  .read(playerNotifierProvider.notifier)
                                  .togglePlay(),
                              child: Icon(
                                state.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: _kBrand,
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Skip next button
                            GestureDetector(
                              onTap: () => ref
                                  .read(playerNotifierProvider.notifier)
                                  .skipToNext(),
                              child: const Icon(
                                Icons.skip_next_rounded,
                                color: _kBrand,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _MusicDisc extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kPrimary.withValues(alpha: 0.15),
      child: const Icon(Icons.music_note, color: _kPrimary, size: 20),
    );
  }
}
