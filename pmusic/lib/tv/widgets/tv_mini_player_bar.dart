import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/enums.dart';
import '../../features/player/player_notifier.dart';
import '../screens/tv_full_player_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kSurface = Color(0xFFF5F3EE);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF5A5B58);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kOutline = Color(0xFF847467);

/// Persistent bottom player bar for the TV layout.
///
/// Matches the footer in `tv_play_queue/code.html` 1:1:
///  • `h-24` glassmorphic bar, `rounded-3xl`, `backdrop-blur-xl`
///  • Left (1/3): square album art (56dp) + title + artist
///  • Center (1/3): controls row (shuffle/prev/pause/next/repeat) + progress bar
///  • Right (1/3): mode tabs — "Now Playing" | "Controls" | "Queue" (active)
///
/// Invisible when no song is playing.
class TvMiniPlayerBar extends ConsumerWidget {
  const TvMiniPlayerBar({
    super.key,
    this.activeTab = TvPlayerTab.controls,
    this.onTabChanged,
  });

  final TvPlayerTab activeTab;
  final ValueChanged<TvPlayerTab>? onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerNotifierProvider);

    return playerAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (state) {
        final song = state.currentSong;
        if (song == null) return const SizedBox.shrink();

        final progress = state.duration.inMilliseconds > 0
            ? (state.position.inMilliseconds /
                    state.duration.inMilliseconds)
                .clamp(0.0, 1.0)
                .toDouble()
            : 0.0;
        final picUrl =
            MusicApiClient.buildPicUrl(song.source.param, song.picId);

        return Container(
          height: 96,
          margin: const EdgeInsets.fromLTRB(288, 0, 32, 32),
          padding: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _kSurface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF865213).withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Left: Track info ─────────────────────────────────────────
              Expanded(
                child: _buildTrackInfo(picUrl, song.name,
                    song.artistDisplay),
              ),

              // ── Center: Controls + progress ──────────────────────────────
              Expanded(
                child: _buildControls(state, progress, ref),
              ),

              // ── Right: Mode tabs ─────────────────────────────────────────
              Expanded(
                child: _buildTabs(context, ref),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Track info ─────────────────────────────────────────────────────────────

  Widget _buildTrackInfo(String picUrl, String title, String artist) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: picUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: picUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        _artPlaceholder(),
                    errorWidget: (_, _, _) =>
                        _artPlaceholder(),
                  )
                : _artPlaceholder(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kOnSurface,
                  fontFamily: 'Plus Jakarta Sans',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                artist,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kOutline,
                  letterSpacing: 0.8,
                  fontFamily: 'Be Vietnam Pro',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _artPlaceholder() => Container(
        color: const Color(0xFFE2A05B).withValues(alpha: 0.15),
        child: const Icon(Icons.music_note,
            color: Color(0xFFE2A05B), size: 24),
      );

  // ── Controls + progress ────────────────────────────────────────────────────

  Widget _buildControls(
      AppPlayerState state, double progress, WidgetRef ref) {
    final notifier = ref.read(playerNotifierProvider.notifier);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Controls row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BarButton(
              icon: Icons.shuffle,
              size: 22,
              color: state.playMode == PlayMode.shuffle
                  ? _kPrimary
                  : _kPrimary.withValues(alpha: 0.5),
              onTap: () => notifier.setPlayMode(PlayMode.shuffle),
            ),
            const SizedBox(width: 24),
            _BarButton(
              icon: Icons.skip_previous,
              size: 28,
              color: _kPrimary,
              onTap: () => notifier.skipToPrevious(),
            ),
            const SizedBox(width: 12),
            _BarButton(
              icon: state.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 44,
              color: _kPrimary,
              onTap: () => notifier.togglePlay(),
            ),
            const SizedBox(width: 12),
            _BarButton(
              icon: Icons.skip_next,
              size: 28,
              color: _kPrimary,
              onTap: () => notifier.skipToNext(),
            ),
            const SizedBox(width: 24),
            _BarButton(
              icon: state.playMode == PlayMode.repeatOne
                  ? Icons.repeat_one
                  : Icons.repeat,
              size: 22,
              color: (state.playMode == PlayMode.repeatAll ||
                      state.playMode == PlayMode.repeatOne)
                  ? _kPrimary
                  : _kPrimary.withValues(alpha: 0.5),
              onTap: () => notifier.setPlayMode(
                  (state.playMode == PlayMode.repeatAll ||
                          state.playMode == PlayMode.repeatOne)
                      ? PlayMode.sequence
                      : PlayMode.repeatAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar + timestamps
        Row(
          children: [
            Text(
              _fmt(state.position),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _kOutline,
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        const Color(0xFFE4E2DD),
                    color: _kPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _fmt(state.duration),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _kOutline,
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Mode tabs ──────────────────────────────────────────────────────────────

  Widget _buildTabs(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _TabButton(
          icon: Icons.music_note,
          label: 'Now Playing',
          active: activeTab == TvPlayerTab.nowPlaying,
          onTap: () {
            onTabChanged?.call(TvPlayerTab.nowPlaying);
            pushTvFullPlayer(context);
          },
        ),
        const SizedBox(width: 4),
        _TabButton(
          icon: Icons.play_circle_outline,
          label: 'Controls',
          active: activeTab == TvPlayerTab.controls,
          onTap: () => onTabChanged?.call(TvPlayerTab.controls),
        ),
        const SizedBox(width: 4),
        _TabButton(
          icon: Icons.queue_music,
          label: 'Queue',
          active: activeTab == TvPlayerTab.queue,
          onTap: () => onTabChanged?.call(TvPlayerTab.queue),
        ),
      ],
    );
  }
}

// ─── Tab enum ─────────────────────────────────────────────────────────────────

enum TvPlayerTab { nowPlaying, controls, queue }

// ─── Internal widgets ─────────────────────────────────────────────────────────

class _BarButton extends StatefulWidget {
  const _BarButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Icon(widget.icon, color: widget.color, size: widget.size),
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _focused || widget.active;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: widget.active
                ? const LinearGradient(
                    colors: [_kPrimary, _kPrimaryContainer],
                  )
                : null,
            color: highlighted && !widget.active
                ? _kSurface.withValues(alpha: 0.8)
                : null,
            borderRadius: BorderRadius.circular(16),
            border: highlighted && !widget.active
                ? Border.all(
                    color: _kPrimaryContainer.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.active
                    ? Colors.white
                    : _kOnSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.active
                      ? Colors.white
                      : _kOnSurfaceVariant,
                  letterSpacing: 1.0,
                  fontFamily: 'Be Vietnam Pro',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
