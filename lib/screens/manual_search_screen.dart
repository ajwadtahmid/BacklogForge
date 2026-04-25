import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/search_provider.dart';
import '../providers/database_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/game_actions_provider.dart';
import '../services/app_logger.dart';
import '../widgets/artwork_image.dart';
import '../models/game_search_result.dart';
import '../models/time_to_beat.dart';

class ManualSearchScreen extends ConsumerStatefulWidget {
  const ManualSearchScreen({super.key});

  @override
  ConsumerState<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends ConsumerState<ManualSearchScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  String _addingGameName = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Clear any results left over from a previous visit to this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).clear();
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

  Future<void> _addGameToBacklog(
    String gameName,
    double? essential,
    double? extended,
    double? completionist, {
    String? artworkUrl,
  }) async {
    if (_addingGameName.isNotEmpty) return;

    setState(() => _addingGameName = gameName);
    try {
      final db = ref.read(databaseProvider);
      final auth = await ref.read(authProvider.future);
      final steamId = auth.steamId ?? '';

      final existing = await db.gamesDao.findByName(gameName, steamId);
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$gameName" is already in your library'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _addingGameName = '');
        return;
      }

      final timeToBeat = essential != null || extended != null || completionist != null
          ? TimeToBeat(
              essentialHours: essential,
              extendedHours: extended,
              completionistHours: completionist,
            )
          : null;

      await db.gamesDao.addManualGame(gameName, timeToBeat, steamId,
          artworkUrl: artworkUrl);

      ref.read(gameActionsProvider).invalidateAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "$gameName" to backlog')),
        );
        context.pop();
      }
    } catch (e, st) {
      AppLogger.instance.error('Failed to add game "$gameName"', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add game. Please try again.')),
        );
      }
    } finally {
      setState(() => _addingGameName = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Add Games'),
      ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: searchState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : searchState.errorMessage != null
                    ? Center(
                        child: Text(
                          searchState.errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : searchState.results.isEmpty && _searchController.text.isNotEmpty
                        ? const Center(child: Text('No results found'))
                        : searchState.results.isEmpty
                            ? const Center(
                                child: Text('Search for a game to get started'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: searchState.results.length,
                                itemBuilder: (ctx, idx) {
                                  final GameSearchResult result = searchState.results[idx];
                                  final hasTtb = result.essentialHours != null ||
                                      result.extendedHours != null ||
                                      result.completionistHours != null;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: SizedBox(
                                        width: 50,
                                        child: ArtworkImage(
                                          url: result.artworkUrl,
                                          width: 50,
                                        ),
                                      ),
                                      title: Text(result.name),
                                      subtitle: hasTtb
                                          ? Text(
                                              'Essential: ${result.essentialHours?.toStringAsFixed(1) ?? "—"}h | '
                                              'Extended: ${result.extendedHours?.toStringAsFixed(1) ?? "—"}h | '
                                              'Completionist: ${result.completionistHours?.toStringAsFixed(1) ?? "—"}h',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            )
                                          : null,
                                      trailing: _addingGameName == result.name
                                          ? const SizedBox(
                                              width: 40,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.add),
                                              onPressed: () =>
                                                  _addGameToBacklog(
                                                    result.name,
                                                    result.essentialHours,
                                                    result.extendedHours,
                                                    result.completionistHours,
                                                    artworkUrl: result.artworkUrl,
                                                  ),
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
