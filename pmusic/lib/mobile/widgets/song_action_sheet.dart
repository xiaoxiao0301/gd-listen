import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../features/favorite/favorite_notifier.dart';
import '../../features/player/player_notifier.dart';
import '../../features/playlist/playlist_notifier.dart';

const _kBrand = Color(0xFF865213);
const _kSurface = Color(0xFFFBF9F3);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kPrimary = Color(0xFFE2A05B);

/// Shows a modal bottom sheet with playback + collection actions for [song].
Future<void> showSongActionSheet(BuildContext context, Song song) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SongActionSheet(song: song),
  );
}

class _SongActionSheet extends ConsumerWidget {
  const _SongActionSheet({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteAsync = ref.watch(favoriteNotifierProvider);
    final isFav = favoriteAsync.valueOrNull?.isFavorite(song) ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _kOnSurfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Song header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note,
                      color: _kPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kOnSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artistDisplay,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kOnSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE4E2DD)),
          const SizedBox(height: 8),

          // Actions
          _ActionTile(
            icon: Icons.play_circle_outline,
            label: '立即播放',
            onTap: () async {
              Navigator.pop(context);
              await ref
                  .read(playerNotifierProvider.notifier)
                  .playSong(song);
            },
          ),
          _ActionTile(
            icon: Icons.playlist_add,
            label: '添加到队列末尾',
            onTap: () async {
              Navigator.pop(context);
              await ref
                  .read(playerNotifierProvider.notifier)
                  .addToQueue(song);
            },
          ),
          _ActionTile(
            icon: Icons.skip_next_outlined,
            label: '下一首播放',
            onTap: () async {
              Navigator.pop(context);
              await ref
                  .read(playerNotifierProvider.notifier)
                  .insertNext(song);
            },
          ),
          _ActionTile(
            icon: isFav ? Icons.favorite : Icons.favorite_border,
            label: isFav ? '取消收藏' : '收藏',
            iconColor: isFav ? const Color(0xFFBA1A1A) : null,
            onTap: () async {
              Navigator.pop(context);
              await ref
                  .read(favoriteNotifierProvider.notifier)
                  .toggle(song);
            },
          ),
          _ActionTile(
            icon: Icons.playlist_add_check_outlined,
            label: '加入歌单',
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistSheet(context, ref, song);
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showAddToPlaylistSheet(
      BuildContext context, WidgetRef ref, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddToPlaylistSheet(song: song),
    );
  }
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(playlistNotifierProvider);

    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _kOnSurfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '加入歌单',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _kOnSurface,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18, color: _kBrand),
                  label: const Text('新建',
                      style: TextStyle(
                          color: _kBrand, fontWeight: FontWeight.w600)),
                  onPressed: () => _createPlaylist(context, ref),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E2DD)),
          playlistAsync.when(
            data: (state) => state.playlists.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '还没有歌单，先创建一个吧',
                      style: TextStyle(color: _kOnSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.playlists.length,
                    itemBuilder: (_, i) {
                      final pl = state.playlists[i];
                      return _ActionTile(
                        icon: Icons.queue_music_outlined,
                        label: pl.name,
                        subtitle: '${pl.songCount} 首',
                        onTap: () async {
                          Navigator.pop(context);
                          await ref
                              .read(playlistNotifierProvider.notifier)
                              .addSong(pl.id, song);
                        },
                      );
                    },
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(color: _kPrimary)),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _createPlaylist(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        title: const Text('新建歌单',
            style: TextStyle(
                color: _kOnSurface, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '歌单名称'),
          style: const TextStyle(color: _kOnSurface),
        ),
        actions: [
          TextButton(
            child: const Text('取消',
                style: TextStyle(color: _kOnSurfaceVariant)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('创建',
                style: TextStyle(
                    color: _kBrand, fontWeight: FontWeight.w700)),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await ref
                    .read(playlistNotifierProvider.notifier)
                    .create(ctrl.text.trim());
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Reusable action list tile ────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? _kBrand,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _kOnSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kOnSurfaceVariant,
                      ),
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
