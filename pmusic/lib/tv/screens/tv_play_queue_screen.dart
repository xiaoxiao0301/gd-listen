import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/song.dart';
import '../../features/player/player_notifier.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kSurface = Color(0xFFFBF9F3);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kSurfaceContainerLowest = Color(0xFFFFFFFF);
const _kSurfaceContainerHigh = Color(0xFFEAE8E2);
const _kSurfaceContainerHighest = Color(0xFFE4E2DD);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kOutlineVariant = Color(0xFFD6C3B4);

/// Full-page play queue screen for TV.
///
/// Matches `tv_play_queue/code.html` (main content area):
///  • "Current Queue" header (32pt extrabold) + count + "Clear Queue" button
///  • Active item: amber left border (6px), scale-[1.01], shadow
///  • "Drop here to play next" zone
///  • Queue items: drag indicator, 64dp art, title (18sp bold headline),
///    artist (14sp on-surface-variant), duration, delete button
///  • TV focus: amber ring + shadow on hovered/focused items
class TvPlayQueueScreen extends ConsumerWidget {
  const TvPlayQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerNotifierProvider);

    return playerAsync.when(
      loading: () => const _TvQueueLoadingView(),
      error: (_, _) => const _TvQueueLoadingView(),
      data: (state) {
        final queue = state.queue;
        final currentIndex = state.currentIndex;
        final notifier = ref.read(playerNotifierProvider.notifier);

        return Container(
          color: _kSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                  context, queue.length, state.queue, notifier),
              Expanded(
                child: _buildQueueList(
                    context, queue, currentIndex, notifier),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    int count,
    List<Song> queue,
    PlayerNotifier notifier,
  ) {
    // Calculate total duration from queue (placeholder — real data via P2-09)
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 64, 48, 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Queue',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: _kOnSurface,
                    fontFamily: 'Plus Jakarta Sans',
                    letterSpacing: -1,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$count TRACKS',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kOnSurfaceVariant,
                    letterSpacing: 3,
                    fontFamily: 'Be Vietnam Pro',
                  ),
                ),
              ],
            ),
          ),
          // Clear Queue button
          Focus(
            child: Builder(
              builder: (ctx) {
                final focused = Focus.of(ctx).hasFocus;
                return GestureDetector(
                  onTap: () => notifier.clearQueue(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: focused
                          ? _kSurfaceContainerHighest
                          : _kSurfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: focused
                          ? Border.all(
                              color:
                                  _kPrimary.withValues(alpha: 0.2),
                              width: 2,
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep,
                            size: 20, color: _kPrimary),
                        const SizedBox(width: 8),
                        const Text(
                          'Clear Queue',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary,
                            letterSpacing: 0.5,
                            fontFamily: 'Be Vietnam Pro',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Queue list ──────────────────────────────────────────────────────────────

  Widget _buildQueueList(
    BuildContext context,
    List<Song> queue,
    int currentIndex,
    PlayerNotifier notifier,
  ) {
    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music,
                size: 64, color: _kOutlineVariant),
            const SizedBox(height: 16),
            const Text(
              '队列为空',
              style: TextStyle(
                fontSize: 18,
                color: _kOnSurfaceVariant,
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 128),
      onReorder: notifier.reorderQueue,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: _kPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
      itemCount: queue.length,
      itemBuilder: (context, i) {
        return _TvQueueItemRow(
          key: ValueKey('tv_q_${queue[i].id}_${queue[i].source.param}_$i'),
          song: queue[i],
          listIndex: i,
          isActive: i == currentIndex,
          onTap: i == currentIndex
              ? null
              : () => notifier.skipToIndex(i),
          onRemove: () => notifier.removeFromQueue(i),
        );
      },
    );
  }
}

// ─── Queue item row ────────────────────────────────────────────────────────────

class _TvQueueItemRow extends StatefulWidget {
  const _TvQueueItemRow({
    super.key,
    required this.song,
    required this.listIndex,
    required this.isActive,
    required this.onRemove,
    this.onTap,
  });

  final Song song;
  final int listIndex;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  @override
  State<_TvQueueItemRow> createState() => _TvQueueItemRowState();
}

class _TvQueueItemRowState extends State<_TvQueueItemRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final picUrl = MusicApiClient.buildPicUrl(
        widget.song.source.param, widget.song.picId);
    final highlighted = _focused || widget.isActive;

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: highlighted
                ? (widget.isActive
                    ? _kSurfaceContainerLow
                    : _kSurfaceContainerLowest)
                : _kSurfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: widget.isActive
                ? const Border(
                    left: BorderSide(color: _kPrimary, width: 6),
                  )
                : (_focused
                    ? Border.all(
                        color:
                            _kPrimaryContainer.withValues(alpha: 0.3),
                        width: 2,
                      )
                    : null),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color:
                          _kPrimary.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : (_focused
                    ? [
                        BoxShadow(
                          color: _kPrimaryContainer
                              .withValues(alpha: 0.25),
                          blurRadius: 20,
                        ),
                      ]
                    : null),
          ),
          child: Row(
            children: [
              // Drag indicator — always visible on TV (dim when unfocused)
              ReorderableDragStartListener(
                index: widget.listIndex,
                child: AnimatedOpacity(
                  opacity: _focused ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 150),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.drag_indicator,
                        color: _kOutlineVariant, size: 24),
                  ),
                ),
              ),

              // Album art
              _TvAlbumThumb(url: picUrl, isActive: widget.isActive),
              const SizedBox(width: 24),

              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.song.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: widget.isActive
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: widget.isActive
                            ? _kPrimary
                            : _kOnSurface,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.song.artistDisplay,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _kOnSurfaceVariant,
                        fontFamily: 'Be Vietnam Pro',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Right actions
              const SizedBox(width: 32),
              if (widget.isActive)
                const Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                    letterSpacing: 1.5,
                    fontFamily: 'Be Vietnam Pro',
                  ),
                )
              else
                const Text(
                  '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _kOnSurfaceVariant,
                    fontFamily: 'Be Vietnam Pro',
                  ),
                ),

              const SizedBox(width: 32),

              // Delete
              Focus(
                child: GestureDetector(
                  onTap: widget.onRemove,
                  child: Icon(
                    Icons.close,
                    size: 22,
                    color: _kOnSurfaceVariant.withValues(alpha: 0.6),
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

// ─── TV album thumbnail ────────────────────────────────────────────────────────

class _TvAlbumThumb extends StatelessWidget {
  const _TvAlbumThumb({required this.url, required this.isActive});
  final String url;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            url.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                  placeholder: (_, p) => _placeholder(),
                  errorWidget: (_, e, _) => _placeholder(),
                  )
                : _placeholder(),
            if (isActive)
              Container(
                color: _kPrimary.withValues(alpha: 0.4),
                child: const Icon(
                  Icons.equalizer,
                  color: Colors.white,
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFE2A05B).withValues(alpha: 0.15),
        child: const Icon(Icons.music_note,
            color: Color(0xFFE2A05B), size: 28),
      );
}

// ─── Loading view ─────────────────────────────────────────────────────────────

class _TvQueueLoadingView extends StatelessWidget {
  const _TvQueueLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: _kPrimaryContainer,
      ),
    );
  }
}
