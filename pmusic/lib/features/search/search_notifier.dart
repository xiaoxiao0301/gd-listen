import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../settings/settings_notifier.dart';
import 'search_repository.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class SearchState {
  const SearchState({
    this.keyword = '',
    this.results = const [],
    this.searchHistory = const [],
    this.currentPage = 1,
    this.isLoading = false,
    this.hasMore = true,
    this.errorMessage,
  });

  final String keyword;
  final List<Song> results;
  final List<String> searchHistory;
  final int currentPage;
  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;

  SearchState copyWith({
    String? keyword,
    List<Song>? results,
    List<String>? searchHistory,
    int? currentPage,
    bool? isLoading,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      results: results ?? this.results,
      searchHistory: searchHistory ?? this.searchHistory,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return StubSearchRepository();
});

final searchNotifierProvider =
    AsyncNotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class SearchNotifier extends AsyncNotifier<SearchState> {
  late SearchRepository _repo;

  @override
  Future<SearchState> build() async {
    _repo = ref.read(searchRepositoryProvider);
    final history = await _repo.loadHistory();
    return SearchState(searchHistory: history);
  }

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) return;

    final settings =
        await ref.read(settingsNotifierProvider.future);
    state = AsyncValue.data(
      state.valueOrNull?.copyWith(
            keyword: keyword,
            isLoading: true,
            clearError: true,
            results: const [],
            currentPage: 1,
          ) ??
          SearchState(keyword: keyword, isLoading: true),
    );

    try {
      final results = await _repo.search(
        source: settings.defaultSource,
        keyword: keyword,
      );
      await _repo.addHistory(keyword);
      final history = await _repo.loadHistory();
      state = AsyncValue.data(
        SearchState(
          keyword: keyword,
          results: results,
          searchHistory: history,
          hasMore: results.length >= 20,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        state.valueOrNull?.copyWith(
              isLoading: false,
              errorMessage: e.toString(),
            ) ??
            const SearchState(),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoading) return;

    final settings = await ref.read(settingsNotifierProvider.future);
    state = AsyncValue.data(current.copyWith(isLoading: true));

    try {
      final more = await _repo.search(
        source: settings.defaultSource,
        keyword: current.keyword,
        page: current.currentPage + 1,
      );
      state = AsyncValue.data(
        current.copyWith(
          results: [...current.results, ...more],
          currentPage: current.currentPage + 1,
          isLoading: false,
          hasMore: more.length >= 20,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(isLoading: false, errorMessage: e.toString()),
      );
    }
  }

  Future<void> clearHistory() async {
    await _repo.clearHistory();
    state = AsyncValue.data(
      state.valueOrNull?.copyWith(searchHistory: const []) ??
          const SearchState(),
    );
  }
}
