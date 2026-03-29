import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../features/favorite/favorite_notifier.dart';
import '../../features/history/history_notifier.dart';
import '../../features/player/player_notifier.dart';
import '../../features/playlist/playlist_notifier.dart';
import '../../features/search/search_notifier.dart';
import '../../mobile/widgets/song_cover_image.dart';
import 'tv_play_history_screen.dart';

// ─── Design tokens (TV: tv_home_discovery_updated_content) ───────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kSurfaceContainerHigh = Color(0xFFEAE8E2);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kBrand = Color(0xFF865213);
const _kAmber = Color(0xFFE2A05B);
const _kOutlineVariant = Color(0xFFD6C3B4);
const _kOnPrimaryContainer = Color(0xFF613700); // on-primary-container chip text

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
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchNotifierProvider.notifier).search(value);
    });
  }

  void _onSearchSubmitted(String value) {
    _debounce?.cancel();
    if (value.isEmpty) return;
    setState(() => _searchActive = true);
    ref.read(searchNotifierProvider.notifier).search(value);
  }

  void _onHistoryChipTap(String keyword) {
    _searchCtrl.text = keyword;
    setState(() => _searchActive = true);
    ref.read(searchNotifierProvider.notifier).search(keyword);
  }

  Future<void> _openSearchDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _TvSearchDialog(
        initialValue: _searchCtrl.text,
      ),
    );
    if (result == null) return; // cancelled
    _searchCtrl.text = result;
    _onSearchSubmitted(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBackground,
      child: Column(
        children: [
          // ── Sticky header ─────────────────────────────────────────────────
          _TvSearchHeader(
            queryText: _searchCtrl.text,
            onTap: _openSearchDialog,
            onClear: () {
              _searchCtrl.text = '';
              _onSearchChanged('');
            },
          ),
          // ── Scrollable content ────────────────────────────────────────────
          Expanded(
            child: _searchActive
                ? _SearchResultsBody()
                : _IdleBody(onHistoryChipTap: _onHistoryChipTap),
          ),
        ],
      ),
    );
  }
}

// ─── Search header ────────────────────────────────────────────────────────────

class _TvSearchHeader extends StatelessWidget {
  const _TvSearchHeader({
    required this.queryText,
    required this.onTap,
    required this.onClear,
  });

  final String queryText;
  final VoidCallback onTap;
  final VoidCallback onClear;

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
          const Spacer(),
          // Tappable search pill — opens a dialog with a keyboard on TV.
          GestureDetector(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, minWidth: 240),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _kSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                  border: queryText.isNotEmpty
                      ? Border.all(color: _kAmber, width: 2)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search,
                        color: _kBrand, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        queryText.isEmpty
                            ? '搜索歌手、曲目、专辑…'
                            : queryText,
                        style: TextStyle(
                          fontSize: 15,
                          color: queryText.isEmpty
                              ? _kOnSurfaceVariant.withValues(alpha: 0.6)
                              : _kOnSurface,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (queryText.isNotEmpty)
                      GestureDetector(
                        onTap: onClear,
                        child: const Icon(Icons.close,
                            color: _kOnSurfaceVariant, size: 18),
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

// ─── TV search dialog ────────────────────────────────────────────────────────

/// A dialog that hosts a [TextField] and auto-opens the TV soft keyboard.
class _TvSearchDialog extends StatefulWidget {
  const _TvSearchDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_TvSearchDialog> createState() => _TvSearchDialogState();
}

class _TvSearchDialogState extends State<_TvSearchDialog> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    Navigator.of(context).pop(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kBackground,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '搜索',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _kOnSurface,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                onSubmitted: _submit,
                onTapOutside: (_) {},
                textInputAction: TextInputAction.search,
                autofocus: true,
                style: const TextStyle(
                    fontSize: 17, color: _kOnSurface, height: 1.4),
                decoration: InputDecoration(
                  hintText: '搜索歌手、曲目、专辑…',
                  hintStyle: TextStyle(
                      color: _kOnSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 17),
                  prefixIcon:
                      const Icon(Icons.search, color: _kBrand, size: 22),
                  filled: true,
                  fillColor: _kSurfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _kAmber, width: 2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消',
                        style: TextStyle(
                            color: _kOnSurfaceVariant, fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kAmber,
                      foregroundColor: _kOnPrimaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _submit(_ctrl.text),
                    child: const Text('搜索',
                        style: TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Idle body (history + recently played) ────────────────────────────────────

class _IdleBody extends ConsumerWidget {
  const _IdleBody({required this.onHistoryChipTap});

  final ValueChanged<String> onHistoryChipTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
      children: [
        _SearchHistorySection(onChipTap: onHistoryChipTap),
        const SizedBox(height: 48),
        const _RecentlyPlayedSection(),
      ],
    );
  }
}

// ─── Search history ───────────────────────────────────────────────────────────

class _SearchHistorySection extends ConsumerWidget {
  const _SearchHistorySection({required this.onChipTap});

  final ValueChanged<String> onChipTap;

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
                  color: Color(0xBF865213), // _kBrand at 70% opacity
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
                onChipTap(keyword);
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
                  color: _kOnPrimaryContainer,
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TvPlayHistoryScreen()),
              ),
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
                      onMore: () =>
                          showTvSongActionDialog(context, ref, songs[i]),
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
    required this.onMore,
  });
  final Song song;
  final VoidCallback onPlay;
  final VoidCallback onMore;

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
                            child: SongCover(
                              source: widget.song.source.param,
                              picId: widget.song.picId,
                              size: 400,
                              width: 220,
                              height: 220,
                              fit: BoxFit.cover,
                              borderRadius: 0,
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
                // Artist • Album  +  more button
                Row(
                  children: [
                    Expanded(
                      child: Text(
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
                    ),
                    GestureDetector(
                      onTap: widget.onMore,
                      child: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: _focused ? _kBrand : _kOnSurfaceVariant,
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
        if (state.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: _kAmber, size: 40),
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(
                      color: _kOnSurfaceVariant, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _TvFocusButton(
                  onTap: () => ref
                      .read(searchNotifierProvider.notifier)
                      .search(state.keyword),
                  child: const Text(
                    '重试',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kBrand),
                  ),
                ),
              ],
            ),
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
              onMore: () =>
                  showTvSongActionDialog(context, ref, song),
            );
          },
        );
      },
    );
  }
}

/// TV-optimised song row for search results.
class _TvSongRow extends StatefulWidget {
  const _TvSongRow({
    required this.song,
    required this.onPlay,
    required this.onMore,
  });
  final Song song;
  final VoidCallback onPlay;
  final VoidCallback onMore;

  @override
  State<_TvSongRow> createState() => _TvSongRowState();
}

class _TvSongRowState extends State<_TvSongRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
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
              SongCover(
                source: widget.song.source.param,
                picId: widget.song.picId,
                size: 200,
                width: 56,
                height: 56,
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
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onMore,
                child: Icon(
                  Icons.more_vert,
                  color: _focused ? _kBrand : _kOnSurfaceVariant,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TV song action dialog (shared) ─────────────────────────────────────────

void showTvSongActionDialog(
    BuildContext context, WidgetRef ref, Song song) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kSurfaceContainerLow,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        song.name,
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
                leading:
                    const Icon(Icons.play_arrow, color: _kBrand),
                title: const Text('立即播放',
                    style: TextStyle(
                        fontSize: 16, color: _kOnSurface)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref2
                      .read(playerNotifierProvider.notifier)
                      .playSong(song);
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading:
                    const Icon(Icons.add_to_queue, color: _kBrand),
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
                    color: _kBrand),
                title: Text(isFav ? '取消收藏' : '收藏',
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
                leading:
                    const Icon(Icons.playlist_add, color: _kBrand),
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
    BuildContext context, WidgetRef ref, Song song) {
  final playlists =
      ref.read(playlistNotifierProvider).valueOrNull?.playlists ?? [];
  if (playlists.isEmpty) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kSurfaceContainerLow,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
