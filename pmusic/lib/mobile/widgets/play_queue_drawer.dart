import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../features/player/player_notifier.dart';
import 'song_cover_image.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kSurfaceLowest = Color(0xFFFFFFFF);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kOutlineVariant = Color(0xFFD6C3B4);

/// Right-sliding play queue drawer.
///
/// Matches `play_queue/code.html` 1:1:
///  • Semi-transparent overlay with backdrop blur
///  • Right drawer: white bg, shadow, 80% width (max 448)
///  • Header: "当前队列" + track count + "清空" button
///  • NOW PLAYING section with amber left indicator bar
///  • "下一首播放" divider
///  • Queue items: drag handle, 44dp art, title/artist, remove button
///
/// Open via [showPlayQueueDrawer].
class PlayQueueDrawer extends ConsumerWidget {
  const PlayQueueDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerNotifierProvider);

    return playerAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (state) {
        final queue = state.queue;
        final currentIndex = state.currentIndex;
        final notifier = ref.read(playerNotifierProvider.notifier);

        return Material(
          type: MaterialType.transparency,
          child: Stack(
          children: [
            // ── Scrim ─────────────────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),

            // ── Drawer ────────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {}, // absorb taps so they don't hit scrim
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  constraints: const BoxConstraints(maxWidth: 448),
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: _kSurfaceLowest,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 32,
                        offset: Offset(-4, 0),
                      ),
                    ],
                    border: Border(
                      left: BorderSide(
                        color: _kOutlineVariant.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, queue.length, notifier),
                        Expanded(
                          child: _QueueBody(
                            queue: queue,
                            currentIndex: currentIndex,
                            notifier: notifier,
                            drawerContext: context,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    int trackCount,
    PlayerNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前队列',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kOnSurface,
                    fontFamily: 'Plus Jakarta Sans',
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 $trackCount 首',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _kOnSurfaceVariant,
                    letterSpacing: 1.5,
                    fontFamily: 'Be Vietnam Pro',
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              notifier.clearQueue();
              Navigator.of(context).pop();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '清空',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary,
                  fontFamily: 'Be Vietnam Pro',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Queue body (now playing + reorderable upcoming list) ────────────────────────

class _QueueBody extends StatelessWidget {
  const _QueueBody({
    required this.queue,
    required this.currentIndex,
    required this.notifier,
    required this.drawerContext,
  });

  final List<Song> queue;
  final int currentIndex;
  final PlayerNotifier notifier;
  final BuildContext drawerContext;

  @override
  Widget build(BuildContext context) {
    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music, size: 48, color: _kOutlineVariant),
            const SizedBox(height: 12),
            const Text('队列为空',
                style: TextStyle(
                    fontSize: 14, color: _kOnSurfaceVariant)),
          ],
        ),
      );
    }

    final hasActive = currentIndex >= 0 && currentIndex < queue.length;
    final activeSong = hasActive ? queue[currentIndex] : null;

    // Build (originalIndex, song) list for items != currentIndex
    final upcomingEntries = <MapEntry<int, Song>>[
      for (var i = 0; i < queue.length; i++)
        if (i != currentIndex) MapEntry(i, queue[i]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── NOW PLAYING label ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '正在播放',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _kPrimaryContainer,
                letterSpacing: 1.5,
                fontFamily: 'Be Vietnam Pro',
              ),
            ),
          ),
        ),

        // ── Fixed active row (not reorderable) ────────────────────────────
        if (activeSong != null)
          _ActiveQueueRow(
            song: activeSong,
            onRemove: () => notifier.removeFromQueue(currentIndex),
          ),

        // ── "下一首播放" divider ────────────────────────────────────────
        if (upcomingEntries.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: _kOutlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '下一首播放',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kOnSurfaceVariant,
                      letterSpacing: 2,
                      fontFamily: 'Be Vietnam Pro',
                    ),
                  ),
                ),
                Expanded(
                  child: _DashedLine(
                      color: _kPrimaryContainer.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),

        // ── Reorderable upcoming items ─────────────────────────────────────
        Expanded(
          child: upcomingEntries.isEmpty
              ? const SizedBox.shrink()
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                  onReorder: (oldI, newI) {
                    // Map local indices back to global queue indices.
                    if (oldI == newI) return;
                    final realOld = upcomingEntries[oldI].key;
                    // Flutter reports newI after removing item; clamp to list.
                    final dstI = newI >= upcomingEntries.length
                        ? upcomingEntries.length - 1
                        : newI > oldI
                            ? newI - 1
                            : newI;
                    final realNew = upcomingEntries[dstI].key;
                    notifier.reorderQueue(realOld, realNew);
                  },
                  proxyDecorator: (child, index, animation) => Material(
                    color: Colors.transparent,
                    elevation: 6,
                    shadowColor: _kPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  ),
                  itemCount: upcomingEntries.length,
                  itemBuilder: (ctx, i) {
                    final entry = upcomingEntries[i];
                    return _QueueItemRow(
                      key: ValueKey(
                          'q_${entry.value.id}_${entry.value.source.param}_$i'),
                      song: entry.value,
                      listIndex: i,
                      onTap: () {
                        notifier.skipToIndex(entry.key);
                        Navigator.of(drawerContext).pop();
                      },
                      onRemove: () =>
                          notifier.removeFromQueue(entry.key),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ActiveQueueRow extends StatelessWidget {
  const _ActiveQueueRow({
    required this.song,
    required this.onRemove,
  });

  final Song song;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Amber left indicator bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        _kPrimary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
            ),
          ),
          // Row content
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.drag_handle,
                    color: _kOutlineVariant, size: 20),
                const SizedBox(width: 12),
                _AlbumThumb(song: song, size: 44),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kOnSurface,
                          fontFamily: 'Be Vietnam Pro',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artistDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kOnSurfaceVariant,
                          fontFamily: 'Be Vietnam Pro',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(Icons.close,
                      size: 20,
                      color:
                          _kOnSurfaceVariant.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reorderable queue item row ─────────────────────────────────────────────

class _QueueItemRow extends StatefulWidget {
  const _QueueItemRow({
    super.key,
    required this.song,
    required this.listIndex,
    required this.onTap,
    required this.onRemove,
  });

  final Song song;
  final int listIndex; // position within the upcoming sub-list
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  State<_QueueItemRow> createState() => _QueueItemRowState();
}

class _QueueItemRowState extends State<_QueueItemRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovering ? _kSurfaceContainerLow : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // ── Drag handle (initiates reorder) ──────────────────────
              ReorderableDragStartListener(
                index: widget.listIndex,
                child: AnimatedOpacity(
                  opacity: _hovering ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.drag_handle,
                      color: _kOutlineVariant, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              _AlbumThumb(song: widget.song, size: 44),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.song.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _kOnSurface,
                        fontFamily: 'Be Vietnam Pro',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.song.artistDisplay,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kOnSurfaceVariant,
                        fontFamily: 'Be Vietnam Pro',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onRemove,
                child: Icon(Icons.close,
                    size: 20,
                    color: _kOnSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Album thumbnail ──────────────────────────────────────────────────────────

class _AlbumThumb extends StatelessWidget {
  const _AlbumThumb({required this.song, required this.size});
  final Song song;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SongCover(
      source: song.source.param,
      picId: song.picId,
      width: size,
      height: size,
    );
  }
}

// ─── Dashed line ──────────────────────────────────────────────────────────────

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedLinePainter(color: color),
      child: const SizedBox(height: 1),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

// ─── Route helper ────────────────────────────────────────────────────────────

/// Show the play queue as a right-sliding modal route.
void showPlayQueueDrawer(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, _, _) => const PlayQueueDrawer(),
      transitionsBuilder: (_, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}
