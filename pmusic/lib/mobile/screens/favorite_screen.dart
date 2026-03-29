import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/song.dart';
import '../../features/favorite/favorite_notifier.dart';
import '../../features/player/player_notifier.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_action_sheet.dart';

// ─── Design tokens (favorites/code.html) ─────────────────────────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kOutline = Color(0xFF847467);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kHeart = Color(0xFFE57373);
const _kSurfaceContainerHigh = Color(0xFFEAE8E2);
const _kBatchBar = Color(0xFFF5F3EE);

/// Mobile favorites screen.
///
/// Matches `favorites/code.html` design 1:1 and adds P2-05 batch operations:
///  • Sticky TopAppBar: back arrow + "我的收藏" + "批量选择" button
///  • In normal mode:
///    – Hero section: 192px cover with tertiary heart badge + info + action pills
///    – Sort label row: "按收藏时间排序" + filter icon
///    – Song list rows: cover, title, artist, filled-red heart, more_vert
///  • In batch mode (tap 批量选择 to enter / 取消 to exit):
///    – AppBar leading: circle-checkbox (select all); title: "已选择 N 首"; action: "取消"
///    – Each row shows a circle checkbox indicator; highlighted when selected
///    – Bottom floating bar: "加入队列" + "取消收藏"
class FavoriteScreen extends ConsumerStatefulWidget {
  const FavoriteScreen({super.key});

  @override
  ConsumerState<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends ConsumerState<FavoriteScreen> {
  bool _batchMode = false;
  final Set<String> _selectedKeys = {};

  String _key(Song s) => '${s.id}_${s.source.param}';
  bool _isSelected(Song s) => _selectedKeys.contains(_key(s));

  void _toggleSelect(Song s) => setState(() {
        if (_isSelected(s)) {
          _selectedKeys.remove(_key(s));
        } else {
          _selectedKeys.add(_key(s));
        }
      });

  void _toggleAll(List<Song> songs) => setState(() {
        if (_selectedKeys.length == songs.length) {
          _selectedKeys.clear();
        } else {
          _selectedKeys
            ..clear()
            ..addAll(songs.map(_key));
        }
      });

  void _enterBatch() => setState(() {
        _batchMode = true;
        _selectedKeys.clear();
      });

  void _exitBatch() => setState(() {
        _batchMode = false;
        _selectedKeys.clear();
      });

  List<Song> _getSelected(List<Song> songs) =>
      songs.where(_isSelected).toList();

  @override
  Widget build(BuildContext context) {
    final favAsync = ref.watch(favoriteNotifierProvider);
    final hasMiniPlayer =
        ref.watch(playerNotifierProvider).valueOrNull?.currentSong != null;

    return Scaffold(
      backgroundColor: _kBackground,
      body: favAsync.when(
        data: (state) => _buildBody(context, state.songs, hasMiniPlayer),
        loading: () => const Center(
            child: CircularProgressIndicator(color: _kPrimaryContainer)),
        error: (e, _) => Center(
            child: Text('加载失败: $e',
                style: const TextStyle(color: _kOnSurfaceVariant))),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, List<Song> songs, bool hasMiniPlayer) {
    final allSelected =
        songs.isNotEmpty && _selectedKeys.length == songs.length;
    final selectedCount = _selectedKeys.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomScrollView(
          slivers: [
            // ── Sticky top app bar ─────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: _kBackground,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 64,
              automaticallyImplyLeading: false,
              leading: _batchMode
                  ? IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          allSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          key: ValueKey(allSelected),
                          color: _kPrimary,
                          size: 22,
                        ),
                      ),
                      tooltip: allSelected ? '取消全选' : '全选',
                      onPressed: () => _toggleAll(songs),
                    )
                  : null,
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  _batchMode
                      ? (selectedCount > 0 ? '已选择 $selectedCount 首' : '选择歌曲')
                      : '我的收藏',
                  key: ValueKey(
                      _batchMode ? 'batch_$selectedCount' : 'normal'),
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                  ),
                ),
              ),
              actions: [
                _batchMode
                    ? TextButton(
                        onPressed: _exitBatch,
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kPrimary,
                          ),
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _enterBatch,
                        icon: const Icon(Icons.checklist,
                            color: _kPrimary, size: 20),
                        label: const Text(
                          '批量选择',
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kPrimary,
                          ),
                        ),
                      ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: _kSurfaceContainerLow.withValues(alpha: 0.10),
                ),
              ),
            ),

            // ── Hero section (normal mode only) ───────────────────────────
            if (!_batchMode)
              SliverToBoxAdapter(
                child: _HeroSection(
                  songs: songs,
                  onPlayAll: songs.isEmpty
                      ? null
                      : () => ref
                          .read(playerNotifierProvider.notifier)
                          .setQueue(songs),
                  onShuffle: songs.isEmpty
                      ? null
                      : () {
                          final shuffled = [...songs]..shuffle(Random());
                          ref
                              .read(playerNotifierProvider.notifier)
                              .setQueue(shuffled);
                        },
                ),
              ),

            // ── Sort/filter row ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    24, _batchMode ? 16 : 32, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '按收藏时间排序',
                      style: TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: _kOutline,
                      ),
                    ),
                    Icon(Icons.filter_list, color: _kOutline, size: 20),
                  ],
                ),
              ),
            ),

            // ── Song list ─────────────────────────────────────────────────
            if (songs.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      '还没有收藏的歌曲',
                      style: TextStyle(
                          color: _kOnSurfaceVariant, fontSize: 14),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      return _batchMode
                          ? _BatchSongRow(
                              song: song,
                              isSelected: _isSelected(song),
                              onToggle: () => _toggleSelect(song),
                            )
                          : _FavoriteSongRow(
                              song: song,
                              onTap: () => ref
                                  .read(playerNotifierProvider.notifier)
                                  .setQueue(songs, startIndex: index),
                              onUnfavorite: () => ref
                                  .read(favoriteNotifierProvider.notifier)
                                  .toggle(song),
                              onMore: () =>
                                  showSongActionSheet(context, song),
                            );
                    },
                    childCount: songs.length,
                  ),
                ),
              ),

            // ── Bottom padding ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: _batchMode
                    ? 96
                    : (hasMiniPlayer ? kMiniPlayerHeight + 72 : 72),
              ),
            ),
          ],
        ),

        // ── Batch action bar (floats at bottom) ───────────────────────────
        if (_batchMode)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BatchActionBar(
              selectedCount: selectedCount,
              onAddToQueue: selectedCount == 0
                  ? null
                  : () {
                      final selected = _getSelected(songs);
                      for (final s in selected) {
                        ref
                            .read(playerNotifierProvider.notifier)
                            .addToQueue(s);
                      }
                      _exitBatch();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '已将 $selectedCount 首歌添加到播放队列'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: _kPrimary,
                        ),
                      );
                    },
              onRemoveFavorites: selectedCount == 0
                  ? null
                  : () => _showRemoveConfirm(
                      context, _getSelected(songs)),
            ),
          ),
      ],
    );
  }

  void _showRemoveConfirm(BuildContext context, List<Song> selected) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBackground,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '取消收藏',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _kOnSurface,
          ),
        ),
        content: Text(
          '确定取消收藏选中的 ${selected.length} 首歌曲？',
          style: const TextStyle(color: _kOnSurfaceVariant, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: _kOutline)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(favoriteNotifierProvider.notifier)
                  .batchRemove(selected);
              _exitBatch();
            },
            child:
                const Text('确认', style: TextStyle(color: _kHeart)),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.songs,
    required this.onPlayAll,
    required this.onShuffle,
  });

  final List<Song> songs;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    // Use the first 4 songs for the mosaic cover art
    final coverUrl = songs.isNotEmpty
        ? MusicApiClient.buildPicUrl(
            songs.first.source.param, songs.first.picId,
            size: 400)
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover art with heart badge (centered)
          Center(
            child: SizedBox(
              width: 192,
              height: 204,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 192,
                      height: 192,
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1F865213),
                            blurRadius: 32,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  const _CoverPlaceholder(),
                              errorWidget: (_, _, _) =>
                                  const _CoverPlaceholder(),
                            )
                          : const _CoverPlaceholder(),
                    ),
                  ),
                  // Heart badge overlay
                  Positioned(
                    bottom: 0,
                    right: -12,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFA03E40),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x40A03E40),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.favorite,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Info text
          const Text(
            '个人曲库',
            style: TextStyle(
              fontFamily: 'Be Vietnam Pro',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.2,
              color: _kOutline,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '我的收藏',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: _kOnSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '这里存放着你最感动的每一个瞬间，共 ${songs.length} 首曲目。',
            style: const TextStyle(
              fontSize: 13,
              color: _kOnSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Side-by-side action buttons
          Row(
            children: [
              // Play All pill (fills remaining width)
              Expanded(
                child: GestureDetector(
                  onTap: onPlayAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kPrimary, _kPrimaryContainer],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33865213),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow,
                            color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          '全部播放',
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Shuffle pill
              GestureDetector(
                onTap: onShuffle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shuffle,
                          color: _kPrimary, size: 18),
                      SizedBox(width: 6),
                      Text(
                        '随机播放',
                        style: TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFBF7340), Color(0xFF8B4B1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.favorite, color: Colors.white60, size: 56),
        ),
      );
}

// ─── Favorite Song Row ────────────────────────────────────────────────────────

class _FavoriteSongRow extends StatefulWidget {
  const _FavoriteSongRow({
    required this.song,
    required this.onTap,
    required this.onUnfavorite,
    required this.onMore,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback onUnfavorite;
  final VoidCallback onMore;

  @override
  State<_FavoriteSongRow> createState() => _FavoriteSongRowState();
}

class _FavoriteSongRowState extends State<_FavoriteSongRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final picUrl = MusicApiClient.buildPicUrl(
        widget.song.source.param, widget.song.picId,
        size: 200);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color:
                _hovering ? _kSurfaceContainerLow : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Album cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: picUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: picUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const _SmallPlaceholder(),
                        errorWidget: (_, _, _) =>
                            const _SmallPlaceholder(),
                      )
                    : const _SmallPlaceholder(),
              ),

              const SizedBox(width: 16),

              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.name,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _kOnSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.song.artistDisplay,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kOnSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Right controls
              // Heart (filled red)
              GestureDetector(
                onTap: widget.onUnfavorite,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.favorite,
                    color: _kHeart,
                    size: 20,
                  ),
                ),
              ),

              // More button (always visible on touch; ~hover on pointer)
              GestureDetector(
                onTap: widget.onMore,
                child: AnimatedOpacity(
                  opacity: _hovering ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 150),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.more_vert,
                        color: _kOutline, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Batch Select Row ─────────────────────────────────────────────────────────

class _BatchSongRow extends StatelessWidget {
  const _BatchSongRow({
    required this.song,
    required this.isSelected,
    required this.onToggle,
  });

  final Song song;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final picUrl = MusicApiClient.buildPicUrl(
        song.source.param, song.picId,
        size: 200);

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _kPrimaryContainer.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Circle checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _kPrimary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _kPrimary : _kOutline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            // Album cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: picUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: picUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const _SmallPlaceholder(),
                      errorWidget: (_, _, _) =>
                          const _SmallPlaceholder(),
                    )
                  : const _SmallPlaceholder(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.name,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? _kPrimary : _kOnSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artistDisplay,
                    style: const TextStyle(
                        fontSize: 11, color: _kOnSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Batch Action Bar ─────────────────────────────────────────────────────────

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({
    required this.selectedCount,
    required this.onAddToQueue,
    required this.onRemoveFavorites,
  });

  final int selectedCount;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onRemoveFavorites;

  @override
  Widget build(BuildContext context) {
    final isActive = selectedCount > 0;
    return Container(
      decoration: BoxDecoration(
        color: _kBatchBar,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF865213).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          // Add to queue
          Expanded(
            child: GestureDetector(
              onTap: onAddToQueue,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [_kPrimary, _kPrimaryContainer])
                      : null,
                  color: isActive ? null : _kSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.queue_music,
                        color: isActive ? Colors.white : _kOutline,
                        size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '加入队列',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isActive ? Colors.white : _kOutline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Remove favorites
          Expanded(
            child: GestureDetector(
              onTap: onRemoveFavorites,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isActive
                      ? _kHeart.withValues(alpha: 0.12)
                      : _kSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: isActive
                      ? Border.all(
                          color: _kHeart.withValues(alpha: 0.4),
                          width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.heart_broken,
                        color: isActive ? _kHeart : _kOutline,
                        size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '取消收藏',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isActive ? _kHeart : _kOutline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPlaceholder extends StatelessWidget {
  const _SmallPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD49A5A), Color(0xFFBF7340)],
          ),
        ),
        child: const Icon(Icons.music_note,
            color: Colors.white70, size: 22),
      );
}
