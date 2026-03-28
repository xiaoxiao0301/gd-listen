import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../features/history/history_notifier.dart';
import '../../features/player/player_notifier.dart';
import '../../features/search/search_notifier.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_action_sheet.dart';
import '../widgets/song_list_item.dart';

// ─── Design tokens (exact match to home_discovery_updated design) ─────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLowest = Color(0xFFFFFFFF);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kBrand = Color(0xFF865213);          // primary in design = text color
const _kPrimary = Color(0xFFE2A05B);        // primary-container = amber fill
const _kOutline = Color(0xFF847467);

/// Mobile home / discovery screen.
///
/// Matches the `home_discovery_updated` Stitch design exactly:
///  • Sticky top nav with app name + overflow menu
///  • Pill-shaped search bar
///  • Search-history chip row (horizontal scroll)
///  • Recently played list (from HistoryNotifier)
///  • When user types → debounced search → replace content with results
///  • Glassmorphism MiniPlayer floats above the BottomNav
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _searchActive = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search interaction ────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(searchNotifierProvider.notifier).clearSearch();
      setState(() => _searchActive = false);
      return;
    }
    setState(() => _searchActive = true);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchNotifierProvider.notifier).search(value.trim());
    });
  }

  void _onSearchSubmitted(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) return;
    setState(() => _searchActive = true);
    ref.read(searchNotifierProvider.notifier).search(value.trim());
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    ref.read(searchNotifierProvider.notifier).clearSearch();
    setState(() => _searchActive = false);
  }

  // ── Playback helpers ─────────────────────────────────────────────────────

  void _playSong(Song song) {
    ref.read(playerNotifierProvider.notifier).playSong(song);
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchNotifierProvider);
    final historyAsync = ref.watch(historyNotifierProvider);
    final playerAsync = ref.watch(playerNotifierProvider);

    final currentSongId =
        playerAsync.valueOrNull?.currentSong?.id;
    final hasMiniPlayer = playerAsync.valueOrNull?.currentSong != null;

    return Scaffold(
      backgroundColor: _kBackground,
      body: CustomScrollView(
        slivers: [
          // ── Sticky app bar ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: _kBackground,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: 56,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Icon(Icons.arrow_back, color: _kBrand, size: 24),
            ),
            title: Text(
              'The Analog Soul',
              style: TextStyle(
                color: _kBrand,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'Plus Jakarta Sans',
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(Icons.more_vert, color: _kBrand, size: 24),
              ),
            ],
          ),

          // ── Search bar ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                height: 56,
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                  style: const TextStyle(
                    color: _kOnSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: '搜索歌手、曲目、专辑…',
                    hintStyle: const TextStyle(
                      color: _kOutline,
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: _kSurfaceContainerLowest,
                    prefixIcon: const Icon(Icons.search, color: _kBrand),
                    suffixIcon: _searchActive
                        ? GestureDetector(
                            onTap: _clearSearch,
                            child: const Icon(Icons.close,
                                color: _kOutline, size: 20),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(
                          color: _kPrimary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 0),
                  ),
                ),
              ),
            ),
          ),

          // ── Content area: idle OR search results ────────────────────────
          searchAsync.when(
            data: (state) {
              if (_searchActive && state.isLoading) {
                return _loadingSliver();
              }

              if (_searchActive && state.results.isNotEmpty) {
                return _searchResultsSliver(state, currentSongId);
              }

              if (_searchActive && state.errorMessage != null) {
                return _errorSliver(state.errorMessage!);
              }

              // ── Idle view ──────────────────────────────────────────────
              return SliverList(
                delegate: SliverChildListDelegate([
                  // Search history chips
                  if (state.searchHistory.isNotEmpty)
                    _SearchHistorySection(
                      history: state.searchHistory,
                      onChipTap: (kw) {
                        _searchCtrl.text = kw;
                        _onSearchSubmitted(kw);
                      },
                      onRemoveTap: (kw) => ref
                          .read(searchNotifierProvider.notifier)
                          .removeHistory(kw),
                      onClearAll: () => ref
                          .read(searchNotifierProvider.notifier)
                          .clearHistory(),
                    ),

                  // Recently played
                  historyAsync.when(
                    data: (hs) {
                      final songs = hs.groups
                          .expand((g) => g.entries.map((e) => e.song))
                          .toList();
                      if (songs.isEmpty) return const SizedBox.shrink();
                      return _RecentlyPlayedSection(
                        songs: songs,
                        currentSongId: currentSongId,
                        onTap: _playSong,
                        onMore: (s) =>
                            showSongActionSheet(context, s),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  // Bottom padding above mini player + nav
                  SizedBox(
                    height: hasMiniPlayer
                        ? kMiniPlayerHeight + 72
                        : 72,
                  ),
                ]),
              );
            },
            loading: () => _loadingSliver(),
            error: (e, _) => _errorSliver(e.toString()),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _loadingSliver() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: _kPrimary),
        ),
      ),
    );
  }

  SliverToBoxAdapter _errorSliver(String message) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            message,
            style:
                const TextStyle(color: _kOnSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  SliverList _searchResultsSliver(
      SearchState state, String? currentSongId) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                '搜索结果',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kOnSurface,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            );
          }
          final songIndex = index - 1;
          if (songIndex >= state.results.length) {
            // Load more + bottom padding
            return Column(
              children: [
                if (state.hasMore && !state.isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: TextButton(
                      onPressed: () => ref
                          .read(searchNotifierProvider.notifier)
                          .loadMore(),
                      child: const Text(
                        '加载更多',
                        style: TextStyle(
                            color: _kBrand, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            );
          }
          final song = state.results[songIndex];
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: SongListItem(
              song: song,
              isPlaying: song.id == currentSongId,
              onTap: () => _playSong(song),
              onMore: () => showSongActionSheet(context, song),
            ),
          );
        },
        childCount: state.results.length + 2, // header + items + footer
      ),
    );
  }
}

// ─── Search history section ───────────────────────────────────────────────────

class _SearchHistorySection extends StatelessWidget {
  const _SearchHistorySection({
    required this.history,
    required this.onChipTap,
    required this.onRemoveTap,
    required this.onClearAll,
  });

  final List<String> history;
  final ValueChanged<String> onChipTap;
  final ValueChanged<String> onRemoveTap;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding:
              const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kOnSurface,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
              GestureDetector(
                onTap: onClearAll,
                child: Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kBrand,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Chip row (horizontal scroll)
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final kw = history[i];
              return GestureDetector(
                onTap: () => onChipTap(kw),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kw,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _kBrand,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onRemoveTap(kw),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: _kOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Recently played section ──────────────────────────────────────────────────

class _RecentlyPlayedSection extends StatelessWidget {
  const _RecentlyPlayedSection({
    required this.songs,
    required this.currentSongId,
    required this.onTap,
    required this.onMore,
  });

  final List<Song> songs;
  final String? currentSongId;
  final ValueChanged<Song> onTap;
  final ValueChanged<Song> onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近播放',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kOnSurface,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
              Row(
                children: [
                  Text(
                    '查看全部',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kBrand,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: _kBrand),
                ],
              ),
            ],
          ),
        ),

        // Song list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: songs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final s = songs[i];
            return SongListItem(
              song: s,
              isPlaying: s.id == currentSongId,
              onTap: () => onTap(s),
              onMore: () => onMore(s),
            );
          },
        ),
      ],
    );
  }
}
