import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../features/cache/cache_notifier.dart';
import '../../features/settings/settings_notifier.dart';
import '../../features/settings/settings_repository.dart';

// ─── Design tokens (tv_settings_aligned/code.html) ───────────────────────────

const _kSurface = Color(0xFFFBF9F3);
const _kSurfaceLow = Color(0xFFF5F3EE);
const _kSurfaceLowest = Color(0xFFFFFFFF);
const _kSurfaceHigh = Color(0xFFEAE8E2);
const _kSurfaceHighest = Color(0xFFE4E2DD);
const _kOnSurface = Color(0xFF1B1C19);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
const _kOutline = Color(0xFF847467);
const _kError = Color(0xFFBA1A1A);

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _sourceName(MusicSource s) => switch (s) {
      MusicSource.netease => '网易云音乐',
      MusicSource.kuwo => '酷我音乐',
      MusicSource.joox => 'JOOX',
      MusicSource.bilibili => '哔哩哔哩',
      MusicSource.tencent => 'QQ音乐',
      MusicSource.tidal => 'Tidal',
      MusicSource.spotify => 'Spotify',
      MusicSource.ytmusic => 'YouTube Music',
      MusicSource.qobuz => 'Qobuz',
      MusicSource.deezer => 'Deezer',
      MusicSource.migu => '咪咕音乐',
      MusicSource.kugou => '酷狗音乐',
      MusicSource.ximalaya => '喜马拉雅',
      MusicSource.apple => 'Apple Music',
    };

String _qualityName(AudioQuality q) => switch (q) {
      AudioQuality.q128 => '流畅 (128 kbps)',
      AudioQuality.q192 => '标准 (192 kbps)',
      AudioQuality.q320 => '高品质 (320 kbps)',
      AudioQuality.q740 => '无损 (740 kbps)',
      AudioQuality.q999 => '超清母带 (FLAC)',
    };

// ─── Screen ───────────────────────────────────────────────────────────────────

/// TV settings screen — right-pane content only (sidebar in TvAppShell).
///
/// Matches `tv_settings_aligned/code.html` 1:1:
///  • Sticky header: "设置" title + decorative search bar + icons
///  • 12-col grid with:
///    – Hero: "The Analog Soul" + subtitle (col-span-12)
///    – Playback card (col-8): source + quality dropdowns
///    – Cache card (col-4): slider + usage bar + clear button
///    – Lyrics card (col-6): translation toggle (larger TV switch)
///    – Network card (col-6): offline mode toggle (larger TV switch)
///    – Visual anchor banner (col-12)
///  • Cards get amber focus ring + scale when focused
class TvSettingsScreen extends ConsumerStatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  ConsumerState<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends ConsumerState<TvSettingsScreen> {
  double? _pendingSlider;

  void _save(AppSettings Function(AppSettings) update) {
    final s = ref.read(settingsNotifierProvider).valueOrNull;
    if (s == null) return;
    ref.read(settingsNotifierProvider.notifier).saveSettings(update(s));
  }

  void _showSourceDialog(AppSettings settings) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurfaceLowest,
        title: const Text('默认音乐源',
            style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: MusicSource.values
                .take(8)
                .map((src) => ListTile(
                      title: Text(_sourceName(src),
                          style: TextStyle(
                            color: _kOnSurface,
                            fontWeight: settings.defaultSource == src
                                ? FontWeight.w700
                                : FontWeight.w400,
                          )),
                      trailing: settings.defaultSource == src
                          ? const Icon(Icons.check_circle, color: _kPrimary)
                          : null,
                      onTap: () {
                        _save((s) => s.copyWith(defaultSource: src));
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showQualityDialog(AppSettings settings) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurfaceLowest,
        title: const Text('音质偏好',
            style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AudioQuality.values
                .map((q) => ListTile(
                      title: Text(_qualityName(q),
                          style: TextStyle(
                            color: _kOnSurface,
                            fontWeight: settings.audioQuality == q
                                ? FontWeight.w700
                                : FontWeight.w400,
                          )),
                      trailing: settings.audioQuality == q
                          ? const Icon(Icons.check_circle, color: _kPrimary)
                          : null,
                      onTap: () {
                        _save((s) => s.copyWith(audioQuality: q));
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('确认删除所有已缓存的音频文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('清空', style: const TextStyle(color: _kError)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(cacheNotifierProvider.notifier).clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('缓存已清空')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final cacheAsync = ref.watch(cacheNotifierProvider);

    return settingsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kPrimaryContainer)),
      error: (e, _) =>
          Center(child: Text('加载失败: $e', style: const TextStyle(color: _kOnSurface))),
      data: (settings) {
        final sliderVal =
            (_pendingSlider ?? settings.cacheMaxMb.toDouble()).clamp(128.0, 4096.0);
        final usedMb = cacheAsync.valueOrNull?.usedMb ?? 0;
        final maxMb = settings.cacheMaxMb;
        final ratio = maxMb == 0 ? 0.0 : (usedMb / maxMb).clamp(0.0, 1.0);

        return Scaffold(
          backgroundColor: _kSurface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Sticky header ─────────────────────────────────────────────
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 48),
                color: _kSurface.withValues(alpha: 0.9),
                child: Row(
                  children: [
                    const Text(
                      '设置',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        color: _kOnSurface,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable content ─────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(48, 32, 48, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero
                      const Text(
                        'The Analog Soul',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 36,
                          color: _kOnSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Personalize your tactile audio experience.',
                        style: TextStyle(
                            color: _kOutline,
                            fontWeight: FontWeight.w500,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 32),

                      // Row 1: 播放 (8-col) + 缓存 (4-col)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 8,
                              child: _TvFocusCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _TvCardHeader(
                                        icon: Icons.tune, label: '播放'),
                                    const SizedBox(height: 28),
                                    _TvDropdownRow(
                                      label: '默认音乐源',
                                      sublabel: '选择偏好的音频流服务',
                                      value: _sourceName(settings.defaultSource),
                                      onTap: () =>
                                          _showSourceDialog(settings),
                                    ),
                                    const SizedBox(height: 28),
                                    _TvDropdownRow(
                                      label: '音质偏好',
                                      sublabel: '根据您的设备调整码率',
                                      value:
                                          _qualityName(settings.audioQuality),
                                      onTap: () =>
                                          _showQualityDialog(settings),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              flex: 4,
                              child: _TvFocusCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _TvCardHeader(
                                        icon: Icons.storage, label: '缓存'),
                                    const SizedBox(height: 20),
                                    // Slider section
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text('缓存上限',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: _kOnSurface)),
                                        Text('${sliderVal.round()}MB',
                                            style: const TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontWeight: FontWeight.w800,
                                              fontSize: 24,
                                              color: _kPrimary,
                                            )),
                                      ],
                                    ),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: _kPrimary,
                                        inactiveTrackColor: _kSurfaceHighest,
                                        thumbColor: _kPrimary,
                                        overlayColor:
                                            _kPrimary.withValues(alpha: 0.12),
                                        trackHeight: 6,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                                enabledThumbRadius: 11),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                                overlayRadius: 20),
                                      ),
                                      child: Slider(
                                        value: sliderVal,
                                        min: 128,
                                        max: 4096,
                                        divisions: 30,
                                        onChanged: (v) => setState(
                                            () => _pendingSlider = v),
                                        onChangeEnd: (v) {
                                          setState(
                                              () => _pendingSlider = null);
                                          _save((s) =>
                                              s.copyWith(cacheMaxMb: v.round()));
                                        },
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Text('128MB',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _kOutline)),
                                        Text('4096MB',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _kOutline)),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('当前使用',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _kOnSurface)),
                                        Text('${usedMb}MB / ${maxMb}MB',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _kOutline)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 12,
                                        backgroundColor: _kSurfaceHighest,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                _kPrimaryContainer),
                                      ),
                                    ),
                                    const Spacer(),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: _confirmClearCache,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: _kError),
                                        foregroundColor: _kError,
                                        minimumSize:
                                            const Size(double.infinity, 56),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                      ),
                                      child: const Text('清空缓存数据',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Row 2: 歌词 (6-col) + 网络 (6-col)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _TvFocusCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _TvCardHeader(
                                          icon: Icons.lyrics, label: '歌词'),
                                      _TvToggleSwitch(
                                        value: settings.lyricTranslation,
                                        onChanged: (v) => _save((s) =>
                                            s.copyWith(lyricTranslation: v)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  const Text('歌词翻译',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20,
                                          color: _kOnSurface)),
                                  const SizedBox(height: 6),
                                  const Text('显示原文与中文对照',
                                      style: TextStyle(
                                          fontSize: 14, color: _kOutline)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: _TvFocusCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _TvCardHeader(
                                          icon: Icons.wifi_off, label: '网络'),
                                      _TvToggleSwitch(
                                        value: settings.offlineMode,
                                        onChanged: (v) => _save((s) =>
                                            s.copyWith(offlineMode: v)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  const Text('离线模式',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20,
                                          color: _kOnSurface)),
                                  const SizedBox(height: 6),
                                  const Text('仅播放已下载的曲目',
                                      style: TextStyle(
                                          fontSize: 14, color: _kOutline)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Visual anchor banner
                      Container(
                        height: 192,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFCC7A30),
                              Color(0xFF865213),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '探索极致声音',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w900,
                                fontSize: 36,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '了解更多关于 The Analog Soul 的声学设计',
                              style: TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── TV-specific sub-widgets ─────────────────────────────────────────────────

/// Card that shows an amber focus ring + slight scale on focus.
class _TvFocusCard extends StatefulWidget {
  const _TvFocusCard({required this.child});

  final Widget child;

  @override
  State<_TvFocusCard> createState() => _TvFocusCardState();
}

class _TvFocusCardState extends State<_TvFocusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedScale(
        scale: _focused ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _kSurfaceLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _focused
                  ? _kPrimary
                  : Colors.transparent,
              width: 3,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 0,
                    )
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _TvCardHeader extends StatelessWidget {
  const _TvCardHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kPrimary, size: 28),
        const SizedBox(width: 10),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.5,
            color: _kOutline,
          ),
        ),
      ],
    );
  }
}

class _TvDropdownRow extends StatelessWidget {
  const _TvDropdownRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: _kOnSurface)),
              const SizedBox(height: 3),
              Text(sublabel,
                  style:
                      const TextStyle(fontSize: 13, color: _kOutline)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Focus(
          child: Builder(builder: (ctx) {
            final isFocused = Focus.of(ctx).hasFocus;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isFocused
                      ? _kSurfaceHigh
                      : _kSurfaceLowest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0x4DD6C3B4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kPrimary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.expand_more,
                        color: _kPrimary, size: 20),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// TV-sized toggle switch matching the w-14 h-7 spec in tv_settings_aligned.
class _TvToggleSwitch extends StatelessWidget {
  const _TvToggleSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1.2,
      child: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? _kPrimary
              : _kSurfaceHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
