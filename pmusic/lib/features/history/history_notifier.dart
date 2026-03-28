import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'history_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class HistoryState {
  const HistoryState({this.groups = const []});

  final List<HistoryGroup> groups;

  HistoryState copyWith({List<HistoryGroup>? groups}) =>
      HistoryState(groups: groups ?? this.groups);
}

// ─── Providers ───────────────────────────────────────────────────────────────

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final db = ref.read(appDatabaseProvider);
  return DriftHistoryRepository(db);
});

final historyNotifierProvider =
    AsyncNotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new,
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class HistoryNotifier extends AsyncNotifier<HistoryState> {
  late HistoryRepository _repo;

  @override
  Future<HistoryState> build() async {
    _repo = ref.read(historyRepositoryProvider);
    // Subscribe to live stream so the UI updates immediately after each play.
    final sub = _repo.watchAll().listen((entries) {
      state = AsyncValue.data(HistoryState(groups: _groupByDate(entries)));
    });
    ref.onDispose(sub.cancel);
    final initial = await _repo.getAll();
    return HistoryState(groups: _groupByDate(initial));
  }

  List<HistoryGroup> _groupByDate(List<HistoryEntry> entries) {
    if (entries.isEmpty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayEntries = <HistoryEntry>[];
    final yesterdayEntries = <HistoryEntry>[];
    final earlierEntries = <HistoryEntry>[];

    for (final e in entries) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.playedAt);
      final day = DateTime(d.year, d.month, d.day);
      if (day == today) {
        todayEntries.add(e);
      } else if (day == yesterday) {
        yesterdayEntries.add(e);
      } else {
        earlierEntries.add(e);
      }
    }

    return [
      if (todayEntries.isNotEmpty)
        HistoryGroup(label: '今天', entries: todayEntries),
      if (yesterdayEntries.isNotEmpty)
        HistoryGroup(label: '昨天', entries: yesterdayEntries),
      if (earlierEntries.isNotEmpty)
        HistoryGroup(label: '更早', entries: earlierEntries),
    ];
  }

  Future<void> clearHistory() async {
    await _repo.clear();
    state = const AsyncValue.data(HistoryState());
  }
}
