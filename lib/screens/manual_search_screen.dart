import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants.dart';
import '../providers/search_provider.dart';
import '../providers/database_provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_logger.dart';
import '../services/hltb_service.dart';
import '../widgets/hltb_search_body.dart';
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
    _debounce = Timer(AppConstants.kSearchDebounce, () {
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
            SnackBar(content: Text('"$gameName" is already in your library')),
          );
        }
        setState(() => _addingGameName = '');
        return;
      }

      // Normalized duplicate check: catches near-matches like "Witcher 3" vs "The Witcher 3"
      final allGames = await db.gamesDao.getAllGames(steamId);
      final normalizedInput = HltbService.normalise(gameName);
      final similar = allGames
          .where((g) => HltbService.normalise(g.name) == normalizedInput)
          .toList();
      if (similar.isNotEmpty && mounted) {
        final shouldAdd = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Possible Duplicate'),
            content: Text(
              '"${similar.first.name}" is already in your library and looks very similar.\n\nAdd "$gameName" anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add Anyway'),
              ),
            ],
          ),
        );
        if (shouldAdd != true) {
          setState(() => _addingGameName = '');
          return;
        }
      }

      final timeToBeat = essential != null || extended != null || completionist != null
          ? TimeToBeat(
              essentialHours: essential,
              extendedHours: extended,
              completionistHours: completionist,
            )
          : null;

      await db.gamesDao.addManualGame(
        gameName,
        timeToBeat,
        steamId,
        artworkUrl: artworkUrl,
      );

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
      if (mounted) setState(() => _addingGameName = '');
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
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search HowLongToBeat...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Expanded(
            child: HltbSearchBody(
              searchState: searchState,
              query: _searchController.text,
              trailingBuilder: (result) => _addingGameName == result.name
                  ? const SizedBox(
                      width: 40,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _addGameToBacklog(
                        result.name,
                        result.essentialHours,
                        result.extendedHours,
                        result.completionistHours,
                        artworkUrl: result.artworkUrl,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
