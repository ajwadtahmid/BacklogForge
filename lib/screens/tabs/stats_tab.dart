import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/stats_provider.dart';
import '../../providers/daily_budget_provider.dart';
import '../../widgets/stat_card.dart';

const _kWideBreakpoint = 600.0;

class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final isWideScreen = MediaQuery.of(context).size.width > _kWideBreakpoint;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card ordering is optimised for both 2-col (mobile) and 3-col (desktop):
            //
            // Mobile pairs:  Backlog/Playing | NeverStarted/BarelyPlayed
            //                Halfway/HoursToClear | TotalHours/AddedThisMonth
            //                CompletedThisMonth/Grade
            //
            // Desktop triples: Backlog/Playing/NeverStarted
            //                  BarelyPlayed/Halfway/HoursToClear
            //                  TotalHours/AddedThisMonth/CompletedThisMonth
            //                  Grade (emphasised alone in the last row)
            GridView.count(
              crossAxisCount: isWideScreen ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: isWideScreen ? 2.5 : 1.4,
              children: [
                CompletionGradeCard(
                  percent: stats.completionPercent,
                  grade: stats.grade,
                ),
                StatCard(
                  label: 'Games in Backlog',
                  value: '${stats.backlogCount}',
                  icon: Icons.inbox,
                ),
                StatCard(
                  label: 'Currently Playing',
                  value: '${stats.playingCount}',
                  icon: Icons.play_circle_outline,
                ),
                StatCard(
                  label: 'Never Started',
                  value: '${stats.neverStartedCount}',
                  icon: Icons.not_started_outlined,
                ),
                StatCard(
                  label: 'Barely Played',
                  value: '${stats.barelyPlayedCount}',
                  icon: Icons.hourglass_empty,
                ),
                StatCard(
                  label: 'At Least Halfway Done',
                  value: '${stats.halfwayDoneCount}',
                  icon: Icons.hourglass_bottom,
                ),
                StatCard(
                  label: 'Hours to Clear',
                  value: stats.hoursRemaining.toStringAsFixed(0),
                  icon: Icons.schedule,
                ),
                StatCard(
                  label: 'Total Hours Played',
                  value: stats.totalHoursPlayed.toStringAsFixed(0),
                  icon: Icons.sports_esports,
                ),
                StatCard(
                  label: 'Quarterly Completion',
                  value: '${stats.completedQuarterly}',
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DailyBudgetCard(stats: stats),
          ],
        ),
      ),
    );
  }
}

class _DailyBudgetCard extends ConsumerWidget {
  const _DailyBudgetCard({required this.stats});
  final GameStats stats;

  String _clearingLine(double budget) {
    final h = stats.hoursRemaining;
    if (h <= 0) return 'Your backlog is clear!';
    final days = h / budget;
    if (days < 30) {
      return 'At ${_fmt(budget)} h/day, your backlog clears in ~${days.toStringAsFixed(0)} days';
    }
    if (days < 365) {
      final months = days / 30.44;
      return 'At ${_fmt(budget)} h/day, your backlog clears in ~${months.toStringAsFixed(1)} months';
    }
    final years = days / 365.0;
    return 'At ${_fmt(budget)} h/day, your backlog clears in ~${years.toStringAsFixed(1)} years';
  }

  // Formats a budget value without redundant trailing zeros: 1.0 → "1", 1.5 → "1.5".
  String _fmt(double h) =>
      h.toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(dailyBudgetProvider).asData?.value ?? 1.0;
    final notifier = ref.read(dailyBudgetNotifierProvider.notifier);
    final subStyle = TextStyle(color: Colors.grey[500], fontSize: 12);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Daily Budget',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: budget > 0.5
                      ? () => notifier.setBudget(
                            double.parse(
                              (budget - 0.5).toStringAsFixed(1),
                            ),
                          )
                      : null,
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    '${_fmt(budget)} h',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: budget < 12.0
                      ? () => notifier.setBudget(
                            double.parse(
                              (budget + 0.5).toStringAsFixed(1),
                            ),
                          )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _clearingLine(budget),
              style: subStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'HLTB coverage: ${stats.hltbCovered} / ${stats.hltbTotal} backlog games',
              style: subStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
