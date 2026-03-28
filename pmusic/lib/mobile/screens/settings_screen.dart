import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../features/cache/cache_notifier.dart';
import '../../features/settings/settings_notifier.dart';
import '../../features/settings/settings_repository.dart';

// ─── Design tokens (settings/code.html) ──────────────────────────────────────

const _kBg = Color(0xFFFBF9F3);
const _kSurfaceLow = Color(0xFFF5F3EE);
const _kSurfaceLowest = Color(0xFFFFFFFF);
const _kSurfaceHighest = Color(0xFFE4E2DD);
const _kOnSurface = Color(0xFF1B1C19);
const _kOnSurfaceVariant = Color(0xFF514439);
const _kPrimary = Color(0xFF865213);
const _kPrimaryContainer = Color(0xFFE2A05B);
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

/// Mobile settings screen.
///
/// Matches `settings/code.html` 1:1:
///  • Sticky top bar: arrow_back + "Settings" (amber) + more_vert
///  • Hero branding: "The Analog Soul" + subtitle
///  • Section 播放: source dropdown + quality dropdown
///  • Section 缓存: slider (128–4096 MB) + usage bar + clear button
///  • Section 歌词: translation toggle
///  • Section 网络: offline toggle
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Local value while slider is being dragged – avoids DB writes per frame.
  double? _pendingSlider;

  void _save(AppSettings Function(AppSettings) update) {
    final s = ref.read(settingsNotifierProvider).valueOrNull;
    if (s == null) return;
    ref.read(settingsNotifierProvider.notifier).saveSettings(update(s));
  }

  void _showSourcePicker(AppSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurfaceLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kSurfaceHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                '默认音乐源',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _kOnSurface,
                ),
              ),
            ),
            ...MusicSource.values.take(8).map((src) => ListTile(
                  title: Text(
                    _sourceName(src),
                    style: TextStyle(
                      color: _kOnSurface,
                      fontWeight: settings.defaultSource == src
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: settings.defaultSource == src
                      ? const Icon(Icons.check_circle, color: _kPrimary)
                      : null,
                  onTap: () {
                    _save((s) => s.copyWith(defaultSource: src));
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showQualityPicker(AppSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurfaceLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kSurfaceHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: const Text(
                '音质偏好',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _kOnSurface,
                ),
              ),
            ),
            ...AudioQuality.values.map((q) => ListTile(
                  title: Text(
                    _qualityName(q),
                    style: TextStyle(
                      color: _kOnSurface,
                      fontWeight: settings.audioQuality == q
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: settings.audioQuality == q
                      ? const Icon(Icons.check_circle, color: _kPrimary)
                      : null,
                  onTap: () {
                    _save((s) => s.copyWith(audioQuality: q));
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
          ],
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
            child: const Text('清空', style: TextStyle(color: _kError)),
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
      loading: () => const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _kBg,
        body: Center(child: Text('加载失败: $e')),
      ),
      data: (settings) {
        final sliderVal =
            _pendingSlider ?? settings.cacheMaxMb.toDouble().clamp(128.0, 4096.0);
        final usedMb = cacheAsync.valueOrNull?.usedMb ?? 0;
        final maxMb = settings.cacheMaxMb;
        final ratio =
            maxMb == 0 ? 0.0 : (usedMb / maxMb).clamp(0.0, 1.0);

        return Scaffold(
          backgroundColor: _kBg,
          body: CustomScrollView(
            slivers: [
              // ── Sticky top app bar ────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: _kBg,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: const Icon(Icons.arrow_back, color: _kPrimary),
                ),
                title: const Text(
                  'Settings',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: _kPrimary,
                  ),
                ),
                centerTitle: false,
                actions: [
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.more_vert, color: _kPrimary),
                  ),
                ],
              ),

              // ── Scrollable content ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                sliver: SliverList.list(
                  children: [
                    // ── Hero branding ─────────────────────────────────────
                    const Text(
                      'The Analog Soul',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        color: _kOnSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Personalize your tactile audio experience.',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: _kOnSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Section: 播放 ─────────────────────────────────────
                    const _SectionHeader(icon: Icons.tune, label: '播放'),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _DropdownRow(
                        label: '默认音乐源',
                        sublabel: '选择偏好的音频流服务',
                        value: _sourceName(settings.defaultSource),
                        onTap: () => _showSourcePicker(settings),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0x1AD6C3B4)),
                      const SizedBox(height: 16),
                      _DropdownRow(
                        label: '音质偏好',
                        sublabel: '根据您的设备调整码率',
                        value: _qualityName(settings.audioQuality),
                        onTap: () => _showQualityPicker(settings),
                      ),
                    ]),
                    const SizedBox(height: 32),

                    // ── Section: 缓存 ─────────────────────────────────────
                    const _SectionHeader(icon: Icons.storage, label: '缓存'),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      // 缓存上限 label + live MB value
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('缓存上限',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _kOnSurface)),
                          Text(
                            '${sliderVal.round()}MB',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: _kPrimary,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _kPrimary,
                          inactiveTrackColor: _kSurfaceHighest,
                          thumbColor: _kPrimary,
                          overlayColor: _kPrimary.withValues(alpha: 0.12),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16),
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                        child: Slider(
                          value: sliderVal,
                          min: 128,
                          max: 4096,
                          divisions: 30,
                          onChanged: (v) =>
                              setState(() => _pendingSlider = v),
                          onChangeEnd: (v) {
                            setState(() => _pendingSlider = null);
                            _save((s) => s.copyWith(cacheMaxMb: v.round()));
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('128MB',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _kOnSurfaceVariant)),
                          Text('4096MB',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _kOnSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Usage progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  color: _kOnSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 12,
                          backgroundColor: _kSurfaceHighest,
                          valueColor:
                              const AlwaysStoppedAnimation(_kPrimaryContainer),
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: _confirmClearCache,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _kError),
                          foregroundColor: _kError,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('清空缓存数据',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ]),
                    const SizedBox(height: 32),

                    // ── Section: 歌词 ─────────────────────────────────────
                    const _SectionHeader(icon: Icons.lyrics, label: '歌词'),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _ToggleRow(
                        label: '歌词翻译',
                        sublabel: '显示原文与中文对照',
                        value: settings.lyricTranslation,
                        onChanged: (v) =>
                            _save((s) => s.copyWith(lyricTranslation: v)),
                      ),
                    ]),
                    const SizedBox(height: 32),

                    // ── Section: 网络 ─────────────────────────────────────
                    const _SectionHeader(icon: Icons.wifi_off, label: '网络'),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _ToggleRow(
                        label: '离线模式',
                        sublabel: '仅播放已下载的曲目',
                        value: settings.offlineMode,
                        onChanged: (v) =>
                            _save((s) => s.copyWith(offlineMode: v)),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kPrimary, size: 18),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.5,
            color: _kOnSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
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
                      fontSize: 14,
                      color: _kOnSurface)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: const TextStyle(
                      fontSize: 11, color: _kOnSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _kSurfaceLowest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kPrimary)),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, color: _kPrimary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

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
                      fontSize: 14,
                      color: _kOnSurface)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: const TextStyle(
                      fontSize: 11, color: _kOnSurfaceVariant)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? _kPrimaryContainer
                : const Color(0xFFE4E2DD);
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ],
    );
  }
}
