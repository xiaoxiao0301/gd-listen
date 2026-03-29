import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/theme.dart';
import '../features/player/player_notifier.dart';
import '../features/search/search_notifier.dart';
import 'screens/tv_favorites_screen.dart';
import 'screens/tv_home_screen.dart';
import 'screens/tv_my_playlists_screen.dart';
import 'screens/tv_play_history_screen.dart';
import 'screens/tv_play_queue_screen.dart';
import 'screens/tv_settings_screen.dart';
import 'widgets/tv_mini_player_bar.dart';

/// TV app shell with a collapsible left sidebar and a right content area.
///
/// Sidebar nav items mirror the mobile bottom tabs:
///   0 – 发现
///   1 – 我的歌单
///   2 – 收藏
///   3 – 设置
///
/// Bottom persistent player bar wired to TvMiniPlayerBar.
class TvAppShell extends ConsumerStatefulWidget {
  const TvAppShell({super.key});

  @override
  ConsumerState<TvAppShell> createState() => _TvAppShellState();
}

class _TvAppShellState extends ConsumerState<TvAppShell> {
  int _currentIndex = 0;
  bool _sidebarFocused = false;
  TvPlayerTab _activeTab = TvPlayerTab.controls;
  bool _showQueue = false;

  static const List<_TvNavItem> _navItems = [
    _TvNavItem(label: '发现', icon: Icons.search),
    _TvNavItem(label: '我的歌单', icon: Icons.queue_music),
    _TvNavItem(label: '播放历史', icon: Icons.history),
    _TvNavItem(label: '收藏', icon: Icons.favorite),
    _TvNavItem(label: '设置', icon: Icons.settings),
  ];

  static const List<Widget> _pages = [
    TvHomeScreen(),
    TvMyPlaylistsScreen(),
    TvPlayHistoryScreen(),
    TvFavoritesScreen(),
    TvSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Sidebar width: expanded when focused (288dp per design), icon-only (72dp).
    final sidebarWidth = _sidebarFocused ? 288.0 : 72.0;

    // P3-06: Global error toasts.
    ref.listen<AsyncValue<AppPlayerState>>(playerNotifierProvider, (prev, next) {
      final prevMsg = prev?.valueOrNull?.errorMessage;
      final nextMsg = next.valueOrNull?.errorMessage;
      if (nextMsg != null && nextMsg.isNotEmpty && nextMsg != prevMsg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextMsg),
            backgroundColor: const Color(0xFFBA1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    ref.listen<AsyncValue<SearchState>>(searchNotifierProvider, (prev, next) {
      final prevMsg = prev?.valueOrNull?.errorMessage;
      final nextMsg = next.valueOrNull?.errorMessage;
      if (nextMsg != null && nextMsg.isNotEmpty && nextMsg != prevMsg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextMsg),
            backgroundColor: const Color(0xFFBA1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: WarmColors.background,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Row(
          children: [
            // ── Left Sidebar ───────────────────────────────────────────────
            FocusTraversalGroup(
              child: Focus(
                onFocusChange: (v) => setState(() => _sidebarFocused = v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: sidebarWidth,
                  color: WarmColors.surface,
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // App logo / name
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: _sidebarFocused
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'The Analog Soul',
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: WarmColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tactile Curator',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: WarmColors.textSecondary,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Icon(
                                Icons.music_note,
                                color: WarmColors.primary,
                                size: 28,
                              ),
                      ),
                      const SizedBox(height: 32),
                      // Nav items
                      for (var i = 0; i < _navItems.length; i++)
                        _TvSidebarTile(
                          item: _navItems[i],
                          isSelected: _currentIndex == i,
                          showLabel: _sidebarFocused,
                          onTap: () => setState(() => _currentIndex = i),
                        ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
            // ── Right Content Area ─────────────────────────────────────────
            Expanded(
              child: FocusTraversalGroup(
                child: Stack(
                  children: [
                    IndexedStack(
                      index: _currentIndex,
                      children: _pages,
                    ),
                    // Queue overlay
                    if (_showQueue)
                      const TvPlayQueueScreen(),
                    // Bottom player bar — floating pill
                    Positioned(
                      bottom: 32,
                      left: 48,
                      right: 48,
                      child: TvMiniPlayerBar(
                        activeTab: _activeTab,
                        onTabChanged: (tab) {
                          setState(() {
                            _activeTab = tab;
                            _showQueue = tab == TvPlayerTab.queue;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Internal TV components ────────────────────────────────────────────────────

class _TvNavItem {
  const _TvNavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _TvSidebarTile extends StatefulWidget {
  const _TvSidebarTile({
    required this.item,
    required this.isSelected,
    required this.showLabel,
    required this.onTap,
  });

  final _TvNavItem item;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  State<_TvSidebarTile> createState() => _TvSidebarTileState();
}

class _TvSidebarTileState extends State<_TvSidebarTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? WarmColors.primary
                : _focused
                    ? WarmColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: _focused && !widget.isSelected
                ? Border.all(color: WarmColors.primary, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                color: widget.isSelected
                    ? Colors.white
                    : _focused
                        ? WarmColors.primary
                        : WarmColors.textSecondary,
                size: 26,
              ),
              if (widget.showLabel) ...[
                const SizedBox(width: 14),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    color: widget.isSelected
                        ? Colors.white
                        : _focused
                            ? WarmColors.primary
                            : WarmColors.textSecondary,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w400,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
