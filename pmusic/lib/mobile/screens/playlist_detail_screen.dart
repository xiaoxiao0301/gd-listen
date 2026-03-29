import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/song.dart';
import '../../features/player/player_notifier.dart';
import '../../features/playlist/playlist_notifier.dart';
import '../widgets/mini_player.dart';

// ─── Design tokens (playlist_detail/code.html) ───────────────────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kOutlineVariant = Color(0xFFD6C3B4);
const _kOutline = Color(0xFF847467);

/// Playlist detail screen that shows all songs in a playlist.
///
/// Matches `playlist_detail/code.html` design 1:1:
///  • Sticky TopAppBar: back arrow (amber), playlist name (amber), more_vert
///  • 2×2 mosaic hero (240 px) built from the first 4 song album covers
///  • Sticky action row: "▶ 播放全部" (gradient) + "⇌ 随机播放" (outlined)
///  • Reorderable song list with drag_indicator handles
///  • Currently playing song highlighted in amber with equalizer icon
/// P3-05: Batch operations mode — "批量选择" in AppBar, checkboxes on rows,
///  bottom bar with "加入队列" + "移出歌单".
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  final int playlistId;
  final String playlistName;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState
    extends ConsumerState<PlaylistDetailScreen> {
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

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(playlistSongsProvider(widget.playlistId));
    final playerState = ref.watch(playerNotifierProvider).valueOrNull;
    final hasMiniPlayer = playerState?.currentSong != null;
    final currentSong = playerState?.currentSong;

    return Scaffold(
      backgroundColor: _kBackground,
      body: songsAsync.when(
        data: (songs) => Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── Sticky top app bar ────────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  backgroundColor: _kBackground,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  toolbarHeight: 64,
                  leading: _batchMode
                      ? GestureDetector(
                          onTap: () => _toggleAll(songs),
                          child: Icon(
                            _selectedKeys.length == songs.length
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: _kPrimary,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_back, color: _kPrimary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                  title: Text(
                    _batchMode ? '已选择 ${_selectedKeys.length} 首' : widget.playlistName,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary,
                    ),
                  ),
                  actions: [
                    _batchMode
                        ? TextButton(
                            onPressed: _exitBatch,
                            child: const Text('取消',
                                style: TextStyle(color: _kPrimary, fontWeight: FontWeight.w600)),
                          )
                        : TextButton(
                            onPressed: songs.isEmpty ? null : _enterBatch,
                            child: const Text('批量选择',
                                style: TextStyle(
                                    color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
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

            // ── 2×2 hero mosaic (240 px) ──────────────────────────────────
            SliverToBoxAdapter(
              child: _HeroMosaic(songs: songs, playlistName: widget.playlistName),
            ),

            // ── Action row ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ActionRow(
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

            // ── Song list (reorderable in normal mode, selectable in batch) ─
            if (songs.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      '歌单暂无歌曲',
                      style: TextStyle(
                        color: _kOnSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: _batchMode
                    ? SliverList.builder(
                        itemCount: songs.length,
                        itemBuilder: (ctx, index) {
                          final song = songs[index];
                          final selected = _isSelected(song);
                          return _SongRow(
                            key: ValueKey('${song.id}_${song.source.param}'),
                            song: song,
                            index: index,
                            isPlaying: false,
                            batchMode: true,
                            selected: selected,
                            onTap: () => _toggleSelect(song),
                            onMore: () {},
                          );
                        },
                      )
                    : SliverReorderableList(
                        itemCount: songs.length,
                        itemBuilder: (ctx, index) {
                          final song = songs[index];
                          final isPlaying = currentSong != null &&
                              currentSong.id == song.id &&
                              currentSong.source == song.source;
                          return _SongRow(
                            key: ValueKey('${song.id}_${song.source.param}'),
                            song: song,
                            index: index,
                            isPlaying: isPlaying,
                            onTap: () => ref
                                .read(playerNotifierProvider.notifier)
                                .setQueue(songs, startIndex: index),
                            onMore: () =>
                                _showSongActions(context, ref, song),
                          );
                        },
                        onReorder: (oldIndex, newIndex) async {
                          await ref
                              .read(playlistNotifierProvider.notifier)
                              .reorderSongs(
                                  widget.playlistId, oldIndex, newIndex);
                          ref.invalidate(
                              playlistSongsProvider(widget.playlistId));
                        },
                        proxyDecorator: (child, i, animation) => Material(
                          elevation: 6,
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        ),
                      ),
              ),

            // ── Bottom padding (mini player + nav bar) ────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: _batchMode
                    ? 80 + (_hasMiniPlayerHeight(hasMiniPlayer))
                    : hasMiniPlayer
                        ? kMiniPlayerHeight + 72
                        : 72,
              ),
            ),
          ],
        ),

        // ── Batch action bar ──────────────────────────────────────────────
        if (_batchMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 12, 24, 12 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F3EE),
                border: Border(
                    top: BorderSide(color: Color(0x1AD6C3B4), width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14865213),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedKeys.isEmpty
                          ? null
                          : () {
                              final selected = songs
                                  .where((s) => _isSelected(s))
                                  .toList();
                              for (final s in selected) {
                                ref
                                    .read(playerNotifierProvider.notifier)
                                    .addToQueue(s);
                              }
                              _exitBatch();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '已添加 ${selected.length} 首到队列')),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('加入队列',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selectedKeys.isEmpty
                          ? null
                          : () async {
                              final selected = songs
                                  .where((s) => _isSelected(s))
                                  .toList();
                              for (final s in selected) {
                                await ref
                                    .read(playlistNotifierProvider.notifier)
                                    .removeSong(widget.playlistId, s.id);
                              }
                              ref.invalidate(playlistSongsProvider(
                                  widget.playlistId));
                              _exitBatch();
                            },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kPrimary),
                        foregroundColor: _kPrimary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('移出歌单',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: _kPrimaryContainer),
        ),
        error: (e, _) => Center(
          child: Text(
            '加载失败: $e',
            style: const TextStyle(color: _kOnSurfaceVariant),
          ),
        ),
      ),
    );
  }

  double _hasMiniPlayerHeight(bool hasMini) =>
      hasMini ? kMiniPlayerHeight + 72 : 72;

  void _showSongActions(BuildContext context, WidgetRef ref, Song song) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _kOutlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow, color: _kPrimary),
                title: const Text('播放'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.queue_music, color: _kPrimary),
                title: const Text('添加到播放队列'),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(playerNotifierProvider.notifier)
                      .addToQueue(song);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.playlist_remove, color: _kPrimary),
                title: const Text('从歌单中删除'),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(playlistNotifierProvider.notifier)
                      .removeSong(widget.playlistId, song.id)
                      .then((_) => ref
                          .invalidate(playlistSongsProvider(widget.playlistId)));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero Mosaic ─────────────────────────────────────────────────────────────

class _HeroMosaic extends StatelessWidget {
  const _HeroMosaic({required this.songs, required this.playlistName});

  final List<Song> songs;
  final String playlistName;

  static const _gradients = [
    [Color(0xFFBF7340), Color(0xFF8B4B1A)],
    [Color(0xFFD49A5A), Color(0xFFA0652A)],
    [Color(0xFF8B5E3C), Color(0xFF5C3718)],
    [Color(0xFFCC8844), Color(0xFF8C5219)],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 2×2 mosaic grid
          GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: List.generate(4, (i) {
              final song = i < songs.length ? songs[i] : null;
              final picUrl = song != null
                  ? MusicApiClient.buildPicUrl(
                      song.source.param, song.picId,
                      size: 300)
                  : '';
              final grads = _gradients[i % _gradients.length];
              if (picUrl.isNotEmpty) {
                return CachedNetworkImage(
                  imageUrl: picUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _GradCell(grads: grads),
                  errorWidget: (_, _, _) => _GradCell(grads: grads),
                );
              }
              return _GradCell(grads: grads);
            }),
          ),

          // Gradient overlay: transparent → deep-brown
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x663E2723),
                  Color(0xFF3E2723),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Playlist name on gradient
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Text(
              playlistName,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradCell extends StatelessWidget {
  const _GradCell({required this.grads});

  final List<Color> grads;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: grads,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

// ─── Action Row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({this.onPlayAll, this.onShuffle});

  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBackground,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // Play All
          Expanded(
            child: GestureDetector(
              onTap: onPlayAll,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPrimary, _kPrimaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26865213),
                      blurRadius: 32,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow,
                        color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      '播放全部',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
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

          // Shuffle
          Expanded(
            child: GestureDetector(
              onTap: onShuffle,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _kPrimaryContainer, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: _kSurfaceContainerLow.withValues(alpha: 0.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shuffle, color: _kPrimary, size: 18),
                    SizedBox(width: 6),
                    Text(
                      '随机播放',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _kPrimary,
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

// ─── Song Row ─────────────────────────────────────────────────────────────────

class _SongRow extends StatelessWidget {
  const _SongRow({
    super.key,
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.onTap,
    required this.onMore,
    this.batchMode = false,
    this.selected = false,
  });

  final Song song;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final bool batchMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final picUrl = MusicApiClient.buildPicUrl(
        song.source.param, song.picId,
        size: 200);
    final textColor = isPlaying ? _kPrimary : _kOnSurface;
    final subColor = isPlaying ? _kPrimaryContainer : _kOnSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? _kPrimaryContainer.withValues(alpha: 0.12)
              : isPlaying
                  ? _kPrimaryContainer.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // Leading: checkbox in batch mode, drag handle in normal mode
                if (batchMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? _kPrimary : _kOutlineVariant,
                      size: 22,
                    ),
                  )
                else
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: isPlaying
                          ? _kPrimary.withValues(alpha: 0.6)
                          : _kOutlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

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
                              const _CoverPlaceholder(),
                          errorWidget: (_, _, _) =>
                              const _CoverPlaceholder(),
                        )
                      : const _CoverPlaceholder(),
                ),

                const SizedBox(width: 16),

                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.name,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.album.isNotEmpty
                            ? '${song.artistDisplay} · ${song.album}'
                            : song.artistDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          color: subColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Playing indicator
                if (isPlaying)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.equalizer,
                        size: 16, color: _kPrimary),
                  ),

                // more_vert button
                GestureDetector(
                  onTap: onMore,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: isPlaying ? _kPrimary : _kOutline,
                    ),
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

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD49A5A), Color(0xFFBF7340)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note,
            color: Colors.white70, size: 22),
      );
}
