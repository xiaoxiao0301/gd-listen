import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/favorite/favorite_notifier.dart';
import '../../features/history/history_notifier.dart';
import '../../features/history/history_repository.dart';
import '../../features/player/player_notifier.dart';
import '../../features/playlist/playlist_notifier.dart';
import '../../mobile/widgets/song_cover_image.dart';
// (TvMiniPlayerBar managed by TvAppShell)

// ─── Design tokens (tv_play_history/code.html) ───────────────────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kSurfaceContainer = Color(0xFFF0EEE8);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kOutline = Color(0xFF847467);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kOnPrimaryContainer = Color(0xFF613700);
const _kError = Color(0xFFBA1A1A);

/// TV play-history screen.
///
/// Matches `tv_play_history/code.html` design 1:1:
///  • Large header: "播放历史" 5xl extrabold + subtitle + "清空历史" pill button
///  • Date-grouped sections with sticky headers (primary color, 20sp bold)
///  • Song rows: 96×96 album art + play-overlay on focus + title (xl bold) +
///    artist (outline, lg) + amber play-count badge + time label + more_vert
///  • Focused row: scale 1.02 + amber glow (4px ring)
///  • Bottom TvMiniPlayerBar persistent
class TvPlayHistoryScreen extends ConsumerStatefulWidget {
  const TvPlayHistoryScreen({super.key});

  @override
  ConsumerState<TvPlayHistoryScreen> createState() =>
      _TvPlayHistoryScreenState();
}

class _TvPlayHistoryScreenState extends ConsumerState<TvPlayHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final histAsync = ref.watch(historyNotifierProvider);

    return Scaffold(
      backgroundColor: _kBackground,
      body: histAsync.when(
        data: (state) => _buildContent(context, state.groups),
        loading: () => const Center(
            child: CircularProgressIndicator(color: _kPrimaryContainer)),
        error: (e, _) => Center(
            child: Text('加载失败: $e',
                style: const TextStyle(color: _kOnSurfaceVariant))),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, List<HistoryGroup> groups) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(48, 64, 48, 48),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '播放历史',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            color: _kOnSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '按日期分组，记录你的每一次聆听',
                          style: TextStyle(
                            fontFamily: 'Be Vietnam Pro',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _kOutline,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Clear button
                    Focus(
                      child: Builder(builder: (ctx) {
                        final focused = Focus.of(ctx).hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: focused
                                ? Border.all(
                                    color: _kError.withValues(alpha: 0.5),
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: TextButton.icon(
                            focusNode: FocusNode(skipTraversal: true),
                            onPressed: () =>
                                _showClearConfirm(context),
                            icon: const Icon(Icons.delete_sweep,
                                color: _kError, size: 20),
                            label: const Text(
                              '清空历史',
                              style: TextStyle(
                                fontFamily: 'Be Vietnam Pro',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 1.5,
                                color: _kError,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // ── Empty state ──────────────────────────────────────────────
            if (groups.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    '还没有播放记录',
                    style: TextStyle(
                        color: _kOnSurfaceVariant, fontSize: 18),
                  ),
                ),
              )
            else
              for (final group in groups) ...[
                // Section header (sticky)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TvSectionHeaderDelegate(label: group.label),
                ),
                // Song rows
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 48, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = group.entries[index];
                        return _TvHistorySongRow(
                          entry: entry,
                          onTap: () {
                            ref
                                .read(playerNotifierProvider.notifier)
                                .setQueue(
                                    group.entries
                                        .map((e) => e.song)
                                        .toList(),
                                    startIndex: index);
                          },
                          onMore: () => _showTvSongActionDialog(
                              context, ref, entry.song),
                        );
                      },
                      childCount: group.entries.length,
                    ),
                  ),
                ),
              ],

            // Bottom padding for player bar (managed by TvAppShell)
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ],
    );
  }

  void _showTvSongActionDialog(
      BuildContext context, WidgetRef ref, song) {
    final s = song as dynamic;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Text(
          s.name as String,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kOnSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Consumer(
          builder: (ctx2, ref2, _) {
            final isFav = ref2
                    .watch(favoriteNotifierProvider)
                    .valueOrNull
                    ?.isFavorite(song) ??
                false;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.play_arrow,
                      color: _kPrimary),
                  title: const Text('立即播放',
                      style: TextStyle(
                          fontSize: 16, color: _kOnSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref2
                        .read(playerNotifierProvider.notifier)
                        .setQueue([song], startIndex: 0);
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.add_to_queue,
                      color: _kPrimary),
                  title: const Text('添加到队列末尾',
                      style: TextStyle(
                          fontSize: 16, color: _kOnSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref2
                        .read(playerNotifierProvider.notifier)
                        .addToQueue(song);
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                      isFav
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: _kPrimary),
                  title: Text(
                      isFav ? '取消收藏' : '收藏',
                      style: const TextStyle(
                          fontSize: 16, color: _kOnSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref2
                        .read(favoriteNotifierProvider.notifier)
                        .toggle(song);
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.playlist_add,
                      color: _kPrimary),
                  title: const Text('加入歌单',
                      style: TextStyle(
                          fontSize: 16, color: _kOnSurface)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddToPlaylistDialog(context, ref2, song);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭',
                style: TextStyle(
                    color: _kOnSurfaceVariant, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(
      BuildContext context, WidgetRef ref, song) {
    final playlists =
        ref.read(playlistNotifierProvider).valueOrNull?.playlists ?? [];
    if (playlists.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text('加入歌单',
            style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kOnSurface)),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlists.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(playlists[i].name,
                  style: const TextStyle(
                      fontSize: 16, color: _kOnSurface)),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(playlistNotifierProvider.notifier)
                    .addSong(playlists[i].id, song);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showClearConfirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '清空播放历史',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: _kOnSurface,
          ),
        ),
        content: const Text(
          '确定要清空全部播放历史吗？此操作无法撤销。',
          style: TextStyle(color: _kOnSurfaceVariant, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: _kOutline, fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(historyNotifierProvider.notifier).clearHistory();
            },
            child: const Text('清空',
                style: TextStyle(color: _kError, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ─── Section header sliver delegate ──────────────────────────────────────────

class _TvSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TvSectionHeaderDelegate({required this.label});

  final String label;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _kBackground.withValues(alpha: 0.90),
      padding: const EdgeInsets.fromLTRB(48, 12, 48, 8),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: _kPrimary,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TvSectionHeaderDelegate old) =>
      old.label != label;
}

// ─── Song Row (TV) ────────────────────────────────────────────────────────────

class _TvHistorySongRow extends StatefulWidget {
  const _TvHistorySongRow({
    required this.entry,
    required this.onTap,
    required this.onMore,
  });

  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  State<_TvHistorySongRow> createState() => _TvHistorySongRowState();
}

class _TvHistorySongRowState extends State<_TvHistorySongRow> {
  bool _focused = false;

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final hhmm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (d == today) return hhmm;
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == yesterday) return 'Yesterday $hhmm';
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hhmm';
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.entry.song;
    final timeStr = _formatTime(widget.entry.playedAt);
    final countStr = 'x${widget.entry.playCount}';

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _focused ? _kSurfaceContainer : _kSurfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: _focused
                ? Border.all(
                    color: _kPrimaryContainer.withValues(alpha: 0.6),
                    width: 3,
                  )
                : null,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: _kPrimaryContainer.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Transform.scale(
            scale: _focused ? 1.02 : 1.0,
            child: Row(
              children: [
                // Album art with play-circle overlay on focus
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SongCover(
                        source: song.source.param,
                        picId: song.picId,
                        size: 400,
                        width: 96,
                        height: 96,
                        borderRadius: 12,
                      ),
                      // Play circle overlay when focused
                      AnimatedOpacity(
                        opacity: _focused ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.name,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kOnSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song.artistDisplay,
                        style: const TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _kOutline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),

                // Right: count badge + time + more
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kPrimaryContainer,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33E2A05B),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        countStr,
                        style: const TextStyle(
                          fontFamily: 'Be Vietnam Pro',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _kOnPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Time string
                    Text(
                      timeStr.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Be Vietnam Pro',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        letterSpacing: 1.2,
                        color: _kOutline,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // More vert
                    GestureDetector(
                      onTap: widget.onMore,
                      child: Icon(
                        Icons.more_vert,
                        color: _focused ? _kPrimary : _kOutline,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
