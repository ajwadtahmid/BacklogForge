import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_actions_provider.dart';
import '../../services/database/app_database.dart';
import '../../widgets/game_card.dart';

/// Common selection state and shared helpers for [BacklogTab] and [CompletedTab].
///
/// Mix this into a [ConsumerState] subclass. The mixin owns [searchController]
/// and disposes it, so the host State must not declare its own dispose().
mixin GameListTabMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final searchController = TextEditingController();
  String query = '';
  bool selectionMode = false;
  final selectedIds = <int>{};

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void enterSelectionMode(int gameId) {
    setState(() {
      selectionMode = true;
      selectedIds.add(gameId);
    });
  }

  void toggleSelect(int gameId) {
    setState(() {
      if (selectedIds.contains(gameId)) {
        selectedIds.remove(gameId);
        if (selectedIds.isEmpty) selectionMode = false;
      } else {
        selectedIds.add(gameId);
      }
    });
  }

  void cancelSelection() {
    setState(() {
      selectionMode = false;
      selectedIds.clear();
    });
  }

  void showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Shows a confirmation dialog before bulk actions on 5 or more games.
  /// Returns true immediately for smaller selections (no dialog needed).
  Future<bool> confirmBulk(int count, String actionLabel) async {
    if (count < 2) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('$actionLabel $count game${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Bulk-deletes all selected manually-added games. Steam games are skipped
  /// with a confirmation dialog and a follow-up snackbar for the skip count.
  Future<void> bulkDelete(List<Game> filteredGames) async {
    final selected =
        filteredGames.where((g) => selectedIds.contains(g.id)).toList();
    final steamCount = selected.where((g) => g.appId >= 0).length;
    final deletable = selected.where((g) => g.appId < 0).length;

    if (deletable == 0) {
      showSnack('Steam games cannot be deleted');
      return;
    }

    final message = steamCount > 0
        ? 'Delete $deletable game${deletable == 1 ? '' : 's'}? '
            '($steamCount Steam game${steamCount == 1 ? '' : 's'} will be skipped)'
        : 'Delete $deletable game${deletable == 1 ? '' : 's'}?';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete games?'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final skipped =
          await ref.read(gameActionsProvider).bulkDelete(selected);
      cancelSelection();
      if (skipped > 0) {
        showSnack(
            '$skipped Steam game${skipped == 1 ? '' : 's'} skipped');
      }
    }
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────────

/// Selectable list row used in both backlog and completed selection modes.
class SelectableGameRow extends StatelessWidget {
  const SelectableGameRow({
    super.key,
    required this.game,
    required this.selected,
    required this.onTap,
    this.isInCompletedTab = false,
  });

  final Game game;
  final bool selected;
  final VoidCallback onTap;
  final bool isInCompletedTab;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Checkbox(value: selected, onChanged: (_) => onTap()),
            Expanded(
              child: AbsorbPointer(
                child:
                    GameCard(game: game, isInCompletedTab: isInCompletedTab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action bar pinned to the bottom of the screen during multi-select mode.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.onCancel,
    this.onMarkPlaying,
    this.onMarkNotPlaying,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onDelete,
  });

  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback? onMarkPlaying;
  final VoidCallback? onMarkNotPlaying;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final enabled = selectedCount > 0;
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: onCancel,
              ),
              Text(
                '$selectedCount selected',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              if (onMarkPlaying != null)
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: 'Mark as Playing',
                  onPressed: onMarkPlaying,
                ),
              if (onMarkNotPlaying != null)
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline),
                  tooltip: 'Mark as Not Playing',
                  onPressed: onMarkNotPlaying,
                ),
              IconButton(
                icon: Icon(primaryIcon),
                tooltip: primaryLabel,
                onPressed: enabled ? onPrimary : null,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                color: enabled ? Colors.red[400] : null,
                onPressed: enabled ? onDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
