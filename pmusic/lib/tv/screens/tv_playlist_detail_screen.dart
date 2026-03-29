import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../features/favorite/favorite_notifier.dart';
import '../../features/player/player_notifier.dart';
import '../../features/playlist/playlist_notifier.dart';
import '../../mobile/widgets/song_cover_image.dart';
import '../widgets/tv_mini_player_bar.dart';

// ─── Design tokens (tv_playlist_detail/code.html) ────────────────────────────

const _kBackground = Color(0xFFFBF9F3);
const _kSurfaceContainerLow = Color(0xFFF5F3EE);
const _kSurfaceContainerHigh = Color(0xFFEAE8E2);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kNavInactive = Color(0xFF5A5B58);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);

/// TV Playlist Detail Screen.
///
/// Matches `tv_playlist_detail/code.html` design 1:1:
///  • Fixed left sidebar 288 px: brand + nav items (Playlists active)
///  • Hero: 400 px full-width 2×2 mosaic with gradient overlays
///  • "CURATED COLLECTION" label + playlist name (60 px extrabold)
///  • Action row: "Play All" (gradient) + "Shuffle" (outlined) + heart icon
///  • Song list: focusable rows, left-border highlight on focus/playing
///  • Bottom: TvMiniPlayerBar (96 px)
class TvPlaylistDetailScreen extends ConsumerStatefulWidget {
  const TvPlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
    this.description = '',
  });

  final int playlistId;
  final String playlistName;
  final String description;

  @override
  ConsumerState<TvPlaylistDetailScreen> createState() =>
      _TvPlaylistDetailScreenState();
}

class _TvPlaylistDetailScreenState
    extends ConsumerState<TvPlaylistDetailScreen> {
  TvPlayerTab _activeTab = TvPlayerTab.controls;

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(playlistSongsProvider(widget.playlistId));

    return Scaffold(
      backgroundColor: _kBackground,
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left Sidebar ──────────────────────────────────────────────
              _TvSidebar(onBack: () => Navigator.of(context).pop()),

              // ── Main Content ──────────────────────────────────────────────
              Expanded(
                child: songsAsync.when(
                  data: (songs) => _buildContent(songs),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: _kPrimaryContainer),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      '加载失败: $e',
                      style: const TextStyle(
                          color: _kOnSurfaceVariant, fontSize: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom Player Bar ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: TvMiniPlayerBar(
              activeTab: _activeTab,
              onTabChanged: (tab) => setState(() => _activeTab = tab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Song> songs) {
    final playerState = ref.watch(playerNotifierProvider).valueOrNull;
    final currentSong = playerState?.currentSong;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 128),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero header ────────────────────────────────────────────────
          _HeroHeader(
            songs: songs,
            playlistName: widget.playlistName,
            description: widget.description.isEmpty
                ? '精选收藏，静心聆听。每一首都是时光的馈赠。'
                : widget.description,
            onPlayAll: songs.isEmpty
                ? null
                : () => ref
                    .read(playerNotifierProvider.notifier)
                    .setQueue(songs),
            onShuffle: songs.isEmpty
                ? null
                : () {
                    final shuffled = [...songs]..shuffle(Random());
                    ref
                        .read(playerNotifierProvider.notifier)
                        .setQueue(shuffled);
                  },
            onFavorite: songs.isEmpty
                ? null
                : () {
                    final favNotifier =
                        ref.read(favoriteNotifierProvider.notifier);
                    final favState =
                        ref.read(favoriteNotifierProvider).valueOrNull;
                    for (final s in songs) {
                      if (favState?.isFavorite(s) != true) {
                        favNotifier.toggle(s);
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('已全部收藏到我喜欢')),
                    );
                  },
          ),

          // ── Song list ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 32, 48, 0),
            child: songs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        '歌单暂无歌曲',
                        style: TextStyle(
                            color: _kOnSurfaceVariant, fontSize: 18),
                      ),
                    ),
                  )
                : Column(
                    children: List.generate(songs.length, (index) {
                      final song = songs[index];
                      final isPlaying = currentSong != null &&
                          currentSong.id == song.id &&
                          currentSong.source == song.source;
                      return _TvSongRow(
                        song: song,
                        isPlaying: isPlaying,
                        onTap: () => ref
                            .read(playerNotifierProvider.notifier)
                            .setQueue(songs, startIndex: index),
                        onMore: () =>
                            _showSongActions(context, song),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  void _showSongActions(BuildContext context, Song song) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Text(
          song.name,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _kOnSurface,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.play_arrow, color: _kPrimary),
                title: const Text('播放',
                    style: TextStyle(
                        fontSize: 18, color: _kOnSurface)),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading:
                    const Icon(Icons.queue_music, color: _kPrimary),
                title: const Text('添加到播放队列',
                    style: TextStyle(
                        fontSize: 18, color: _kOnSurface)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(playerNotifierProvider.notifier)
                      .addToQueue(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_remove,
                    color: _kPrimary),
                title: const Text('从歌单中删除',
                    style: TextStyle(
                        fontSize: 18, color: _kOnSurface)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(playlistNotifierProvider.notifier)
                      .removeSong(widget.playlistId, song.id)
                      .then((_) => ref.invalidate(
                          playlistSongsProvider(widget.playlistId)));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────

class _TvSidebar extends StatelessWidget {
  const _TvSidebar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 288,
      color: _kBackground,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The Analog Soul',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kPrimary,
            ),
          ),
          const SizedBox(height: 48),
          _SidebarNavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            isActive: false,
            onTap: onBack,
          ),
          _SidebarNavItem(
            icon: Icons.library_music,
            label: 'Playlists',
            isActive: true,
            onTap: () {},
          ),
          _SidebarNavItem(
            icon: Icons.favorite_border,
            label: '收藏全部',
            isActive: false,
            onTap: () {},
          ),
          _SidebarNavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isActive: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _focused || widget.isActive;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          padding: widget.isActive
              ? const EdgeInsets.only(left: 20, right: 24, top: 16, bottom: 16)
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: widget.isActive ? _kSurfaceContainerLow : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: widget.isActive
                ? const Border(
                    left: BorderSide(color: _kPrimary, width: 4),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: highlighted ? _kPrimary : _kNavInactive,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 18,
                  fontWeight: widget.isActive
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: highlighted ? _kPrimary : _kNavInactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero Header ─────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.songs,
    required this.playlistName,
    required this.description,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onFavorite,
  });

  final List<Song> songs;
  final String playlistName;
  final String description;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final VoidCallback? onFavorite;

  static const _gradients = [
    [Color(0xFFBF7340), Color(0xFF8B4B1A)],
    [Color(0xFFD49A5A), Color(0xFFA0652A)],
    [Color(0xFF8B5E3C), Color(0xFF5C3718)],
    [Color(0xFFCC8844), Color(0xFF8C5219)],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 2×2 mosaic
          GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: List.generate(4, (i) {
              final song = i < songs.length ? songs[i] : null;
              final grads = _gradients[i % _gradients.length];
              if (song != null) {
                return SongCover(
                  source: song.source.param,
                  picId: song.picId,
                  size: 400,
                  fit: BoxFit.cover,
                  width: 300,
                  height: 300,
                  borderRadius: 0,
                );
              }
              return _GradCell(grads: grads);
            }),
          ),

          // Top-to-bottom gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _kBackground.withValues(alpha: 0.40),
                  _kBackground,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Left-to-right gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _kBackground.withValues(alpha: 0.80),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Content overlay
          Positioned(
            bottom: 0,
            left: 48,
            right: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURATED COLLECTION',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  playlistName,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 60,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: _kOnSurface,
                    height: 1.0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: _kOnSurfaceVariant,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _HeroButton(
                      label: 'Play All',
                      icon: Icons.play_arrow,
                      gradient: const LinearGradient(
                          colors: [_kPrimary, _kPrimaryContainer]),
                      textColor: Colors.white,
                      onTap: onPlayAll,
                    ),
                    const SizedBox(width: 16),
                    _HeroButton(
                      label: 'Shuffle',
                      icon: Icons.shuffle,
                      isOutlined: true,
                      onTap: onShuffle,
                    ),
                    const SizedBox(width: 16),
                    _HeroIconButton(
                      icon: Icons.favorite_border,
                      onTap: onFavorite,
                    ),
                  ],
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradCell extends StatelessWidget {
  const _GradCell({required this.grads});

  final List<Color> grads;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: grads,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

// ─── Hero Buttons ─────────────────────────────────────────────────────────────

class _HeroButton extends StatefulWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    this.gradient,
    this.textColor,
    this.isOutlined = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final LinearGradient? gradient;
  final Color? textColor;
  final bool isOutlined;
  final VoidCallback? onTap;

  @override
  State<_HeroButton> createState() => _HeroButtonState();
}

class _HeroButtonState extends State<_HeroButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.textColor ?? _kPrimary;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            border: widget.isOutlined
                ? Border.all(color: _kPrimary, width: 2)
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.gradient != null
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFF865213).withValues(alpha: 0.20),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: fg, size: 20),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: fg,
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

class _HeroIconButton extends StatefulWidget {
  const _HeroIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_HeroIconButton> createState() => _HeroIconButtonState();
}

class _HeroIconButtonState extends State<_HeroIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _focused
                ? _kSurfaceContainerHigh
                : _kSurfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: _focused
                ? Border.all(color: _kPrimary, width: 2)
                : null,
          ),
          child: Icon(widget.icon, color: _kPrimary, size: 22),
        ),
      ),
    );
  }
}

// ─── TV Song Row ──────────────────────────────────────────────────────────────

class _TvSongRow extends StatefulWidget {
  const _TvSongRow({
    required this.song,
    required this.isPlaying,
    required this.onTap,
    required this.onMore,
  });

  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  State<_TvSongRow> createState() => _TvSongRowState();
}

class _TvSongRowState extends State<_TvSongRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _focused || widget.isPlaying;

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: highlighted
              ? const EdgeInsets.only(left: 12, top: 16, bottom: 16, right: 16)
              : const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: highlighted ? _kSurfaceContainerLow : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: highlighted
                ? const Border(
                    left: BorderSide(color: _kPrimary, width: 4),
                  )
                : null,
          ),
          child: Row(
            children: [
              // Album cover
              SongCover(
                source: widget.song.source.param,
                picId: widget.song.picId,
                size: 200,
                width: 48,
                height: 48,
              ),

              const SizedBox(width: 24),

              // Song name + artist
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.name,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: highlighted ? _kPrimary : _kOnSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.song.artistDisplay,
                      style: TextStyle(
                        fontSize: 13,
                        color: highlighted
                            ? _kPrimaryContainer
                            : _kOnSurfaceVariant,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              // Album column
              Expanded(
                flex: 1,
                child: Text(
                  widget.song.album,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: highlighted ? _kOnSurface : _kOnSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 32),

              // Duration (not in Song model, show dashes)
              Text(
                '--:--',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: highlighted ? _kPrimary : _kOnSurfaceVariant,
                ),
              ),

              const SizedBox(width: 32),

              // More button
              GestureDetector(
                onTap: widget.onMore,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.more_vert,
                    color: highlighted ? _kPrimary : _kOnSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
