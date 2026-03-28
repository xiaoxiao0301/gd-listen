import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../features/history/history_notifier.dart';
import '../../features/history/history_repository.dart';
import '../../features/player/player_notifier.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_action_sheet.dart';

// ─── Design tokens (play_history/code.html) ───────────────────────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLowest = Color(0xFFFFFFFF);
const _kSurfaceContainer = Color(0xFFF0EEE8);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kOutline = Color(0xFF847467);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kError = Color(0xFFBA1A1A);

/// Mobile play-history screen.
///
/// Matches `play_history/code.html` design 1:1:
///  • Sticky TopAppBar: amber back arrow + "播放历史" + "清空" (error color)
///  • Date-grouped list sections with sticky labels: 今天 / 昨天 / 更早
///    – Each section header: `bg-background/95 backdrop-blur`, 13px bold
///      primary-container uppercase + tracking-wider
///  • Song rows: 48×48 cover + title (bold headline) + artist +
///    play-count badge (×N amber pill) + more_vert
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(historyNotifierProvider);
    final hasMiniPlayer =
        ref.watch(playerNotifierProvider).valueOrNull?.currentSong != null;

    return Scaffold(
      backgroundColor: _kBackground,
      body: histAsync.when(
        data: (state) =>
            _buildBody(context, ref, state.groups, hasMiniPlayer),
        loading: () => const Center(
            child: CircularProgressIndicator(color: _kPrimaryContainer)),
        error: (e, _) => Center(
            child: Text('加载失败: $e',
                style: const TextStyle(color: _kOnSurfaceVariant))),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      List<HistoryGroup> groups, bool hasMiniPlayer) {
    return CustomScrollView(
      slivers: [
        // ── Sticky TopAppBar ───────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          backgroundColor: _kBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 64,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _kPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            '播放历史',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _showClearConfirm(context, ref),
              child: const Text(
                '清空',
                style: TextStyle(
                  fontFamily: 'Be Vietnam Pro',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _kError,
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

        // ── Empty state ────────────────────────────────────────────────────
        if (groups.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text(
                '还没有播放记录',
                style: TextStyle(color: _kOnSurfaceVariant, fontSize: 14),
              ),
            ),
          )
        else
          // ── Date sections ────────────────────────────────────────────────
          for (final group in groups) ...[
            // Section header (sticky)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SectionHeaderDelegate(label: group.label),
            ),
            // Song rows
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = group.entries[index];
                    return _HistorySongRow(
                      entry: entry,
                      onTap: () => ref
                          .read(playerNotifierProvider.notifier)
                          .setQueue(
                              group.entries.map((e) => e.song).toList(),
                              startIndex: index),
                      onMore: () =>
                          showSongActionSheet(context, entry.song),
                    );
                  },
                  childCount: group.entries.length,
                ),
              ),
            ),
          ],

        // ── Bottom padding ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child:
              SizedBox(height: hasMiniPlayer ? kMiniPlayerHeight + 72 : 72),
        ),
      ],
    );
  }

  void _showClearConfirm(BuildContext context, WidgetRef ref) {
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
            fontSize: 18,
            color: _kOnSurface,
          ),
        ),
        content: const Text(
          '确定要清空全部播放历史吗？此操作无法撤销。',
          style: TextStyle(color: _kOnSurfaceVariant, fontSize: 14),
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
              ref.read(historyNotifierProvider.notifier).clearHistory();
            },
            child: const Text('清空',
                style: TextStyle(color: _kError)),
          ),
        ],
      ),
    );
  }
}

// ─── Section header sticky delegate ──────────────────────────────────────────

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SectionHeaderDelegate({required this.label});

  final String label;

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _kBackground.withValues(alpha: 0.95),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Be Vietnam Pro',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: _kPrimaryContainer,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionHeaderDelegate old) => old.label != label;
}

// ─── Song Row ─────────────────────────────────────────────────────────────────

class _HistorySongRow extends StatefulWidget {
  const _HistorySongRow({
    required this.entry,
    required this.onTap,
    required this.onMore,
  });

  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  State<_HistorySongRow> createState() => _HistorySongRowState();
}

class _HistorySongRowState extends State<_HistorySongRow> {
  bool _hovering = false;

  String get _playCountLabel => '×${widget.entry.playCount}';

  @override
  Widget build(BuildContext context) {
    final song = widget.entry.song;
    final picUrl = MusicApiClient.buildPicUrl(
        song.source.param, song.picId,
        size: 200);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovering ? _kSurfaceContainer : _kSurfaceContainerLowest,
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
                        placeholder: (_, _) => const _SmallPlaceholder(),
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
                      song.name,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _kOnSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.artistDisplay,
                      style: const TextStyle(
                          fontSize: 13, color: _kOnSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Play count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kPrimaryContainer.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _playCountLabel,
                  style: const TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _kPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // More button
              GestureDetector(
                onTap: widget.onMore,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.more_vert,
                    color: _hovering ? _kPrimary : _kOutline,
                    size: 20,
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
        child: const Icon(Icons.history, color: Colors.white70, size: 22),
      );
}
