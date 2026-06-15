import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants.dart';
import '../models/game_search_result.dart';
import '../providers/search_provider.dart';
import '../providers/game_actions_provider.dart';
import '../services/database/app_database.dart';
import '../widgets/hltb_search_body.dart';
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
    _debounce = Timer(AppConstants.kSearchDebounce, () {
      ref.read(searchProvider.notifier).search(query);
    });
  }

  Future<void> _applyResult(GameSearchResult result) async {
    if (_applying) return;
    setState(() => _applying = true);
    // Capture messenger before async gap so the snackbar shows on the parent screen.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(gameActionsProvider).setHltbHours(
            widget.game,
            essential: result.essentialHours,
            extended: result.extendedHours,
            completionist: result.completionistHours,
            hltbName: result.name,
          );
      if (mounted) {
        context.pop();
        messenger.showSnackBar(
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
              showNoDataLabel: true,
              trailingBuilder: (result) => _applying
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
          ),
        ],
      ),
    );
  }
}
