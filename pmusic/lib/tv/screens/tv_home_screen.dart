import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/music_api_client.dart';
import '../../core/models/song.dart';
import '../../features/history/history_notifier.dart';
import '../../features/player/player_notifier.dart';
import '../../features/search/search_notifier.dart';

// ─── Design tokens (TV: tv_home_discovery_updated_content) ───────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kSurfaceContainerHigh = Color(0xFFEAE8E2);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kBrand = Color(0xFF865213);
const _kAmber = Color(0xFFE2A05B);
const _kOutlineVariant = Color(0xFFD6C3B4);

/// TV discovery / home screen content.
///
/// Sits inside the right-side content area of [TvAppShell]. Matches
/// `tv_home_discovery_updated_content/code.html` 1:1:
///  • Sticky header — right-aligned pill search bar
///  • 搜索历史 chips (wrapped; each deletable)
///  • 最近播放 section — horizontal card scroll with D-pad focus effects
class TvHomeScreen extends ConsumerStatefulWidget {
  const TvHomeScreen({super.key});

  @override
  ConsumerState<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends ConsumerState<TvHomeScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(historyNotifierProvider.notifier);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      ref.read(searchNotifierProvider.notifier).clearSearch();
      setState(() => _searchActive = false);
      return;
    }
    setState(() => _searchActive = true);
    _debounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(searchNotifierProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBackground,
      child: Column(
        children: [
          // ── Sticky header ─────────────────────────────────────────────────
          _TvSearchHeader(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
          ),
          // ── Scrollable content ────────────────────────────────────────────
          Expanded(
            child: _searchActive
                ? _SearchResultsBody()
                : _IdleBody(),
          ),
        ],
      ),
    );
  }
}

// ─── Search header ────────────────────────────────────────────────────────────

class _TvSearchHeader extends StatelessWidget {
  const _TvSearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      decoration: BoxDecoration(
        color: _kBackground.withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(color: Color(0x10865213), width: 1),
        ),
      ),
      child: Row(
        children: [
          // App title on the left (spacer keeps search right-aligned)
          const Spacer(),
          // Search pill — max 400px wide (design: max-w-md)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  controller.clear();
                  onChanged('');
                  focusNode.unfocus();
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 15,
                  color: _kOnSurface,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: '搜索歌手、曲目、专辑…',
                  hintStyle: TextStyle(
                    color: _kOnSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: _kBrand,
                    size: 22,
                  ),
                  filled: true,
                  fillColor: _kSurfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide:
                        const BorderSide(color: _kAmber, width: 2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Idle body (history + recently played) ────────────────────────────────────

class _IdleBody extends ConsumerWidget {
  const _IdleBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
      children: const [
        _SearchHistorySection(),
        SizedBox(height: 48),
        _RecentlyPlayedSection(),
      ],
    );
  }
}

// ─── Search history ───────────────────────────────────────────────────────────

class _SearchHistorySection extends ConsumerWidget {
  const _SearchHistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(searchNotifierProvider);
    final history = searchAsync.maybeWhen(
      data: (s) => s.searchHistory,
      orElse: () => <String>[],
    );

    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '搜索历史',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _kOnSurface,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            _TvFocusButton(
              onTap: () =>
                  ref.read(searchNotifierProvider.notifier).clearHistory(),
              child: const Text(
                '清空',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kBrand,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: history.map((keyword) {
            return _HistoryChip(
              keyword: keyword,
              onTap: () {
                ref.read(searchNotifierProvider.notifier).search(keyword);
              },
              onDelete: () {
                ref.read(searchNotifierProvider.notifier).removeHistory(keyword);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _HistoryChip extends StatefulWidget {
  const _HistoryChip({
    required this.keyword,
    required this.onTap,
    required this.onDelete,
  });
  final String keyword;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_HistoryChip> createState() => _HistoryChipState();
}

class _HistoryChipState extends State<_HistoryChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _focused
                ? _kAmber.withValues(alpha: 0.30)
                : _kAmber.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _focused
                  ? _kAmber
                  : _kAmber.withValues(alpha: 0.10),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.keyword,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kBrand,
                  height: 1.3,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onDelete,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: _kBrand.withValues(alpha: _focused ? 1.0 : 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recently played ──────────────────────────────────────────────────────────

class _RecentlyPlayedSection extends ConsumerWidget {
  const _RecentlyPlayedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyNotifierProvider);

    final songs = historyAsync.maybeWhen(
      data: (state) => state.groups
          .expand((g) => g.entries)
          .map((e) => e.song)
          .toList(),
      orElse: () => <Song>[],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: title + divider + "查看全部" button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '最近播放',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _kOnSurface,
                letterSpacing: -1,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: _kSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(width: 16),
            _TvFocusButton(
              onTap: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '查看全部',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kBrand,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 18, color: _kBrand),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Horizontal card scroll
        songs.isEmpty
            ? _EmptyState()
            : SizedBox(
                height: 280,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: songs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 32),
                  itemBuilder: (context, i) {
                    return _RecentlyPlayedCard(
                      song: songs[i],
                      onPlay: () {
                        ref
                            .read(playerNotifierProvider.notifier)
                            .playSong(songs[i]);
                      },
                    );
                  },
                ),
              ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, size: 48, color: _kOutlineVariant),
          const SizedBox(height: 12),
          const Text(
            '还没有播放记录',
            style: TextStyle(fontSize: 16, color: _kOnSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Square album-art card with D-pad focus: lifts & shows play overlay on focus.
class _RecentlyPlayedCard extends StatefulWidget {
  const _RecentlyPlayedCard({
    required this.song,
    required this.onPlay,
  });
  final Song song;
  final VoidCallback onPlay;

  @override
  State<_RecentlyPlayedCard> createState() => _RecentlyPlayedCardState();
}

class _RecentlyPlayedCardState extends State<_RecentlyPlayedCard>
    with SingleTickerProviderStateMixin {
  bool _focused = false;
  late final AnimationController _ctrl;
  late final Animation<double> _lift;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _lift = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 1.0, end: 1.10)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setFocus(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = MusicApiClient.buildPicUrl(
      widget.song.source.param,
      widget.song.picId,
      size: 400,
    );

    return Focus(
      onFocusChange: _setFocus,
      child: GestureDetector(
        onTap: widget.onPlay,
        child: SizedBox(
          width: 220,
          child: AnimatedBuilder(
            animation: _lift,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -8 * _lift.value),
                child: child,
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Square cover with focus ring + play overlay
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _focused
                        ? [
                            BoxShadow(
                              color: _kBrand.withValues(alpha: 0.18),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                    border: _focused
                        ? Border.all(color: _kAmber, width: 3)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover image with scale animation on focus
                          ScaleTransition(
                            scale: _scale,
                            child: CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                color: _kSurfaceContainerLow,
                                child: const Icon(
                                  Icons.music_note,
                                  color: _kOutlineVariant,
                                  size: 48,
                                ),
                              ),
                              errorWidget: (_, _, _) => Container(
                                color: _kSurfaceContainerLow,
                                child: const Icon(
                                  Icons.music_note,
                                  color: _kOutlineVariant,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                          // Focus overlay: gradient + play button
                          AnimatedOpacity(
                            opacity: _focused ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    _kBrand.withValues(alpha: 0.45),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: _kBrand,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _focused ? _kBrand : _kOnSurface,
                    height: 1.3,
                  ),
                  child: Text(
                    widget.song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                // Artist • Album
                Text(
                  '${widget.song.artistDisplay} • ${widget.song.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _kOnSurfaceVariant,
                    height: 1.3,
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

// ─── Search results body ──────────────────────────────────────────────────────

class _SearchResultsBody extends ConsumerWidget {
  const _SearchResultsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(searchNotifierProvider);

    return searchAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _kAmber),
      ),
      error: (e, _) => Center(
        child: Text(e.toString(),
            style: const TextStyle(color: _kOnSurfaceVariant)),
      ),
      data: (state) {
        if (state.isLoading && state.results.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: _kAmber),
          );
        }
        if (state.results.isEmpty) {
          return const Center(
            child: Text(
              '没有找到相关结果',
              style: TextStyle(color: _kOnSurfaceVariant, fontSize: 16),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          itemCount: state.results.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == state.results.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: _kAmber)
                      : _TvFocusButton(
                          onTap: () => ref
                              .read(searchNotifierProvider.notifier)
                              .loadMore(),
                          child: const Text(
                            '加载更多',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _kBrand,
                            ),
                          ),
                        ),
                ),
              );
            }
            final song = state.results[i];
            return _TvSongRow(
              song: song,
              onPlay: () => ref
                  .read(playerNotifierProvider.notifier)
                  .playSong(song),
            );
          },
        );
      },
    );
  }
}

/// TV-optimised song row for search results.
class _TvSongRow extends StatefulWidget {
  const _TvSongRow({required this.song, required this.onPlay});
  final Song song;
  final VoidCallback onPlay;

  @override
  State<_TvSongRow> createState() => _TvSongRowState();
}

class _TvSongRowState extends State<_TvSongRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final coverUrl = MusicApiClient.buildPicUrl(
      widget.song.source.param,
      widget.song.picId,
      size: 200,
    );
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _focused
                ? _kAmber.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: _focused
                ? Border.all(color: _kAmber, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    width: 56,
                    height: 56,
                    color: _kSurfaceContainerLow,
                    child: const Icon(Icons.music_note,
                        color: _kOutlineVariant, size: 24),
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: 56,
                    height: 56,
                    color: _kSurfaceContainerLow,
                    child: const Icon(Icons.music_note,
                        color: _kOutlineVariant, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _focused ? _kBrand : _kOnSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.song.artistDisplay} • ${widget.song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _kOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Focus indicator
              AnimatedOpacity(
                opacity: _focused ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(Icons.play_arrow_rounded,
                    color: _kBrand, size: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared focus-aware button ────────────────────────────────────────────────

class _TvFocusButton extends StatefulWidget {
  const _TvFocusButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<_TvFocusButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _focused
                ? _kAmber.withValues(alpha: 0.15)
                : Colors.transparent,
            border: _focused
                ? Border.all(color: _kAmber.withValues(alpha: 0.5), width: 2)
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
