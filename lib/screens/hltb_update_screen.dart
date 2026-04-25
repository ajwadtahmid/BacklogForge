import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_search_result.dart';
import '../providers/search_provider.dart';
import '../providers/game_actions_provider.dart';
import '../services/database/app_database.dart';
import '../services/hltb_service.dart';

/// Lets the user search HLTB and apply time-to-beat data to an existing game.
/// Only the essential/extended/completionist hours are updated — no other
/// fields are changed.
class HltbUpdateScreen extends ConsumerStatefulWidget {
  const HltbUpdateScreen({super.key, required this.game});

  final Game game;

  @override
  ConsumerState<HltbUpdateScreen> createState() => _HltbUpdateScreenState();
}

class _HltbUpdateScreenState extends ConsumerState<HltbUpdateScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    final query = HltbService.normalise(widget.game.name);
    _searchController = TextEditingController(text: query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).search(query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchProvider.notifier).search(query);
    });
  }

  Future<void> _applyResult(GameSearchResult result) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await ref.read(gameActionsProvider).setHltbHours(
            widget.game,
            essential: result.essentialHours,
            extended: result.extendedHours,
            completionist: result.completionistHours,
            hltbName: result.name,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HLTB data updated for "${widget.game.name}"')),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Update Time to Beat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search HowLongToBeat...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Expanded(
            child: searchState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : searchState.errorMessage != null
                    ? Center(child: Text(searchState.errorMessage!, textAlign: TextAlign.center))
                    : searchState.results.isEmpty && _searchController.text.isNotEmpty
                        ? const Center(child: Text('No results found'))
                        : searchState.results.isEmpty
                            ? const Center(child: Text('Search for a game to get started'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: searchState.results.length,
                                itemBuilder: (ctx, idx) {
                                  final result = searchState.results[idx];
                                  final hasTtb = result.essentialHours != null ||
                                      result.extendedHours != null ||
                                      result.completionistHours != null;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: SizedBox(
                                        width: 50,
                                        child: result.artworkUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: result.artworkUrl!,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                    child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.image_not_supported),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.image_not_supported),
                                              ),
                                      ),
                                      title: Text(result.name),
                                      subtitle: hasTtb
                                          ? Text(
                                              'Essential: ${result.essentialHours?.toStringAsFixed(1) ?? "—"}h  |  '
                                              'Extended: ${result.extendedHours?.toStringAsFixed(1) ?? "—"}h  |  '
                                              'Completionist: ${result.completionistHours?.toStringAsFixed(1) ?? "—"}h',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            )
                                          : const Text('No HLTB data available'),
                                      trailing: _applying
                                          ? const SizedBox(
                                              width: 40,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.check),
                                              tooltip: 'Apply this data',
                                              onPressed: () => _applyResult(result),
                                            ),
                                    ),
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }
}
