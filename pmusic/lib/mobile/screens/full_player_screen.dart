
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/enums.dart';
import '../../core/models/song.dart';
import '../../features/favorite/favorite_notifier.dart';
import '../../features/player/player_notifier.dart';
import '../widgets/lyric_scroll_view.dart';
import '../widgets/play_queue_drawer.dart';
import 'full_lyric_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kGradientTop = Color(0xFF5D3A1A);
const _kGradientMid = Color(0xFF865213);
const _kGradientBottom = Color(0xFFFFF8E7);
const _kAmber = Color(0xFFE2A05B);
const _kWhite90 = Color(0xE6FFFFFF);
const _kWhite60 = Color(0x99FFFFFF);
const _kWhite40 = Color(0x66FFFFFF);
const _kCreamy = Color(0xFFFFF8E7);
const _kAmberText = Color(0xFFEEC08A);
const _kOnPrimaryContainer = Color(0xFF613700);

/// Immersive full-screen player.
///
/// Matches the `full_player` Stitch design exactly:
///  • Gradient background: deep brown → amber → cream
///  • Vinyl-style circular cover (280dp) with slow rotation when playing
///  • Song title (22sp bold cream) + artist (15sp amber) + favorite button
///  • Custom progress slider (amber thumb with glow)
///  • Controls row: shuffle, skip_prev, play/pause (64dp amber), skip_next, repeat
///  • Lyrics preview area (3 lines, center active line in amber)
///  • "上滑查看全部歌词" hint at bottom
class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  IconData _playModeIcon(PlayMode mode) {
    return switch (mode) {
      PlayMode.shuffle => Icons.shuffle,
      PlayMode.repeatOne => Icons.repeat_one,
      PlayMode.repeatAll => Icons.repeat,
      PlayMode.sequence => Icons.shuffle,
    };
  }

  Color _playModeColor(PlayMode mode) {
    return switch (mode) {
      PlayMode.shuffle => _kAmber,
      PlayMode.repeatOne => _kAmber,
      PlayMode.repeatAll => _kAmber,
      PlayMode.sequence => _kWhite40,
    };
  }

  void _cyclePlayMode(PlayMode current) {
    final next = switch (current) {
      PlayMode.sequence => PlayMode.shuffle,
      PlayMode.shuffle => PlayMode.repeatAll,
      PlayMode.repeatAll => PlayMode.repeatOne,
      PlayMode.repeatOne => PlayMode.sequence,
    };
    ref.read(playerNotifierProvider.notifier).setPlayMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(playerNotifierProvider);
    final favoriteAsync = ref.watch(favoriteNotifierProvider);

    return playerAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => const _LoadingView(),
      data: (state) {
        final song = state.currentSong;
        if (song == null) {
          Navigator.of(context).maybePop();
          return const _LoadingView();
        }

        if (state.isPlaying) {
          _rotation.repeat();
        } else {
          _rotation.stop();
        }

        final isFav = favoriteAsync.valueOrNull?.isFavorite(song) ?? false;
        final progress = state.duration.inMilliseconds > 0
            ? (state.position.inMilliseconds /
                    state.duration.inMilliseconds)
                .clamp(0.0, 1.0)
                .toDouble()
            : 0.0;
        final picUrl =
            MusicApiClient.buildPicUrl(song.source.param, song.picId, size: 400);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 1.0],
                colors: [_kGradientTop, _kGradientMid, _kGradientBottom],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, state),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            const SizedBox(height: 32),
                            _buildAlbumCover(picUrl, song.name),
                            const SizedBox(height: 48),
                            _buildSongInfo(song, isFav),
                            const SizedBox(height: 32),
                            _buildProgressBar(state, progress),
                            const SizedBox(height: 32),
                            _buildControls(state),
                            const SizedBox(height: 32),
                            _buildLyricsPreview(context, song),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
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

  // ── Top header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AppPlayerState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.keyboard_arrow_down, color: _kWhite90, size: 28),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  '正在播放',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _kWhite60,
                    letterSpacing: 2,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'AmberMusic',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kWhite90,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showPlayQueueDrawer(context),
            child: const Icon(Icons.queue_music, color: _kWhite90, size: 24),
          ),
        ],
      ),
    );
  }

  // ── Vinyl album cover ──────────────────────────────────────────────────────

  Widget _buildAlbumCover(String picUrl, String songName) {
    return RotationTransition(
      turns: _rotation,
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1B1C19),
          boxShadow: [
            BoxShadow(
              color: _kGradientMid.withValues(alpha: 0.4),
              blurRadius: 50,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Album art (square inside circle)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 228,
                height: 228,
                child: picUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: picUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _buildCoverPlaceholder(),
                        errorWidget: (_, _, _) => _buildCoverPlaceholder(),
                      )
                    : _buildCoverPlaceholder(),
              ),
            ),
            // Vinyl groove ring texture
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.48, 0.50, 0.52],
                ),
              ),
            ),
            // Center spindle hole
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: _kAmber.withValues(alpha: 0.15),
      child: const Icon(Icons.music_note, color: _kAmber, size: 64),
    );
  }

  // ── Song info row ──────────────────────────────────────────────────────────

  Widget _buildSongInfo(Song song, bool isFav) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kCreamy,
                  fontFamily: 'Plus Jakarta Sans',
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                song.album.isNotEmpty
                    ? '${song.artistDisplay} • ${song.album}'
                    : song.artistDisplay,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _kAmberText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () => ref.read(favoriteNotifierProvider.notifier).toggle(song),
          child: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: _kAmber,
            size: 28,
          ),
        ),
      ],
    );
  }

  // ── Progress bar ───────────────────────────────────────────────────────────

  Widget _buildProgressBar(AppPlayerState state, double progress) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: _kAmber,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: _kAmber,
            thumbShape: const _GlowingThumbShape(radius: 8),
            overlayColor: _kAmber.withValues(alpha: 0.15),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: progress,
            onChanged: (v) {
              final newPos = Duration(
                milliseconds:
                    (v * state.duration.inMilliseconds).round(),
              );
              ref.read(playerNotifierProvider.notifier).seekTo(newPos);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(state.position),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _kWhite60,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                _formatDuration(state.duration),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _kWhite60,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Playback controls ──────────────────────────────────────────────────────

  Widget _buildControls(AppPlayerState state) {
    final notifier = ref.read(playerNotifierProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle / play-mode toggle
        GestureDetector(
          onTap: () => _cyclePlayMode(state.playMode),
          child: Icon(
            _playModeIcon(state.playMode),
            color: _playModeColor(state.playMode),
            size: 26,
          ),
        ),
        // Previous
        GestureDetector(
          onTap: () => notifier.skipToPrevious(),
          child: const Icon(
            Icons.skip_previous,
            color: _kWhite90,
            size: 40,
          ),
        ),
        // Play / Pause (64dp amber circle)
        GestureDetector(
          onTap: () => notifier.togglePlay(),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kAmber,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kAmber.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              state.isPlaying ? Icons.pause : Icons.play_arrow,
              color: _kOnPrimaryContainer,
              size: 36,
            ),
          ),
        ),
        // Next
        GestureDetector(
          onTap: () => notifier.skipToNext(),
          child: const Icon(
            Icons.skip_next,
            color: _kWhite90,
            size: 40,
          ),
        ),
        // Repeat toggle (activated when repeatAll or repeatOne)
        GestureDetector(
          onTap: () {
            final next = state.playMode == PlayMode.repeatAll ||
                    state.playMode == PlayMode.repeatOne
                ? PlayMode.sequence
                : PlayMode.repeatAll;
            notifier.setPlayMode(next);
          },
          child: Icon(
            state.playMode == PlayMode.repeatOne
                ? Icons.repeat_one
                : Icons.repeat,
            color: (state.playMode == PlayMode.repeatAll ||
                    state.playMode == PlayMode.repeatOne)
                ? _kAmber
                : _kWhite40,
            size: 26,
          ),
        ),
      ],
    );
  }

  // ── Lyrics preview ─────────────────────────────────────────────────────────

  Widget _buildLyricsPreview(BuildContext context, Song song) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FullLyricScreen()),
      ),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -200) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FullLyricScreen()),
          );
        }
      },
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: LyricScrollView(
              songId: song.id,
              source: song.source.param,
              previewMode: true,
              // Design (full_player): active line = text-primary = #865213
              activeLineColor: _kGradientMid,
            ),
          ),
          const SizedBox(height: 20),
          const Column(
            children: [
              Text(
                '上滑查看全部歌词',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _kAmber,
                  letterSpacing: 2.5,
                ),
              ),
              SizedBox(height: 4),
              Icon(
                Icons.keyboard_double_arrow_up,
                color: _kAmber,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Custom glowing thumb shape ──────────────────────────────────────────────

class _GlowingThumbShape extends SliderComponentShape {
  const _GlowingThumbShape({this.radius = 8});
  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    // Glow
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color = _kAmber.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Thumb
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = _kAmber,
    );
    // White border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

// ─── Loading placeholder ─────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

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

/// Push [FullPlayerScreen] from any Navigator context.
void pushFullPlayer(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const FullPlayerScreen(),
      transitionsBuilder: (_, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    ),
  );
}


