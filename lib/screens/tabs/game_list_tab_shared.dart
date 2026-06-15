import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants.dart';
import '../../models/game_status.dart';
import '../../util/platform.dart';
import '../../util/search_match.dart';
import '../../providers/game_actions_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/database/app_database.dart';
import '../../widgets/game_card.dart';
import '../../widgets/skeleton_loaders.dart';

enum _GameAction { openDetail, markPlaying, unmarkPlaying, markDone, moveBacklog, delete }


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

  /// Handles the Delete key pressed while a game row has keyboard focus.
  /// Steam games are not deletable — shows a snackbar instead.
  Future<void> _onKeyDelete(Game game) async {
    if (game.appId >= 0) {
      showSnack('Steam games cannot be deleted');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete game?'),
        content: Text('Remove "${game.name}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(gameActionsProvider).deleteGame(game);
    }
  }

  /// Triggers a full library sync — used as the pull-to-refresh callback.
  Future<void> syncLibrary() =>
      ref.read(syncStateProvider.notifier).sync();

  // Shown once per session on touch platforms — dismissed when user taps ×.
  // Not persisted: intentionally resets on every cold start.
  static bool _swipeHintDismissed = false;

  Widget _swipeHint(BuildContext context) {
    if (_swipeHintDismissed || !context.isMobileOS) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
      child: Row(
        children: [
          Icon(Icons.swipe_outlined, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Swipe a row left or right to change status',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 14, color: cs.onSurfaceVariant),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 20),
            onPressed: () => setState(() => _swipeHintDismissed = true),
          ),
        ],
      ),
    );
  }


  /// Shows a confirmation dialog before bulk actions on 2 or more games.
  /// Returns true immediately for single-game selections (no dialog needed).
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

  /// Right-click / secondary-tap context menu. Shows the same actions as the
  /// swipe panes so mouse users don't have to discover gestures.
  Future<void> _showContextMenu(
    Offset position,
    Game game,
    bool isInCompletedTab,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final isPlaying = game.status.toGameStatus == GameStatus.playing;

    // Build the status-change action that mirrors the end swipe pane.
    final PopupMenuEntry<_GameAction> primaryStatusItem;
    if (isPlaying && isInCompletedTab) {
      primaryStatusItem = const PopupMenuItem(
        value: _GameAction.unmarkPlaying,
        child: _ContextMenuItem(icon: Icons.check_circle_outline, label: 'Mark Completed'),
      );
    } else if (isPlaying) {
      primaryStatusItem = const PopupMenuItem(
        value: _GameAction.unmarkPlaying,
        child: _ContextMenuItem(icon: Icons.inbox_outlined, label: 'Move to Backlog'),
      );
    } else {
      primaryStatusItem = const PopupMenuItem(
        value: _GameAction.markPlaying,
        child: _ContextMenuItem(icon: Icons.play_arrow_outlined, label: 'Mark as Playing'),
      );
    }

    final secondaryStatusItem = isInCompletedTab
        ? const PopupMenuItem(
            value: _GameAction.moveBacklog,
            child: _ContextMenuItem(icon: Icons.inbox_outlined, label: 'Move to Backlog'),
          )
        : const PopupMenuItem(
            value: _GameAction.markDone,
            child: _ContextMenuItem(icon: Icons.check_outlined, label: 'Mark as Done'),
          );

    final size = MediaQuery.of(context).size;
    final action = await showMenu<_GameAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        size.width - position.dx,
        size.height - position.dy,
      ),
      items: [
        const PopupMenuItem(
          value: _GameAction.openDetail,
          child: _ContextMenuItem(icon: Icons.open_in_new, label: 'Open Detail'),
        ),
        const PopupMenuDivider(),
        primaryStatusItem,
        secondaryStatusItem,
        if (game.appId < 0) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _GameAction.delete,
            child: _ContextMenuItem(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: cs.error,
            ),
          ),
        ],
      ],
    );

    if (!mounted || action == null) return;
    final actions = ref.read(gameActionsProvider);

    switch (action) {
      case _GameAction.openDetail:
        if (context.mounted) {
          context.push('/library/game/${game.id}', extra: game);
        }
      case _GameAction.markPlaying:
        await actions.setStatus(game, GameStatus.playing,
            preserveCompletedAt: isInCompletedTab);
      case _GameAction.unmarkPlaying:
        final next = isInCompletedTab && isPlaying
            ? GameStatus.completed
            : GameStatus.backlog;
        await actions.setStatus(game, next);
      case _GameAction.markDone:
        await actions.setStatus(game, GameStatus.completed);
      case _GameAction.moveBacklog:
        await actions.setStatus(game, GameStatus.backlog);
      case _GameAction.delete:
        if (!context.mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete game?'),
            content: Text('Remove "${game.name}" from your library?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) await actions.deleteGame(game);
    }
  }

  /// Builds the standard search + sort-row + list scaffold shared by both tabs.
  /// Each tab supplies its own [gamesStream], labels, sort helpers, and
  /// [bulkActionBar] builder so the unique logic stays in the tab file.
  ///
  /// [extraControls] is rendered between the sort row and the list — used by
  /// BacklogTab for the length-filter chip strip.
  Widget buildGameListBody({
    required AsyncValue<List<Game>> gamesFuture,
    required String searchHint,
    required String emptyText,
    required Widget Function(List<Game> filtered) bulkActionBar,
    bool isInCompletedTab = false,
    Widget? floatingActionButton,
    Widget? extraControls,
    IconData emptyIcon = Icons.inbox_outlined,
  }) {
    return Column(
      children: [
        if (!selectionMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
            ),
          ),
          if (extraControls != null)
            SizedBox(width: double.infinity, child: extraControls),
          _swipeHint(context),
        ],
        Expanded(
          child: gamesFuture.when(
            loading: () => const GameListSkeleton(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (games) {
              final filtered = query.isEmpty || selectionMode
                  ? games
                  : games.where((g) => matchesGameName(g.name, query)).toList();

              if (filtered.isEmpty) {
                final cs = Theme.of(context).colorScheme;
                return RefreshIndicator(
                  onRefresh: syncLibrary,
                  child: Stack(
                    children: [
                      // Needs a scrollable child so pull-to-refresh can fire.
                      ListView(children: [
                        SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  query.isEmpty ? emptyIcon : Icons.search_off,
                                  size: 56,
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  query.isEmpty ? emptyText : 'No results for "$query"',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                      if (!selectionMode && floatingActionButton != null)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: floatingActionButton,
                        ),
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  // Arrow-key navigation: Up/Down move focus between rows;
                  // individual rows handle Enter (via InkWell) and Delete.
                  Focus(
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        FocusScope.of(context).nextFocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        FocusScope.of(context).previousFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: RefreshIndicator(
                      onRefresh: syncLibrary,
                      child: ListView.separated(
                        padding: EdgeInsets.only(
                          top: 0,
                          bottom: selectionMode
                              ? AppConstants.kBulkBarClearance
                              : floatingActionButton != null
                                  ? AppConstants.kFabClearance
                                  : 0,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final game = filtered[i];
                          if (selectionMode) {
                            return SelectableGameRow(
                              key: ValueKey(game.id),
                              game: game,
                              selected: selectedIds.contains(game.id),
                              onTap: () => toggleSelect(game.id),
                              isInCompletedTab: isInCompletedTab,
                            );
                          }
                          // Delete key handler on focused rows.
                          return Focus(
                            key: ValueKey(game.id),
                            onKeyEvent: (_, event) {
                              if (event is! KeyDownEvent) {
                                return KeyEventResult.ignored;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.delete) {
                                _onKeyDelete(game);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: GestureDetector(
                              onLongPress: () => enterSelectionMode(game.id),
                              onSecondaryTapDown: (details) => _showContextMenu(
                                details.globalPosition,
                                game,
                                isInCompletedTab,
                              ),
                              child: GameCard(
                              game: game,
                              isInCompletedTab: isInCompletedTab,
                            ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (selectionMode)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: bulkActionBar(filtered),
                    ),
                  if (!selectionMode && floatingActionButton != null)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: floatingActionButton,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
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
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final skipped =
          await ref.read(gameActionsProvider).bulkDelete(selected);
      cancelSelection();
      if (skipped > 0) {
        showSnack('$skipped Steam game${skipped == 1 ? '' : 's'} skipped');
      }
    }
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────────

/// Compact row used inside context menu items.
class _ContextMenuItem extends StatelessWidget {
  const _ContextMenuItem({
    required this.icon,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: color != null ? TextStyle(color: color) : null),
      ],
    );
  }
}

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
                child: GameCard(game: game, isInCompletedTab: isInCompletedTab),
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
  });

  final int selectedCount;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
        ),
      ),
    );
  }
}
