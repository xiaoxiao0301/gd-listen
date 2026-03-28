import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../features/player/player_notifier.dart';
import '../../features/playlist/playlist_notifier.dart';
import '../widgets/mini_player.dart';
import 'playlist_detail_screen.dart';

// ─── Design tokens (my_playlists/code.html) ──────────────────────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLowest = Color(0xFFFFFFFF);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kSurfaceContainerHighest = Color(0xFFE4E2DD);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kOnPrimaryContainer = Color(0xFF613700);
const _kOutlineVariant = Color(0xFFD6C3B4);

/// Mobile playlist-list screen.
///
/// Matches `my_playlists/code.html` design 1:1:
///  • Sticky top nav with back, title, + (create) and more_vert buttons
///  • Editorial header: "COLLECTIONS" label + "Personal Curations" heading
///  • Scrollable list of playlist cards (72px cover, title, song count, chevron)
///  • "探索更多" promo section at bottom
///  • Long-press any card → rename / delete action sheet
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(playlistNotifierProvider);
    final hasMiniPlayer =
        ref.watch(playerNotifierProvider).valueOrNull?.currentSong != null;

    return Scaffold(
      backgroundColor: _kBackground,
      body: CustomScrollView(
        slivers: [
          // ── Sticky top navigation ───────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: _kBackground,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(Icons.arrow_back,
                        color: _kPrimary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '我的歌单',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: _kOnSurface,
                      ),
                    ),
                  ),
                  // Create playlist button
                  GestureDetector(
                    onTap: () => _showCreateDialog(context, ref),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kPrimary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.more_vert, color: _kPrimary, size: 24),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: _kSurfaceContainerLow.withValues(alpha: 0.10),
              ),
            ),
          ),

          // ── Editorial header ────────────────────────────────────────────
          const SliverToBoxAdapter(child: _EditorialHeader()),

          // ── Playlist list ───────────────────────────────────────────────
          playlistAsync.when(
            data: (state) {
              if (state.playlists.isEmpty) {
                return const SliverToBoxAdapter(child: _EmptyPlaylistHint());
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final pl = state.playlists[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              index < state.playlists.length - 1 ? 12 : 0,
                        ),
                        child: _PlaylistCard(
                          playlist: pl,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PlaylistDetailScreen(
                                  playlistId: pl.id,
                                  playlistName: pl.name,
                                ),
                              ),
                            );
                          },
                          onLongPress: () =>
                              _showPlaylistActions(context, ref, pl),
                        ),
                      );
                    },
                    childCount: state.playlists.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(
                    color: _kPrimaryContainer,
                  ),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '加载失败: $e',
                  style: const TextStyle(
                      color: _kOnSurfaceVariant, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // ── "探索更多" promo section ─────────────────────────────────────
          const SliverToBoxAdapter(child: _ExploreMoreSection()),

          // ── Bottom padding above mini player + nav ───────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: hasMiniPlayer ? kMiniPlayerHeight + 72 : 72,
            ),
          ),
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
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '新建歌单',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _kOnSurface,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: _kOnSurface, fontSize: 16),
          decoration: InputDecoration(
            hintText: '歌单名称',
            hintStyle: const TextStyle(color: _kOutlineVariant),
            filled: true,
            fillColor: _kSurfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: _kPrimaryContainer, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: _kOnSurfaceVariant)),
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
                    color: _kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showPlaylistActions(
      BuildContext context, WidgetRef ref, Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _kOutlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                playlist.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kOnSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: _kPrimary),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, ref, playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFBA1A1A)),
              title: const Text('删除歌单',
                  style: TextStyle(color: Color(0xFFBA1A1A))),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(context, ref, playlist);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '重命名',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _kOnSurface,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: _kOnSurface, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: _kSurfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: _kPrimaryContainer, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: _kOnSurfaceVariant)),
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
                    color: _kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(
      BuildContext context, WidgetRef ref, Playlist playlist) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '删除歌单',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _kOnSurface,
          ),
        ),
        content: Text(
          '确定删除「${playlist.name}」吗？此操作无法撤回。',
          style: const TextStyle(
              color: _kOnSurfaceVariant, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: _kOnSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(playlistNotifierProvider.notifier)
                  .delete(playlist.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除',
                style: TextStyle(
                    color: Color(0xFFBA1A1A),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Editorial header ─────────────────────────────────────────────────────────

class _EditorialHeader extends StatelessWidget {
  const _EditorialHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COLLECTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
              color: _kPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Personal Curations',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: _kOnSurface,
              height: 1.1,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your tactile collection of sound,\norganized by mood and moment.',
            style: TextStyle(
              fontSize: 14,
              color: _kOnSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Playlist card ────────────────────────────────────────────────────────────

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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final coverAsync =
        ref.watch(playlistFirstSongProvider(widget.playlist.id));

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _pressed
                ? _kSurfaceContainerLow
                : _kSurfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Cover art ──────────────────────────────────────────────
              _PlaylistCover(
                coverAsync: coverAsync,
                playlistId: widget.playlist.id,
              ),
              const SizedBox(width: 16),

              // ── Info ───────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.name,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _kOnSurface,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.playlist.songCount} 首歌曲',
                      style: const TextStyle(
                        fontSize: 14,
                        color: _kOnSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Chevron ────────────────────────────────────────────────
              Icon(
                Icons.chevron_right,
                color: _pressed ? _kPrimary : _kOutlineVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Playlist cover art widget ────────────────────────────────────────────────

class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({
    required this.coverAsync,
    required this.playlistId,
  });

  final AsyncValue<Object?> coverAsync;
  final int playlistId;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: coverAsync.when(
          data: (song) {
            if (song == null) return _placeholder(playlistId);
            // song is Song — need to cast since AsyncValue is typed Object?
            return _buildImage(song);
          },
          loading: () => _placeholder(playlistId),
          error: (_, _) => _placeholder(playlistId),
        ),
      ),
    );
  }

  Widget _buildImage(dynamic song) {
    final s = song as Song;
    final url =
        MusicApiClient.buildPicUrl(s.source.param, s.picId, size: 150);
    if (url.isEmpty) return _placeholder(playlistId);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => _placeholder(playlistId),
      errorWidget: (_, _, _) => _placeholder(playlistId),
    );
  }

  static Widget _placeholder(int id) {
    // Warm gradient placeholder unique to each playlist
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
        child: Icon(Icons.queue_music, color: Colors.white70, size: 30),
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

// ─── Empty state hint ─────────────────────────────────────────────────────────

class _EmptyPlaylistHint extends StatelessWidget {
  const _EmptyPlaylistHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _kSurfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.queue_music,
                color: _kPrimary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有歌单',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击右上角 + 按钮创建你的第一个歌单',
              style: TextStyle(
                fontSize: 14,
                color: _kOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── "探索更多" promo section ──────────────────────────────────────────────────

class _ExploreMoreSection extends StatelessWidget {
  const _ExploreMoreSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
      child: Column(
        children: [
          Container(
            height: 1,
            color: _kOutlineVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _kOutlineVariant.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: _kSurfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars,
                    color: _kPrimary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '探索更多',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kOnSurface,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '根据你的听歌习惯，我们为你生成了新的建议。',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kOnSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kPrimaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '查看推荐',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kOnPrimaryContainer,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
