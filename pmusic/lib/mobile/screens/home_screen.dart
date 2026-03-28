import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../features/history/history_notifier.dart';
import 'history_screen.dart';
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
const _kOnPrimaryContainer = Color(0xFF613700); // on-primary-container chip text

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

          // ── Search mode chips (visible when search active) ──────────────
          if (_searchActive)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: searchAsync.when(
                  data: (state) => Row(
                    children: [
                      _ModeChip(
                        label: '歌曲',
                        selected: !state.albumMode,
                        onSelected: (_) => ref
                            .read(searchNotifierProvider.notifier)
                            .setAlbumMode(false),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(
                        label: '专辑',
                        selected: state.albumMode,
                        onSelected: (_) => ref
                            .read(searchNotifierProvider.notifier)
                            .setAlbumMode(true),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
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
                        onViewAll: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const HistoryScreen(),
                          ),
                        ),
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
    if (state.albumMode) {
      return _albumResultsSliver(state);
    }
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

  /// Groups [state.results] by album and renders a 2-col grid of album cards.
  SliverList _albumResultsSliver(SearchState state) {
    // Deduplicate & group songs by album name.
    final groups = <String, ({String name, String artist, String picId, String source, List<Song> songs})>{};
    for (final song in state.results) {
      final key = '${song.album}|${song.artistDisplay}';
      if (!groups.containsKey(key)) {
        groups[key] = (
          name: song.album.isNotEmpty ? song.album : '未知专辑',
          artist: song.artistDisplay,
          picId: song.picId,
          source: song.source.param,
          songs: [],
        );
      }
      groups[key]!.songs.add(song);
    }
    final albums = groups.values.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                '专辑结果 (${albums.length})',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kOnSurface,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            );
          }
          if (index > albums.length) return const SizedBox(height: 80);
          final album = albums[index - 1];
          return _AlbumCard(
            name: album.name,
            artist: album.artist,
            picId: album.picId,
            source: album.source,
            songCount: album.songs.length,
            onTap: () => _playSong(album.songs.first),
          );
        },
        childCount: albums.length + 2,
      ),
    );
  }
}

// ─── Album card widget ────────────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.name,
    required this.artist,
    required this.picId,
    required this.source,
    required this.songCount,
    required this.onTap,
  });
  final String name, artist, picId, source;
  final int songCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Build cover URL from picId (same format as SongListItem).
    final coverUrl = picId.isNotEmpty
        ? 'https://music-api.gdstudio.xyz/api.php?types=pic&id=$picId&source=$source'
        : '';
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, _) =>
                          const _AlbumCoverPlaceholder(),
                    )
                  : const _AlbumCoverPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _kOnSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$artist · $songCount 首',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_circle_outline, color: _kBrand, size: 28),
          ],
        ),
      ),
    );
  }
}

class _AlbumCoverPlaceholder extends StatelessWidget {
  const _AlbumCoverPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFFE4E2DD),
      child: const Icon(Icons.album, size: 28, color: Color(0xFF847467)),
    );
  }
}

// ─── Mode chip ────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: const Color(0xFFE2A05B),
      checkmarkColor: const Color(0xFF613700),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? const Color(0xFF613700) : const Color(0xFF514439),
      ),
      backgroundColor: const Color(0xFFF5F3EE),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  '清空'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kBrand,
                    letterSpacing: 1.5,
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
                          color: _kOnPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onRemoveTap(kw),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: _kOnPrimaryContainer,
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
    this.onViewAll,
  });

  final List<Song> songs;
  final String? currentSongId;
  final ValueChanged<Song> onTap;
  final ValueChanged<Song> onMore;
  final VoidCallback? onViewAll;

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
              GestureDetector(
                onTap: onViewAll,
                child: Row(
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
