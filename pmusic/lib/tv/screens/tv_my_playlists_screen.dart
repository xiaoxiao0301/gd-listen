import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/playlist.dart';
import '../../features/playlist/playlist_notifier.dart';
import '../../core/models/song.dart';
import 'tv_playlist_detail_screen.dart';

// ─── Design tokens (tv_my_playlists/code.html) ───────────────────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kOnPrimaryContainer = Color(0xFF613700);
const _kOutlineVariant = Color(0xFFD6C3B4);

/// TV playlists screen content area.
///
/// Matches `tv_my_playlists/code.html` design 1:1:
///  • Header with "My Playlists" + "Personal Curations" heading + create button
///  • 3-column responsive grid of playlist cards
///  • Each card: square cover, title, count; focus ring on TV D-pad
///  • Create playlist: dialog opened via amber gradient button
class TvMyPlaylistsScreen extends ConsumerWidget {
  const TvMyPlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(playlistNotifierProvider);

    return Container(
      color: _kBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 64, 48, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Title block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Playlists',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: _kPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Personal Curations',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          color: _kOnSurface,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Create playlist button
                _TvCreateButton(
                  onTap: () => _showCreateDialog(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // ── Grid ─────────────────────────────────────────────────────────
          Expanded(
            child: playlistAsync.when(
              data: (state) {
                if (state.playlists.isEmpty) {
                  return _EmptyState(
                    onCreateTap: () => _showCreateDialog(context, ref),
                  );
                }
                return _PlaylistGrid(
                  playlists: state.playlists,
                  onTap: (pl) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TvPlaylistDetailScreen(
                          playlistId: pl.id,
                          playlistName: pl.name,
                        ),
                      ),
                    );
                  },
                  onLongPress: (pl) =>
                      _showPlaylistActions(context, ref, pl),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: _kPrimaryContainer),
              ),
              error: (e, _) => Center(
                child: Text(
                  '加载失败: $e',
                  style: const TextStyle(
                      color: _kOnSurfaceVariant, fontSize: 20),
                ),
              ),
            ),
          ),

          // ── Bottom player bar padding ──────────────────────────────────
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  // ── Dialog helpers ─────────────────────────────────────────────────────────

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '新建歌单',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _kOnSurface,
          ),
        ),
        content: SizedBox(
          width: 480,
          child: Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter) {
                final name = ctrl.text.trim();
                if (name.isNotEmpty) {
                  ref
                      .read(playlistNotifierProvider.notifier)
                      .create(name);
                  Navigator.pop(ctx);
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(
                  color: _kOnSurface, fontSize: 18),
              decoration: InputDecoration(
                hintText: '歌单名称',
                hintStyle: const TextStyle(color: _kOutlineVariant),
                filled: true,
                fillColor: _kSurfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: _kPrimaryContainer, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(
                    color: _kOnSurfaceVariant, fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(playlistNotifierProvider.notifier)
                    .create(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('创建',
                style: TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showPlaylistActions(
      BuildContext context, WidgetRef ref, Playlist playlist) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Text(
          playlist.name,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _kOnSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.edit_outlined, color: _kPrimary),
              title: const Text('重命名',
                  style: TextStyle(fontSize: 18, color: _kOnSurface)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, ref, playlist);
              },
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFBA1A1A)),
              title: const Text('删除歌单',
                  style: TextStyle(
                      fontSize: 18, color: Color(0xFFBA1A1A))),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(playlistNotifierProvider.notifier)
                    .delete(playlist.id);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(
                    color: _kOnSurfaceVariant, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, Playlist playlist) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '重命名',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _kOnSurface,
          ),
        ),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: _kOnSurface, fontSize: 18),
            decoration: InputDecoration(
              filled: true,
              fillColor: _kSurfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: _kPrimaryContainer, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: _kOnSurfaceVariant, fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(playlistNotifierProvider.notifier)
                    .rename(playlist.id, name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存',
                style: TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ─── Create button (gradient, TV style) ──────────────────────────────────────

class _TvCreateButton extends StatefulWidget {
  const _TvCreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_TvCreateButton> createState() => _TvCreateButtonState();
}

class _TvCreateButtonState extends State<_TvCreateButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimary, _kPrimaryContainer],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: _focused
                ? Border.all(color: Colors.white, width: 3)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.add, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Create Playlist',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Playlist grid ────────────────────────────────────────────────────────────

class _PlaylistGrid extends StatelessWidget {
  const _PlaylistGrid({
    required this.playlists,
    required this.onTap,
    required this.onLongPress,
  });

  final List<Playlist> playlists;
  final ValueChanged<Playlist> onTap;
  final ValueChanged<Playlist> onLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 40,
        mainAxisSpacing: 40,
        childAspectRatio: 0.78, // cover square + title/count below
      ),
      itemCount: playlists.length,
      itemBuilder: (ctx, i) => _PlaylistCard(
        playlist: playlists[i],
        onTap: () => onTap(playlists[i]),
        onLongPress: () => onLongPress(playlists[i]),
      ),
    );
  }
}

// ─── Individual playlist card ─────────────────────────────────────────────────

class _PlaylistCard extends ConsumerStatefulWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onLongPress,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  ConsumerState<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends ConsumerState<_PlaylistCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final coverAsync =
        ref.watch(playlistFirstSongProvider(widget.playlist.id));
    final highlighted = _focused || _hovered;

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: highlighted ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: _focused
                    ? Border.all(
                        color: _kPrimaryContainer,
                        width: 4,
                      )
                    : null,
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: _kPrimaryContainer.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Square cover ──────────────────────────────────────
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover image
                          _CardCover(
                            coverAsync: coverAsync,
                            playlistId: widget.playlist.id,
                            zoomed: highlighted,
                          ),
                          // Dark overlay (fades on hover)
                          AnimatedOpacity(
                            opacity: highlighted ? 0.0 : 0.10,
                            duration: const Duration(milliseconds: 200),
                            child: const ColoredBox(color: Colors.black),
                          ),
                          // Play button (appears on focus/hover)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: AnimatedOpacity(
                              opacity: highlighted ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: _kPrimary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x40865213),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Title + count ─────────────────────────────────────
                    Container(
                      color: _kBackground,
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.playlist.name,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: highlighted
                                  ? _kPrimary
                                  : _kOnSurface,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.playlist.songCount} Tracks',
                            style: const TextStyle(
                              fontSize: 16,
                              color: _kOnSurfaceVariant,
                              height: 1.3,
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
        ),
      ),
    );
  }
}

// ─── Card cover (animates scale on focus/hover) ───────────────────────────────

class _CardCover extends StatelessWidget {
  const _CardCover({
    required this.coverAsync,
    required this.playlistId,
    required this.zoomed,
  });

  final AsyncValue<Object?> coverAsync;
  final int playlistId;
  final bool zoomed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: AnimatedScale(
        scale: zoomed ? 1.10 : 1.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        child: coverAsync.when(
          data: (song) {
            if (song == null) return _placeholder(playlistId);
            final s = song as Song;
            final url = MusicApiClient.buildPicUrl(
              s.source.param,
              s.picId,
              size: 400,
            );
            if (url.isEmpty) return _placeholder(playlistId);
            return CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, _) => _placeholder(playlistId),
              errorWidget: (_, _, _) => _placeholder(playlistId),
            );
          },
          loading: () => _placeholder(playlistId),
          error: (_, _) => _placeholder(playlistId),
        ),
      ),
    );
  }

  static Widget _placeholder(int id) {
    final colors = _gradientPairs[id.abs() % _gradientPairs.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.library_music, color: Colors.white60, size: 64),
      ),
    );
  }

  static const List<List<Color>> _gradientPairs = [
    [Color(0xFFE2A05B), Color(0xFF865213)],
    [Color(0xFFB87333), Color(0xFF5D3A1A)],
    [Color(0xFFD4956B), Color(0xFF8B4513)],
    [Color(0xFFE8C49E), Color(0xFFBF7038)],
    [Color(0xFFC18240), Color(0xFF6B3A1F)],
    [Color(0xFFEBB577), Color(0xFF9C5E2B)],
  ];
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: _kSurfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.library_music,
              color: _kPrimary,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '还没有歌单',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _kOnSurface,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '点击右上角按钮创建你的第一个歌单',
            style: TextStyle(
              fontSize: 18,
              color: _kOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Focus(
            child: GestureDetector(
              onTap: onCreateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: _kPrimaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '立即创建',
                  style: TextStyle(
                    color: _kOnPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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
