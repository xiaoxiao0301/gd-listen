import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../features/lyric/lyric_notifier.dart';
import '../../features/player/player_notifier.dart';
import '../../mobile/widgets/song_cover_image.dart';

// ─── Design tokens (tv_full_lyrics/code.html) ────────────────────────────────

const _kBg = Color(0xFF2B1810);
const _kBgEnd = Color(0xFF1B1C19);
const _kAmber = Color(0xFFE2A05B);
const _kBrand = Color(0xFF865213);
const _kBrown = Color(0xFF795548);
const _kMuted = Color(0xFFA0A19D);
const _kBarBg = Color(0xFF2C2D2A);
const _kPrimaryContainer = Color(0xFFE2A05B);

/// Full-screen lyric viewer for TV.
///
/// Design source: `picture/stitch/tv_full_lyrics/code.html`
///
/// Layout:
///  • Fixed header (96dp) — back + song title/artist + more button
///  • Main area: Left 1/3 album art with glow | Right 2/3 lyric scroll
///  • Lyric scroll: fade-mask top/bottom, scale-105 active line, opacities by distance
///  • Fixed bottom player bar (96dp) — controls + progress
class TvFullLyricScreen extends ConsumerStatefulWidget {
  const TvFullLyricScreen({super.key});

  @override
  ConsumerState<TvFullLyricScreen> createState() => _TvFullLyricScreenState();
}

class _TvFullLyricScreenState extends ConsumerState<TvFullLyricScreen> {
  List<GlobalKey>? _keys;

  void _scrollToActive(int index) {
    if (_keys == null || index >= (_keys?.length ?? 0)) return;
    final key = _keys![index];
    if (key.currentContext == null) return;
    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.5,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
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

    final isPlaying = playerAsync.valueOrNull?.isPlaying ?? false;
    final position = playerAsync.valueOrNull?.position ?? Duration.zero;
    final duration = playerAsync.valueOrNull?.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final lyricKey = (song.id, song.source.param);

    // Sync position to lyric notifier
    ref.listen<AsyncValue<AppPlayerState>>(playerNotifierProvider, (_, next) {
      next.whenData((s) {
        ref.read(lyricNotifierProvider(lyricKey).notifier).syncPosition(s.position);
      });
    });

    return Scaffold(
      backgroundColor: _kBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBg, _kBgEnd],
          ),
        ),
        child: Stack(
          children: [
            // ── Main content (header + split layout) ──────────────────────
            Column(
              children: [
                const SizedBox(height: 96), // header space
                Expanded(
                  child: Row(
                    children: [
                      // ── Left: album art ──────────────────────────────────
                      SizedBox(
                        width: MediaQuery.of(context).size.width / 3,
                        child: _buildAlbumArt(song.source.param, song.picId),
                      ),

                      // ── Right: lyric scroll ──────────────────────────────
                      Expanded(
                        child: _buildLyricScroll(lyricKey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 96), // player bar space
              ],
            ),

            // ── Fixed header ───────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 96,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: _kBg.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Row(
                      children: [
                        // Back button
                        _TvIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 24),
                        // Song info
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.name,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artistDisplay.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: _kMuted,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // More
                        const Icon(Icons.more_vert, color: _kMuted, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Fixed bottom player bar ────────────────────────────────────
            Positioned(
              bottom: 32,
              left: 48,
              right: 48,
              height: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kBarBg.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F865213),
                          blurRadius: 32,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _buildPlayerBar(
                      isPlaying: isPlaying,
                      position: position,
                      duration: duration,
                      progress: progress.toDouble(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumArt(String source, String picId) {
    return Padding(
      padding: const EdgeInsets.only(right: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glow + image
          Stack(
            alignment: Alignment.center,
            children: [
              // Amber glow behind image
              Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: _kBrand.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  margin: const EdgeInsets.all(-32),
                  decoration: BoxDecoration(
                    color: _kBrand.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Album cover with subtle rotation
              Transform.rotate(
                angle: 0.052, // ~3 degrees
                child: SongCover(
                  source: source,
                  picId: picId,
                  size: 600,
                  width: 320,
                  height: 320,
                  borderRadius: 16,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLyricScroll((String, String) lyricKey) {
    final lyricAsync = ref.watch(lyricNotifierProvider(lyricKey));

    // Auto-scroll when active line changes
    ref.listen<AsyncValue<LyricState>>(lyricNotifierProvider(lyricKey),
        (prev, next) {
      next.whenData((s) {
        if (prev?.valueOrNull?.currentIndex != s.currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToActive(s.currentIndex);
          });
        }
      });
    });

    return lyricAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kAmber, strokeWidth: 2)),
      error: (e, st) => const Center(
          child: Text('歌词加载失败', style: TextStyle(color: _kBrown))),
      data: (lyricState) {
        final lines = lyricState.lines;
        if (lines.isEmpty) {
          return const Center(
              child: Text('暂无歌词', style: TextStyle(color: _kBrown)));
        }

        if (_keys == null || _keys!.length != lines.length) {
          _keys = List.generate(lines.length, (_) => GlobalKey());
        }

        final current = lyricState.currentIndex;

        return ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.15, 0.85, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 160),
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final line = lines[i];
              final isActive = i == current;
              final distance = (i - current).abs();

              final double opacity;
              if (isActive) {
                opacity = 1.0;
              } else if (distance == 1) {
                opacity = 0.6;
              } else if (distance == 2) {
                opacity = 0.4;
              } else {
                opacity = 0.2;
              }

              return GestureDetector(
                key: _keys![i],
                onTap: () => ref
                    .read(playerNotifierProvider.notifier)
                    .seekTo(line.timestamp),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: AnimatedOpacity(
                    opacity: opacity,
                    duration: const Duration(milliseconds: 400),
                    child: AnimatedScale(
                      scale: isActive ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 400),
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Active line indicator + text row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (isActive) ...[
                                Container(
                                  width: 48,
                                  height: 1,
                                  color: _kPrimaryContainer,
                                ),
                                const SizedBox(width: 16),
                              ],
                              Expanded(
                                child: Text(
                                  line.original,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: isActive ? 40 : 22,
                                    fontWeight: isActive
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isActive ? _kAmber : _kBrown,
                                    height: 1.2,
                                    shadows: isActive
                                        ? [
                                            Shadow(
                                              color: _kAmber.withValues(
                                                  alpha: 0.4),
                                              blurRadius: 30,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Translation
                          if (line.translation != null &&
                              line.translation!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                top: 8,
                                left: isActive ? 64.0 : 0,
                              ),
                              child: Text(
                                line.translation!,
                                style: TextStyle(
                                  fontSize: isActive ? 24 : 18,
                                  fontWeight: FontWeight.w500,
                                  color: isActive
                                      ? _kAmber.withValues(alpha: 0.8)
                                      : _kBrown.withValues(alpha: 0.7),
                                  height: 1.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlayerBar({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required double progress,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Now Playing tab
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kBrand, _kAmber],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_note, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Controls + progress
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final s = ref
                            .read(playerNotifierProvider)
                            .valueOrNull;
                        if (s == null) return;
                        final next = s.playMode == PlayMode.shuffle
                            ? PlayMode.sequence
                            : PlayMode.shuffle;
                        ref
                            .read(playerNotifierProvider.notifier)
                            .setPlayMode(next);
                      },
                      child: Icon(
                        Icons.shuffle,
                        color: ref
                                    .watch(playerNotifierProvider)
                                    .valueOrNull
                                    ?.playMode ==
                                PlayMode.shuffle
                            ? _kAmber
                            : _kMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 28),
                    _TvControlButton(
                      icon: Icons.skip_previous,
                      onTap: () =>
                          ref.read(playerNotifierProvider.notifier).skipToPrevious(),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => ref
                          .read(playerNotifierProvider.notifier)
                          .togglePlay(),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: _kAmber,
                        size: 48,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _TvControlButton(
                      icon: Icons.skip_next,
                      onTap: () =>
                          ref.read(playerNotifierProvider.notifier).skipToNext(),
                    ),
                    const SizedBox(width: 28),
                    GestureDetector(
                      onTap: () {
                        final s = ref
                            .read(playerNotifierProvider)
                            .valueOrNull;
                        if (s == null) return;
                        final isRepeat = s.playMode ==
                                PlayMode.repeatAll ||
                            s.playMode == PlayMode.repeatOne;
                        ref
                            .read(playerNotifierProvider.notifier)
                            .setPlayMode(isRepeat
                                ? PlayMode.sequence
                                : PlayMode.repeatAll);
                      },
                      child: Icon(
                        ref
                                    .watch(playerNotifierProvider)
                                    .valueOrNull
                                    ?.playMode ==
                                PlayMode.repeatOne
                            ? Icons.repeat_one
                            : Icons.repeat,
                        color: (ref
                                        .watch(playerNotifierProvider)
                                        .valueOrNull
                                        ?.playMode ==
                                    PlayMode.repeatAll ||
                                ref
                                        .watch(playerNotifierProvider)
                                        .valueOrNull
                                        ?.playMode ==
                                    PlayMode.repeatOne)
                            ? _kAmber
                            : _kMuted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress slider
                Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(
                          fontSize: 11, color: _kMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: _kAmber,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.1),
                          thumbColor: Colors.white,
                          thumbShape:
                              const RoundSliderThumbShape(
                                  enabledThumbRadius: 7),
                          overlayColor:
                              _kAmber.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (v) {
                            final pos = Duration(
                              milliseconds:
                                  (v * duration.inMilliseconds)
                                      .round(),
                            );
                            ref
                                .read(playerNotifierProvider
                                    .notifier)
                                .seekTo(pos);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(
                          fontSize: 11, color: _kMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Controls / Queue tabs
          const _TvTabButton(icon: Icons.play_circle_outline, label: 'Controls'),
          const SizedBox(width: 8),
          const _TvTabButton(icon: Icons.queue_music, label: 'Queue'),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _TvIconButton extends StatefulWidget {
  const _TvIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_TvIconButton> createState() => _TvIconButtonState();
}

class _TvIconButtonState extends State<_TvIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _focused
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _TvControlButton extends StatefulWidget {
  const _TvControlButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_TvControlButton> createState() => _TvControlButtonState();
}

class _TvControlButtonState extends State<_TvControlButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Icon(
          widget.icon,
          color: _focused ? _kAmber : _kMuted,
          size: 32,
        ),
      ),
    );
  }
}

class _TvTabButton extends StatelessWidget {
  const _TvTabButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _kMuted, size: 20),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kMuted,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
