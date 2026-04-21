import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_search_result.dart';
import '../services/hltb_service.dart';

class SearchState {
  final List<GameSearchResult> results;
  final bool isLoading;
  final String? errorMessage;

  SearchState({
    this.results = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SearchState copyWith({
    List<GameSearchResult>? results,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Manages game search against the HowLongToBeat proxy.
class SearchNotifier extends Notifier<SearchState> {
  final _hltb = HltbService();

  @override
  SearchState build() => SearchState();

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = SearchState();
      return;
    }
    // Mirror the server-side cap to avoid sending oversized requests.
    if (trimmed.length > 100) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await _hltb.search(trimmed);
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search failed. Check your connection and try again.',
      );
    }
  }

  /// Resets search results and any error state.
  void clear() => state = SearchState();
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
