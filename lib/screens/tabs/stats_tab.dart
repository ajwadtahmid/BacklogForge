import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/stats_provider.dart';
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
      data: (stats) => GridView.count(
        crossAxisCount: isWideScreen ? 3 : 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: isWideScreen ? 2.5 : 1.4,
        children: [
          StatCard(
            label: 'Games in Backlog',
            value: '${stats.backlogCount}',
            icon: Icons.inbox,
          ),
          StatCard(
            label: 'Hours to Clear',
            value: stats.hoursRemaining.toStringAsFixed(0),
            icon: Icons.schedule,
          ),
          StatCard(
            label: 'Currently Playing',
            value: '${stats.playingCount}',
            icon: Icons.play_circle_outline,
          ),
          StatCard(
            label: 'Added This Month',
            value: '${stats.addedThisMonth}',
            icon: Icons.add_circle_outline,
          ),
          StatCard(
            label: 'Completed This Month',
            value: '${stats.completedThisMonth}',
            icon: Icons.check_circle_outline,
          ),
          CompletionGradeCard(
            percent: stats.completionPercent,
            grade: stats.grade,
          ),
        ],
      ),
    );
  }
}
