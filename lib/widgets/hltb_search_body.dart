import 'package:flutter/material.dart';
import '../models/game_search_result.dart';
import '../providers/search_provider.dart';
import 'hltb_result_tile.dart';

/// Shared body for HLTB search screens. Handles loading / error / empty / results
/// states and delegates the per-result trailing widget to [trailingBuilder].
class HltbSearchBody extends StatelessWidget {
  const HltbSearchBody({
    super.key,
    required this.searchState,
    required this.query,
    required this.trailingBuilder,
    this.showNoDataLabel = false,
  });

  final SearchState searchState;

  /// Current search query — used to pick the right empty-state message.
  final String query;

  final Widget Function(GameSearchResult result) trailingBuilder;
  final bool showNoDataLabel;

  @override
  Widget build(BuildContext context) {
    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (searchState.errorMessage != null) {
      return Center(
        child: Text(searchState.errorMessage!, textAlign: TextAlign.center),
      );
    }
    if (searchState.results.isEmpty) {
      return Center(
        child: Text(
          query.isNotEmpty ? 'No results found' : 'Search for a game to get started',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: searchState.results.length,
      itemBuilder: (ctx, idx) {
        final result = searchState.results[idx];
        return HltbResultTile(
          result: result,
          showNoDataLabel: showNoDataLabel,
          trailing: trailingBuilder(result),
        );
      },
    );
  }
}
