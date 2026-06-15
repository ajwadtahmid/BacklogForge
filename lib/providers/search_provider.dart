import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
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
    if (trimmed.length > AppConstants.kMaxQueryLength) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await _hltb.search(trimmed);
      // Re-rank by client-side normalised similarity so the best match floats up.
      final sorted = [...results]..sort((a, b) =>
          _similarity(trimmed, b.name).compareTo(_similarity(trimmed, a.name)));
      state = state.copyWith(results: sorted, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search failed. Check your connection and try again.',
      );
    }
  }

  static double _similarity(String query, String candidate) {
    final q = HltbService.normalise(query);
    final c = HltbService.normalise(candidate);
    if (q == c) return 1.0;
    if (c.startsWith(q)) return 0.9;
    if (c.contains(q)) return 0.75;
    final qWords = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final cWords = c.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    if (qWords.isEmpty || cWords.isEmpty) return 0.0;
    final intersection = qWords.intersection(cWords).length;
    final union = qWords.union(cWords).length;
    return intersection / union;
  }

  /// Resets search results and any error state.
  void clear() => state = SearchState();
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
