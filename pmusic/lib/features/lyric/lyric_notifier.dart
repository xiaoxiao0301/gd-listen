import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/lyric_line.dart';
import 'lyric_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class LyricState {
  const LyricState({
    this.lines = const [],
    this.currentIndex = 0,
  });

  final List<LyricLine> lines;

  /// Index of the line that should be highlighted at the current [position].
  final int currentIndex;

  LyricState copyWith({List<LyricLine>? lines, int? currentIndex}) {
    return LyricState(
      lines: lines ?? this.lines,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final lyricRepositoryProvider = Provider<LyricRepository>((ref) {
  return StubLyricRepository();
});

/// Family keyed by `(songId, source)` so each song caches its own lyric state.
final lyricNotifierProvider = AsyncNotifierProvider.family<
    LyricNotifier, LyricState, (String, String)>(
  LyricNotifier.new,
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class LyricNotifier
    extends FamilyAsyncNotifier<LyricState, (String, String)> {
  late LyricRepository _repo;

  @override
  Future<LyricState> build((String, String) arg) async {
    _repo = ref.read(lyricRepositoryProvider);
    final (songId, source) = arg;
    final lines = await _repo.getLyrics(songId, source);
    return LyricState(lines: lines);
  }

  /// Update [LyricState.currentIndex] based on the player's current [position].
  void syncPosition(Duration position) {
    final current = state.valueOrNull;
    if (current == null || current.lines.isEmpty) return;

    // Find the last line whose timestamp <= position.
    var idx = 0;
    for (var i = 0; i < current.lines.length; i++) {
      if (current.lines[i].timestamp <= position) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != current.currentIndex) {
      state = AsyncValue.data(current.copyWith(currentIndex: idx));
    }
  }
}
