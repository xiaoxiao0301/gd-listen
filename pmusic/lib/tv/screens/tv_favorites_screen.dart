import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/song.dart';
import '../../features/favorite/favorite_notifier.dart';
import '../../features/player/player_notifier.dart';

// ─── Design tokens (tv_favorites_aligned/code.html) ──────────────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLowest = Color(0xFFFFFFFF);
const _kSurfaceContainer = Color(0xFFF0EEE8);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kHeart = Color(0xFFE57373);

/// TV Favorites content screen.
///
/// Matches `tv_favorites_aligned/code.html` design 1:1 (content area only —
/// sidebar is provided by TvAppShell):
///  • Header: "我的收藏" (extrabold 48sp) + song count subtitle
///    + "全部播放" (gradient pill) + "随机播放" (neutral pill)
///  • 6-column grid of favorite song cards
///  • Each card: square cover, song title, artist, red heart overlay top-right
///  • Focus: amber outline + scale 1.05 on D-pad
class TvFavoritesScreen extends ConsumerWidget {
  const TvFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(favoriteNotifierProvider);

    return Container(
      color: _kBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 64, 48, 0),
            child: favAsync.when(
              data: (state) => _Header(
                songCount: state.songs.length,
                onPlayAll: state.songs.isEmpty
                    ? null
                    : () => ref
                        .read(playerNotifierProvider.notifier)
                        .setQueue(state.songs),
                onShuffle: state.songs.isEmpty
                    ? null
                    : () {
                        final shuffled = [...state.songs]
                          ..shuffle(Random());
                        ref
                            .read(playerNotifierProvider.notifier)
                            .setQueue(shuffled);
                      },
              ),
              loading: () => const _Header(songCount: 0),
              error: (_, _) => const _Header(songCount: 0),
            ),
          ),

          const SizedBox(height: 40),

          // ── Grid ─────────────────────────────────────────────────────────
          Expanded(
            child: favAsync.when(
              data: (state) => state.songs.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有收藏的歌曲',
                        style: TextStyle(
                          color: _kOnSurfaceVariant,
                          fontSize: 22,
                        ),
                      ),
                    )
                  : Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 48),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: state.songs.length,
                        itemBuilder: (ctx, index) => _FavCard(
                          song: state.songs[index],
                          onTap: () => ref
                              .read(playerNotifierProvider.notifier)
                              .setQueue(state.songs,
                                  startIndex: index),
                          onUnfavorite: () => ref
                              .read(favoriteNotifierProvider.notifier)
                              .toggle(state.songs[index]),
                        ),
                      ),
                    ),
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: _kPrimaryContainer),
              ),
              error: (e, _) => Center(
                child: Text('加载失败: $e',
                    style: const TextStyle(
                        color: _kOnSurfaceVariant, fontSize: 20)),
              ),
            ),
          ),

          // ── Bottom player bar padding ──────────────────────────────────
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.songCount,
    this.onPlayAll,
    this.onShuffle,
  });

  final int songCount;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '我的收藏',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  color: _kOnSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '这里存放着你最感动的每一个瞬间，共 $songCount 首曲目。',
                style: const TextStyle(
                  fontSize: 16,
                  color: _kOnSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
        Row(
          children: [
            _HeaderButton(
              label: '全部播放',
              icon: Icons.play_arrow,
              gradient: const LinearGradient(
                  colors: [_kPrimary, _kPrimaryContainer]),
              textColor: Colors.white,
              onTap: onPlayAll,
            ),
            const SizedBox(width: 16),
            _HeaderButton(
              label: '随机播放',
              icon: Icons.shuffle,
              backgroundColor: _kSurfaceContainer,
              textColor: _kPrimary,
              onTap: onShuffle,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderButton extends StatefulWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    this.gradient,
    this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _focused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: _focused
                  ? Border.all(color: _kPrimary, width: 4)
                  : null,
              boxShadow: widget.gradient != null
                  ? [
                      BoxShadow(
                        color: const Color(0xFF865213)
                            .withValues(alpha: 0.15),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.textColor, size: 22),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: widget.textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Favorite Card ────────────────────────────────────────────────────────────

class _FavCard extends StatefulWidget {
  const _FavCard({
    required this.song,
    required this.onTap,
    required this.onUnfavorite,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback onUnfavorite;

  @override
  State<_FavCard> createState() => _FavCardState();
}

class _FavCardState extends State<_FavCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final picUrl = MusicApiClient.buildPicUrl(
        widget.song.source.param, widget.song.picId,
        size: 300);

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kSurfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: _focused
                ? Border.all(color: _kPrimary, width: 4)
                : null,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color:
                          _kPrimary.withValues(alpha: 0.35),
                      blurRadius: 24,
                    ),
                  ]
                : null,
          ),
          child: AnimatedScale(
            scale: _focused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Square cover
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: picUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: picUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    const _CardPlaceholder(),
                                errorWidget: (_, _, _) =>
                                    const _CardPlaceholder(),
                              )
                            : const _CardPlaceholder(),
                      ),
                      // Heart badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: widget.onUnfavorite,
                          child: const Icon(
                            Icons.favorite,
                            color: _kHeart,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  widget.song.name,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _kOnSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.song.artistDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    color: _kOnSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD49A5A), Color(0xFFBF7340)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.music_note, color: Colors.white54, size: 32),
        ),
      );
}
