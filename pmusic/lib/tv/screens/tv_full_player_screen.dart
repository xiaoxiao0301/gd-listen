import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/enums.dart';
import '../../core/models/song.dart';
import '../../features/player/player_notifier.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kGradientTop = Color(0xFF5D3A1A);
const _kGradientMid = Color(0xFF865213);
const _kGradientBottom = Color(0xFFFBF9F3);
const _kAmber = Color(0xFFE2A05B);
const _kWhite = Color(0xFFFFFFFF);
const _kWhite70 = Color(0xB3FFFFFF);
const _kOnPrimaryContainer = Color(0xFF613700);

/// TV full-screen immersive player.
///
/// Matches `tv_full_player_aligned` design exactly:
///  • Immersive gradient background (deep brown → amber → cream)
///  • Left 45%: rounded album cover 500dp with amber glow shadow
///  • Right 55%: title (56sp extrabold white), artist (32sp amber),
///    progress bar (8dp height amber fill), controls (shuffle, prev,
///    128dp play/pause, next, repeat), lyrics preview (3 lines with mask)
///  • Top-right: volume indicator + clock
///  • 3-second auto-hide for controls area
///  • Media key support (play/pause, skip)
class TvFullPlayerScreen extends ConsumerStatefulWidget {
  const TvFullPlayerScreen({super.key});

  @override
  ConsumerState<TvFullPlayerScreen> createState() =>
      _TvFullPlayerScreenState();
}

class _TvFullPlayerScreenState extends ConsumerState<TvFullPlayerScreen> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  final double _volume = 0.8;

  @override
  void initState() {
    super.initState();
    _resetHideTimer();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    _resetHideTimer();

    final notifier = ref.read(playerNotifierProvider.notifier);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.mediaPlay:
      case LogicalKeyboardKey.mediaPause:
      case LogicalKeyboardKey.mediaPlayPause:
      case LogicalKeyboardKey.space:
        notifier.togglePlay();
        return true;
      case LogicalKeyboardKey.mediaTrackNext:
      case LogicalKeyboardKey.arrowRight:
        notifier.skipToNext();
        return true;
      case LogicalKeyboardKey.mediaTrackPrevious:
      case LogicalKeyboardKey.arrowLeft:
        notifier.skipToPrevious();
        return true;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        Navigator.of(context).maybePop();
        return true;
      default:
        return false;
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(playerNotifierProvider);
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return playerAsync.when(
      loading: () => const _TvLoadingView(),
      error: (_, _) => const _TvLoadingView(),
      data: (state) {
        final song = state.currentSong;
        if (song == null) {
          Navigator.of(context).maybePop();
          return const _TvLoadingView();
        }

        final progress = state.duration.inMilliseconds > 0
            ? (state.position.inMilliseconds /
                    state.duration.inMilliseconds)
                .clamp(0.0, 1.0)
                .toDouble()
            : 0.0;
        final coverUrl = MusicApiClient.buildPicUrl(
          song.source.param,
          song.picId,
          size: 500,
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            onTap: _resetHideTimer,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.4, 1.0],
                  colors: [_kGradientTop, _kGradientMid, _kGradientBottom],
                ),
              ),
              child: Stack(
                children: [
                  // ── Main two-column layout ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 96, vertical: 64),
                    child: Row(
                      children: [
                        // Left 45%: Album cover
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.45 - 96,
                          child: Center(
                            child: _buildAlbumCover(coverUrl),
                          ),
                        ),
                        // Right 55%: Info + Controls
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 48),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSongInfo(song),
                                const SizedBox(height: 48),
                                _buildProgressBar(state, progress),
                                const SizedBox(height: 64),
                                AnimatedOpacity(
                                  opacity: _controlsVisible ? 1.0 : 0.2,
                                  duration:
                                      const Duration(milliseconds: 500),
                                  child: _buildControls(state),
                                ),
                                const SizedBox(height: 80),
                                _buildLyricsPreview(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Top-right overlay: volume + clock ──────────────────
                  Positioned(
                    top: 48,
                    right: 48,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Volume indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.volume_up,
                                  color: _kWhite70, size: 22),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 96,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: _volume,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.2),
                                    color: _kWhite,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Clock
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: _kWhite70,
                              fontFamily: 'Be Vietnam Pro',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Album cover ────────────────────────────────────────────────────────────

  Widget _buildAlbumCover(String url) {
    return Container(
      width: 500,
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: _kGradientMid.withValues(alpha: 0.6),
            blurRadius: 60,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: _kAmber.withValues(alpha: 0.15),
                  child: const Icon(Icons.music_note,
                      color: _kAmber, size: 80),
                ),
                errorWidget: (_, _, _) => Container(
                  color: _kAmber.withValues(alpha: 0.15),
                  child: const Icon(Icons.music_note,
                      color: _kAmber, size: 80),
                ),
              )
            : Container(
                color: _kAmber.withValues(alpha: 0.15),
                child: const Icon(Icons.music_note,
                    color: _kAmber, size: 80),
              ),
      ),
    );
  }

  // ── Song info ──────────────────────────────────────────────────────────────

  Widget _buildSongInfo(Song song) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song.name,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w800,
            color: _kWhite,
            fontFamily: 'Plus Jakarta Sans',
            height: 1.1,
            letterSpacing: -1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        Text(
          song.album.isNotEmpty
              ? '${song.artistDisplay} • ${song.album}'
              : song.artistDisplay,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: _kAmber,
            fontFamily: 'Plus Jakarta Sans',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── Progress bar ───────────────────────────────────────────────────────────

  Widget _buildProgressBar(AppPlayerState state, double progress) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(state.position),
              style: TextStyle(
                fontSize: 18,
                color: _kWhite.withValues(alpha: 0.7),
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
            Text(
              _formatDuration(state.duration),
              style: TextStyle(
                fontSize: 18,
                color: _kWhite.withValues(alpha: 0.7),
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 8,
            activeTrackColor: _kAmber,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: _kAmber,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayColor: _kAmber.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: progress,
            onChanged: (v) {
              final pos = Duration(
                milliseconds:
                    (v * state.duration.inMilliseconds).round(),
              );
              ref.read(playerNotifierProvider.notifier).seekTo(pos);
            },
          ),
        ),
      ],
    );
  }

  // ── Playback controls ──────────────────────────────────────────────────────

  Widget _buildControls(AppPlayerState state) {
    final notifier = ref.read(playerNotifierProvider.notifier);
    final isRepeat = state.playMode == PlayMode.repeatAll ||
        state.playMode == PlayMode.repeatOne;

    return Row(
      children: [
        // Shuffle
        _TvControlButton(
          icon: Icons.shuffle,
          size: 40,
          color: state.playMode == PlayMode.shuffle
              ? _kWhite
              : _kWhite.withValues(alpha: 0.5),
          onTap: () => notifier.setPlayMode(PlayMode.shuffle),
        ),
        const SizedBox(width: 40),
        // Previous
        _TvControlButton(
          icon: Icons.skip_previous,
          size: 50,
          color: _kWhite,
          onTap: () => notifier.skipToPrevious(),
        ),
        const SizedBox(width: 40),
        // Play / Pause (128dp)
        _TvControlButton(
          icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
          size: 72,
          color: _kOnPrimaryContainer,
          background: _kAmber,
          buttonSize: 128,
          onTap: () => notifier.togglePlay(),
        ),
        const SizedBox(width: 40),
        // Next
        _TvControlButton(
          icon: Icons.skip_next,
          size: 50,
          color: _kWhite,
          onTap: () => notifier.skipToNext(),
        ),
        const SizedBox(width: 40),
        // Repeat
        _TvControlButton(
          icon: state.playMode == PlayMode.repeatOne
              ? Icons.repeat_one
              : Icons.repeat,
          size: 40,
          color: isRepeat ? _kAmber : _kWhite.withValues(alpha: 0.5),
          onTap: () => notifier.setPlayMode(
              isRepeat ? PlayMode.sequence : PlayMode.repeatAll),
        ),
      ],
    );
  }

  // ── Lyrics preview ─────────────────────────────────────────────────────────

  Widget _buildLyricsPreview() {
    // Placeholder 3-line preview — replaced with real lyric data in P2-09
    const lines = [
      ('落叶在风中寻找归宿', false),
      ('音符编织成触手可及的温度', true),
      ('时光在胶片的纹理中慢行', false),
    ];

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.2, 0.8, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: Column(
        children: lines.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              entry.$1,
              style: TextStyle(
                fontSize: entry.$2 ? 40 : 26,
                fontWeight:
                    entry.$2 ? FontWeight.w700 : FontWeight.w500,
                color: entry.$2
                    ? _kAmber
                    : Colors.black.withValues(alpha: 0.3),
                letterSpacing: entry.$2 ? 1.5 : 0.5,
                height: 1.3,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Reusable TV focus button ─────────────────────────────────────────────────

class _TvControlButton extends StatefulWidget {
  const _TvControlButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
    this.background,
    this.buttonSize,
  });

  final IconData icon;
  final double size;
  final Color color;
  final Color? background;
  final double? buttonSize;
  final VoidCallback onTap;

  @override
  State<_TvControlButton> createState() => _TvControlButtonState();
}

class _TvControlButtonState extends State<_TvControlButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.background;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.buttonSize,
          height: widget.buttonSize,
          padding: widget.buttonSize == null
              ? const EdgeInsets.all(16)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: bg ??
                (_focused ? Colors.white.withValues(alpha: 0.15) : null),
            shape: bg != null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: bg == null ? BorderRadius.circular(16) : null,
            border: _focused && bg == null
                ? Border.all(
                    color: _kAmber.withValues(alpha: 0.6), width: 3)
                : null,
          ),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

// ─── Loading placeholder ─────────────────────────────────────────────────────

class _TvLoadingView extends StatelessWidget {
  const _TvLoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kGradientTop, _kGradientMid],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _kAmber),
      ),
    );
  }
}

// ─── Route helper ────────────────────────────────────────────────────────────

void pushTvFullPlayer(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const TvFullPlayerScreen(),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    ),
  );
}
