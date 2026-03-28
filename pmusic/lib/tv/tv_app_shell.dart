import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/theme.dart';
import 'screens/tv_home_screen.dart';

/// TV app shell with a collapsible left sidebar and a right content area.
///
/// Sidebar nav items mirror the mobile bottom tabs:
///   0 – 发现
///   1 – 我的歌单
///   2 – 收藏
///   3 – 设置
///
/// The bottom persistent player bar will be added in Phase 4 (P4-06).
class TvAppShell extends ConsumerStatefulWidget {
  const TvAppShell({super.key});

  @override
  ConsumerState<TvAppShell> createState() => _TvAppShellState();
}

class _TvAppShellState extends ConsumerState<TvAppShell> {
  int _currentIndex = 0;
  bool _sidebarFocused = false;

  static const List<_TvNavItem> _navItems = [
    _TvNavItem(label: '发现', icon: Icons.search),
    _TvNavItem(label: '我的歌单', icon: Icons.queue_music),
    _TvNavItem(label: '收藏', icon: Icons.favorite),
    _TvNavItem(label: '设置', icon: Icons.settings),
  ];

  static const List<Widget> _pages = [
    TvHomeScreen(),
    _TvPlaceholderPage(label: '我的歌单', icon: Icons.queue_music),
    _TvPlaceholderPage(label: '收藏', icon: Icons.favorite),
    _TvPlaceholderPage(label: '设置', icon: Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    // Sidebar width: expanded when focused (220), icon-only otherwise (72).
    final sidebarWidth = _sidebarFocused ? 220.0 : 72.0;

    return Scaffold(
      backgroundColor: WarmColors.background,
      body: Row(
        children: [
          // ── Left Sidebar ─────────────────────────────────────────────────
          Focus(
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
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'pmusic',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: WarmColors.primary,
                              ),
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
                ],
              ),
            ),
          ),
          // ── Right Content Area ───────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
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
    final highlighted = _focused || widget.isSelected;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: highlighted
                ? WarmColors.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: _focused
                ? Border.all(color: WarmColors.primary, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                color: highlighted
                    ? WarmColors.primary
                    : WarmColors.textSecondary,
                size: 26,
              ),
              if (widget.showLabel) ...[
                const SizedBox(width: 14),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    color: highlighted
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

class _TvPlaceholderPage extends StatelessWidget {
  const _TvPlaceholderPage({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: WarmColors.primary),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: WarmColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '// TV screen — to be implemented in Phase 4',
            style: TextStyle(fontSize: 18, color: WarmColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
