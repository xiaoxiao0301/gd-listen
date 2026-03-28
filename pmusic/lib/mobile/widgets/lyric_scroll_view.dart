import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/lyric/lyric_notifier.dart';
import '../../features/player/player_notifier.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────

const _kAmber = Color(0xFFE2A05B);
const _kBrown = Color(0xFF795548);
const _kBrand = Color(0xFF865213);

/// Full-featured scrollable lyric view.
///
/// Watches [lyricNotifierProvider] and the player position stream to
/// auto-scroll and highlight the currently active lyric line.
/// Tapping any line seeks the player to that line's timestamp.
///
/// Used by [FullLyricScreen] (mobile dark full-screen) and embedded
/// as a 3-line preview inside [FullPlayerScreen] and [TvFullPlayerScreen].
///
/// [activeLineColor] controls the color of the active lyric line:
///   - [FullLyricScreen] (dark bg) → defaults to [_kAmber] (#E2A05B)
///   - [FullPlayerScreen] preview (cream bg) → pass [_kBrand] (#865213)
///   - TV full player (cream bg) → pass [_kAmber] (#E2A05B) as per design
class LyricScrollView extends ConsumerStatefulWidget {
  const LyricScrollView({
    super.key,
    required this.songId,
    required this.source,
    /// If true, renders only 3 lines centered on the active index (preview).
    this.previewMode = false,
    /// Text alignment for lyric lines.
    this.textAlign = TextAlign.center,
    /// Color of the highlighted active line. Defaults to amber [_kAmber].
    this.activeLineColor,
    /// Color of inactive lyric lines. Defaults to [_kBrown] in full-screen,
    /// and semi-transparent black in preview mode.
    this.inactiveLineColor,
  });

  final String songId;
  final String source;
  final bool previewMode;
  final TextAlign textAlign;
  final Color? activeLineColor;
  final Color? inactiveLineColor;

  @override
  ConsumerState<LyricScrollView> createState() => _LyricScrollViewState();
}

class _LyricScrollViewState extends ConsumerState<LyricScrollView> {
  List<GlobalKey>? _keys;

  void _scrollToActive(int index) {
    if (_keys == null || index >= (_keys?.length ?? 0)) return;
    final key = _keys![index];
    if (key.currentContext == null) return;
    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.5,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricKey = (widget.songId, widget.source);

    // Keep LyricNotifier in sync with the player position.
    ref.listen<AsyncValue<AppPlayerState>>(playerNotifierProvider, (_, next) {
      next.whenData((s) {
        ref
            .read(lyricNotifierProvider(lyricKey).notifier)
            .syncPosition(s.position);
      });
    });

    // Auto-scroll when the active line changes.
    ref.listen<AsyncValue<LyricState>>(lyricNotifierProvider(lyricKey),
        (prev, next) {
      next.whenData((s) {
        if (prev?.valueOrNull?.currentIndex != s.currentIndex &&
            !widget.previewMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToActive(s.currentIndex);
          });
        }
      });
    });

    final lyricAsync = ref.watch(lyricNotifierProvider(lyricKey));

    return lyricAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _kAmber, strokeWidth: 2),
      ),
      error: (e, st) => const Center(
        child: Text('歌词加载失败',
            style: TextStyle(color: _kBrown, fontSize: 14)),
      ),
      data: (lyricState) {
        final lines = lyricState.lines;
        if (lines.isEmpty) {
          return const Center(
            child: Text('暂无歌词',
                style: TextStyle(color: _kBrown, fontSize: 14)),
          );
        }

        // Re-allocate keys only when line count changes.
        if (_keys == null || _keys!.length != lines.length) {
          _keys = List.generate(lines.length, (_) => GlobalKey());
        }

        final current = lyricState.currentIndex;
        final activeColor = widget.activeLineColor ?? _kAmber;
        final inactiveColor = widget.inactiveLineColor ?? _kBrown;

        if (widget.previewMode) {
          return _buildPreview(lines, current, activeColor);
        }

        return ListView.builder(
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 160),
          itemCount: lines.length,
          itemBuilder: (context, i) {
            final line = lines[i];
            final isActive = i == current;
            final distance = (i - current).abs();
            final opacity = isActive
                ? 1.0
                : (distance <= 2 ? 0.4 : 0.3);

            return GestureDetector(
              key: _keys![i],
              onTap: () =>
                  ref.read(playerNotifierProvider.notifier).seekTo(line.timestamp),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: AnimatedScale(
                  scale: isActive ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    opacity: opacity,
                    duration: const Duration(milliseconds: 300),
                    // Active line gets a subtle glow background (bg-primary/5 blur)
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isActive)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _kBrand.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        Column(
                          children: [
                            Text(
                              line.original,
                              textAlign: widget.textAlign,
                              style: TextStyle(
                                fontFamily: isActive ? 'Plus Jakarta Sans' : null,
                                fontSize: isActive ? 18 : 15,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isActive ? activeColor : inactiveColor,
                                height: isActive ? 1.25 : 1.625, // leading-tight vs leading-relaxed
                                letterSpacing: isActive ? 0.5 : 0,
                              ),
                            ),
                            if (line.translation != null &&
                                line.translation!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  line.translation!,
                                  textAlign: widget.textAlign,
                                  style: TextStyle(
                                    fontSize: isActive ? 16 : 13,
                                    fontWeight: isActive
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    color: isActive
                                        ? activeColor.withValues(alpha: 0.9)
                                        : inactiveColor.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Renders a compact 3-line preview (current ± 1) for use inside the
  /// full player screen. Matches `full_player/code.html` lyric section:
  ///  • Active: [activeColor], 18sp, bold, scale-110
  ///  • Non-active: semi-transparent, 15sp, medium
  Widget _buildPreview(List lines, int current, Color activeColor) {
    final indices = [current - 1, current, current + 1]
        .where((i) => i >= 0 && i < lines.length)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: indices.map((i) {
        final line = lines[i];
        final isActive = i == current;
        return AnimatedScale(
          scale: isActive ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: isActive ? 8 : 8),
            child: Text(
              line.original,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: isActive ? 'Plus Jakarta Sans' : null,
                fontSize: isActive ? 18 : 15,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? activeColor
                    : Colors.black.withValues(alpha: 0.35),
                height: 1.4,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
