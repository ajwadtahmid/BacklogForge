import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants.dart';
import '../../providers/play_next_provider.dart';
import '../../util/ui_tokens.dart';
import '../../providers/daily_budget_provider.dart';
import '../../services/database/app_database.dart';
import '../../models/game.dart';
import '../../util/date_format.dart';
import '../../widgets/pick_card.dart';
import '../../widgets/skeleton_loaders.dart';

class PlayNextTab extends ConsumerWidget {
  const PlayNextTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playNextProvider);
    final notifier = ref.read(playNextProvider.notifier);

    final isShuffle = state.method == FindMethod.shuffle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Method selector ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MethodCard(
                  icon: Icons.shuffle,
                  title: 'Shuffle',
                  subtitle: 'Weighted random pick from your backlog',
                  selected: state.method == FindMethod.shuffle,
                  onTap: () => notifier.setMethod(FindMethod.shuffle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodCard(
                  icon: Icons.local_fire_department,
                  title: 'Endgame',
                  subtitle: 'Games you\'re almost done with or can finish fastest',
                  selected: state.method == FindMethod.focused,
                  onTap: () => notifier.setMethod(FindMethod.focused),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Primary action ────────────────────────────────────────
          if (isShuffle)
            _ActionCard(
              icon: state.loading ? Icons.hourglass_empty : Icons.shuffle,
              title: state.loading ? 'Finding…' : 'Find Games',
              loading: state.loading,
              onTap: notifier.spin,
            )
          else
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _FocusedViewCard(
                        icon: Icons.hourglass_bottom,
                        title: 'Almost Done',
                        selected: state.focusedView == FocusedView.progress,
                        loading: state.loading,
                        onTap: () => notifier.setFocusedView(FocusedView.progress),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    Expanded(
                      child: _FocusedViewCard(
                        icon: Icons.bolt,
                        title: 'Quickest',
                        selected: state.focusedView == FocusedView.quickest,
                        loading: state.loading,
                        onTap: () => notifier.setFocusedView(FocusedView.quickest),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Progress filter (Almost Done only) ────────────────────
          if (!isShuffle && state.focusedView == FocusedView.progress) ...[
            const SizedBox(height: 12),
            _ProgressThresholdRow(
              threshold: state.progressThreshold,
              onChanged: notifier.updateProgressThreshold,
              onChangeEnd: (_) => notifier.applyProgressThreshold(),
            ),
          ],

          const SizedBox(height: 24),

          if (state.loading)
            const Expanded(child: PlayNextSkeleton())
          else if (state.spun)
            _PicksSection(
              picks: state.picks,
              method: state.method,
              focusedView: state.focusedView,
              lockedIds: state.lockedIds,
              onToggleLock: notifier.toggleLock,
              scoreReasons: state.scoreReasons,
              progressThreshold: state.progressThreshold,
              focusedDisplayCount: state.focusedDisplayCount,
              onLoadMore: notifier.loadMoreFocused,
            ),
        ],
      ),
    );
  }
}

/// Full-width action card used for the Shuffle "Find Games" button.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: kAnimNormal,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: cs.onPrimary),
              const SizedBox(width: 7),
              Text(
                title,
                style: tt.titleSmall?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selection card for "Almost Done" / "Quickest" sub-views.
class _FocusedViewCard extends StatelessWidget {
  const _FocusedViewCard({
    required this.icon,
    required this.title,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bgColor = selected ? cs.primary : cs.surfaceContainerHigh;
    final fgColor = selected ? cs.onPrimary : cs.onSurface;

    return AnimatedContainer(
      duration: kAnimNormal,
      curve: Curves.easeInOut,
      color: bgColor,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fgColor),
              const SizedBox(width: 7),
              Text(
                title,
                style: tt.titleSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact single-row slider for the "Almost Done" completion threshold.
class _ProgressThresholdRow extends StatelessWidget {
  const _ProgressThresholdRow({
    required this.threshold,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double threshold;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = (threshold * 100).round();

    return Row(
      children: [
        Icon(Icons.tune_rounded, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          'Min. progress',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 4),
        Text(
          '$pct%',
          style: tt.bodySmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Slider(
            value: threshold,
            min: 0.50,
            max: 0.95,
            divisions: 9,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}

/// Top-level method selector card — shows title + subtitle so users
/// understand what each mode does before selecting it.
class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bgColor = selected ? cs.primary : cs.surfaceContainerHigh;
    final fgColor = selected ? cs.onPrimary : cs.onSurface;
    final subColor = selected
        ? cs.onPrimary.withValues(alpha: 0.75)
        : cs.onSurfaceVariant;

    return AnimatedContainer(
      duration: kAnimNormal,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: selected ? null : Border.all(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: fgColor),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(
                      color: fgColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: subColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PicksSection extends ConsumerWidget {
  const _PicksSection({
    required this.picks,
    required this.method,
    required this.focusedView,
    required this.lockedIds,
    required this.onToggleLock,
    required this.scoreReasons,
    required this.progressThreshold,
    required this.focusedDisplayCount,
    required this.onLoadMore,
  });

  final List<Game> picks;
  final FindMethod method;
  final FocusedView focusedView;
  final Set<int> lockedIds;
  final void Function(int) onToggleLock;
  final Map<int, String> scoreReasons;
  final double progressThreshold;
  final int focusedDisplayCount;
  final VoidCallback onLoadMore;

  String _subtitle(Game game) {
    switch (method) {
      case FindMethod.shuffle:
        final lp = game.lastPlayedAt;
        final String playedPart;
        if (lp == null) {
          playedPart = 'Never played';
        } else {
          final days = DateTime.now().difference(lp).inDays;
          if (days == 0) {
            playedPart = 'Played today';
          } else if (days == 1) {
            playedPart = 'Played yesterday';
          } else {
            playedPart = 'Not played in $days days';
          }
        }
        final target = game.displayTargetHours;
        if (target == null || target <= 0) return playedPart;
        final played = game.playtimeMinutes / 60.0;
        if (played <= 0) {
          return '$playedPart  |  ~${target.toStringAsFixed(1)}h to beat';
        }
        final pct = ((played / target) * 100).clamp(0.0, 100.0);
        final rem = (target - played).clamp(0.0, double.infinity);
        return '$playedPart  |  ${pct.toStringAsFixed(0)}% completed  |  ~${rem.toStringAsFixed(1)}h left';

      case FindMethod.focused:
        switch (focusedView) {
          case FocusedView.progress:
            final target = game.displayTargetHours;
            if (target == null || target <= 0) return '';
            final played = game.playtimeMinutes / 60.0;
            final pct = ((played / target) * 100).clamp(0.0, 100.0);
            final rem = (target - played).clamp(0.0, double.infinity);
            return '${pct.toStringAsFixed(0)}% completed  |  ~${rem.toStringAsFixed(1)}h left';

          case FocusedView.quickest:
            final target = game.displayTargetHours;
            if (target == null) return 'Unknown length';
            final remaining = (target - game.playtimeMinutes / 60.0)
                .clamp(0.0, double.infinity);
            if (remaining == 0) return 'Almost done!';
            return '~${remaining.toStringAsFixed(1)}h remaining';
        }
    }
  }

  String? _estimatedDoneBy(Game game, double budget) {
    final target = game.displayTargetHours;
    if (target == null) return null;
    return estimatedDoneByLabel(target - game.playtimeMinutes / 60.0, budget);
  }

  void _showReason(BuildContext context, Game game, String reason) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Why "${game.name}"?'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(dailyBudgetProvider).asData?.value ?? 0.0;
    if (picks.isEmpty) {
      final thresholdPct = (progressThreshold * 100).round();
      final message = switch ((method, focusedView)) {
        (FindMethod.focused, FocusedView.progress) =>
          'No games are ≥$thresholdPct% complete. Try lowering the threshold above.',
        (FindMethod.focused, FocusedView.quickest) =>
          'No backlog games have time-to-beat data yet. Try syncing first.',
        _ => 'Your backlog is empty.',
      };
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final isShuffle = method == FindMethod.shuffle;
    final displayPicks = isShuffle
        ? picks
        : picks.take(focusedDisplayCount).toList();
    final hasMore = !isShuffle && picks.length > focusedDisplayCount;
    final remaining = picks.length - focusedDisplayCount;

    final countMsg = isShuffle && picks.length < AppConstants.kPickCount
        ? 'Only ${picks.length} game${picks.length == 1 ? '' : 's'} matched.'
        : null;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (countMsg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                countMsg,
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: displayPicks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final game = displayPicks[i];
                final reason = scoreReasons[game.id];
                return PickCard(
                  game: game,
                  subtitle: _subtitle(game),
                  estimatedDoneBy: _estimatedDoneBy(game, budget),
                  locked: isShuffle && lockedIds.contains(game.id),
                  onToggleLock:
                      isShuffle ? () => onToggleLock(game.id) : null,
                  onShowReason: (isShuffle && reason != null)
                      ? () => _showReason(context, game, reason)
                      : null,
                );
              },
            ),
          ),
          if (hasMore) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text(
                'Load ${remaining.clamp(1, AppConstants.kPickCount)} more'
                '  ·  $remaining remaining',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
