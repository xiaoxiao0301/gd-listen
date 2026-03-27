import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/theme.dart';

/// Mobile app shell with bottom navigation and a global mini player slot.
///
/// Tab layout:
///   0 – 发现 (Home / Search)
///   1 – 我的歌单 (Playlists)
///   2 – 收藏 (Favorites)
///   3 – 设置 (Settings)
///
/// The [MiniPlayer] will be wired in Phase 1 (P1-09); it is kept as a
/// placeholder here so the shell compiles immediately.
class MobileAppShell extends ConsumerStatefulWidget {
  const MobileAppShell({super.key});

  @override
  ConsumerState<MobileAppShell> createState() => _MobileAppShellState();
}

class _MobileAppShellState extends ConsumerState<MobileAppShell> {
  int _currentIndex = 0;

  // Placeholder page widgets — replaced tab-by-tab as features land.
  static const List<Widget> _pages = [
    _PlaceholderPage(label: '发现', icon: Icons.search),
    _PlaceholderPage(label: '我的歌单', icon: Icons.queue_music),
    _PlaceholderPage(label: '收藏', icon: Icons.favorite),
    _PlaceholderPage(label: '设置', icon: Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // IndexedStack keeps all tab states alive.
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          // ── Mini Player slot ───────────────────────────────────────────
          // Will be replaced by the real MiniPlayer widget in P1-09.
          const Positioned(
            bottom: kBottomNavigationBarHeight,
            left: 0,
            right: 0,
            child: _MiniPlayerPlaceholder(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue_music),
            label: '歌单',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: '收藏',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

// ── Internal placeholders ─────────────────────────────────────────────────────

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: WarmColors.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: WarmColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '// TODO: implement',
            style: TextStyle(
              fontSize: 13,
              color: WarmColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder that occupies the mini-player slot.
/// Will be replaced by MiniPlayer widget in P1-09.
class _MiniPlayerPlaceholder extends StatelessWidget {
  const _MiniPlayerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: WarmColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WarmColors.primary.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '── Mini Player (P1-09) ──',
          style: TextStyle(
            fontSize: 12,
            color: WarmColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
