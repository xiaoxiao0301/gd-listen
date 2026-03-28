import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/theme.dart';
import '../features/player/player_notifier.dart';
import '../features/search/search_notifier.dart';
import 'screens/favorite_screen.dart';
import 'screens/full_player_screen.dart';
import 'screens/home_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/mini_player.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kNavBgBlur = Color(0xFBFBF9F3);
const _kBrand = Color(0xFF865213);
const _kNavInactive = Color(0xFF5D5E5A);
const _kIndicator = Color(0x1AE2A05B);
const _kBorderTop = Color(0x1AD6C3B4);

/// Mobile app shell — sticky BottomNavigationBar + glassmorphism MiniPlayer.
///
/// Tab layout:
///   0 – 发现 (HomeScreen)
///   1 – 我的歌单 (placeholder → P2-03)
///   2 – 收藏 (placeholder → P2-05)
///   3 – 设置 (placeholder → P3-01)
class MobileAppShell extends ConsumerStatefulWidget {
  const MobileAppShell({super.key});

  @override
  ConsumerState<MobileAppShell> createState() => _MobileAppShellState();
}

class _MobileAppShellState extends ConsumerState<MobileAppShell> {
  int _currentIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(label: '发现', icon: Icons.explore_outlined, activeIcon: Icons.explore),
    _NavItem(label: '歌单', icon: Icons.library_music_outlined, activeIcon: Icons.library_music),
    _NavItem(label: '收藏', icon: Icons.favorite_outline, activeIcon: Icons.favorite),
    _NavItem(label: '设置', icon: Icons.settings_outlined, activeIcon: Icons.settings),
  ];

  static const List<Widget> _pages = [
    HomeScreen(),
    PlaylistScreen(),
    FavoriteScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // P3-06: Global error toasts from player and search.
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
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(index: _currentIndex, children: _pages),
          Positioned(
            bottom: kBottomNavigationBarHeight + 8,
            left: 0,
            right: 0,
            child: MiniPlayer(
              onTap: () => pushFullPlayer(context),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _WarmBottomNav(
        selectedIndex: _currentIndex,
        items: _navItems,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─── Custom bottom navigation bar ────────────────────────────────────────────

class _WarmBottomNav extends StatelessWidget {
  const _WarmBottomNav({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: kBottomNavigationBarHeight + bottomPadding,
      decoration: const BoxDecoration(
        color: _kNavBgBlur,
        border: Border(top: BorderSide(color: _kBorderTop, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F865213),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(left: 8, right: 8, bottom: bottomPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final item = items[i];
            final isActive = i == selectedIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? _kIndicator : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? item.activeIcon : item.icon,
                      color: isActive ? _kBrand : _kNavInactive,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive ? _kBrand : _kNavInactive,
                        letterSpacing: 0.8,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Nav item model ───────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
}


