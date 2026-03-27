import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return InMemoryHistoryRepository();
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
    return _buildState();
  }

  Future<HistoryState> _buildState() async {
    final entries = await _repo.getAll();
    return HistoryState(groups: _groupByDate(entries));
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
