import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import 'song_cover_image.dart';

// ─── Design tokens (mirrored from design system) ─────────────────────────────

const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kOutline = Color(0xFF847467);
const _kPrimary = Color(0xFFE2A05B);

/// A single song row matching the design:
///   [48×48 cover] [song name + artist·album] [more_vert]
///
/// Pass [onTap] for play on click, [onMore] to open the action sheet.
class SongListItem extends StatelessWidget {
  const SongListItem({
    super.key,
    required this.song,
    this.isPlaying = false,
    this.onTap,
    this.onMore,
  });

  final Song song;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // ── Album cover ────────────────────────────────────────────────
            SongCover(
              source: song.source.param,
              picId: song.picId,
              width: 48,
              height: 48,
            ),
            const SizedBox(width: 16),

            // ── Song info ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (isPlaying)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.equalizer,
                            size: 14,
                            color: _kPrimary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          song.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: isPlaying ? _kPrimary : _kOnSurface,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.album.isNotEmpty
                        ? '${song.artistDisplay} · ${song.album}'
                        : song.artistDisplay,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kOnSurfaceVariant,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── More button ───────────────────────────────────────────────
            GestureDetector(
              onTap: onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                child: Icon(
                  Icons.more_vert,
                  color: _kOutline,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
