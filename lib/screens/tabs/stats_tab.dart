import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants.dart';
import '../../util/platform.dart';
import '../../providers/goals_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/daily_budget_provider.dart';
import '../../util/date_format.dart';
import '../../widgets/skeleton_loaders.dart';
import '../../widgets/stat_card.dart';

class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return statsAsync.when(
      loading: () => const StatsTabSkeleton(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(stats: stats),
            const SizedBox(height: 20),
            const _SectionLabel('Breakdown'),
            const SizedBox(height: 8),
            _QuickStatsRow(stats: stats),
            const SizedBox(height: 20),
            const _SectionLabel('Goals'),
            const SizedBox(height: 8),
            _DailyBudgetCard(stats: stats),
            const SizedBox(height: 10),
            const _QuarterGoalCard(),
            const SizedBox(height: 20),
            const _SectionLabel('Velocity'),
            const SizedBox(height: 8),
            const _VelocityCard(),
            const SizedBox(height: 20),
            _DetailsSection(stats: stats),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ─────────────────────────────────────────────
// Hero card
// ─────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});
  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = stats.backlogCount + stats.completedCount;
    final gradeColor = CompletionGradeCard.gradeColor(stats.grade, cs);
    final pct = total == 0 ? 0.0 : stats.completionPercent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Library Overview',
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: pct.toStringAsFixed(0),
                              style: tt.displayLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                                height: 1.0,
                              ),
                            ),
                            TextSpan(
                              text: '%',
                              style: tt.headlineLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w300,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        total == 0
                            ? 'No games yet'
                            : '${stats.completedCount} of $total completed',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gradeColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: gradeColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      stats.grade,
                      style: TextStyle(
                        color: gradeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : pct / 100,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(gradeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quick stats — wrapping centered chips
// ─────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.stats});
  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobileOS;

    final items = [
      (value: '${stats.backlogCount}', label: 'In Backlog'),
      (value: '${stats.completedCount}', label: 'Completed'),
      (value: '${stats.playingCount}', label: 'Playing'),
      (value: stats.hoursRemaining.toStringAsFixed(0), label: 'Hours left'),
      (value: stats.totalHoursPlayed.toStringAsFixed(0), label: 'Hours played'),
      (value: '${stats.neverStartedCount}', label: 'Never started'),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
        children: items
            .map((item) => _StatChip(value: item.value, label: item.label))
            .toList(),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => _StatChip(value: item.value, label: item.label))
          .toList(),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.primary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Daily budget — slider, no presets
// ─────────────────────────────────────────────

class _DailyBudgetCard extends ConsumerWidget {
  const _DailyBudgetCard({required this.stats});
  final GameStats stats;

  String _clearingLine(double budget) {
    if (budget <= 0) return 'Set a daily budget to see a backlog completion estimate';
    final h = stats.hoursRemaining;
    if (h <= 0) return 'Your backlog is clear!';
    final days = h / budget;
    if (days < 30) return 'Clears in ~${days.toStringAsFixed(0)} days';
    if (days < 365) {
      return 'Clears in ~${(days / 30.44).toStringAsFixed(1)} months';
    }
    return 'Clears in ~${(days / 365.0).toStringAsFixed(1)} years';
  }

  String _fmt(double h) =>
      h.toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(dailyBudgetProvider).asData?.value ?? 0.0;
    final notifier = ref.read(dailyBudgetNotifierProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final budgetSet = budget > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Daily Budget', style: tt.titleSmall)),
                Text(
                  budgetSet ? '${_fmt(budget)} h / day' : 'Not set',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: budgetSet ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _clearingLine(budget),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: (budgetSet ? budget : AppConstants.kMinBudget).clamp(
                  AppConstants.kMinBudget,
                  AppConstants.kMaxBudget,
                ),
                min: AppConstants.kMinBudget,
                max: AppConstants.kMaxBudget,
                divisions: ((AppConstants.kMaxBudget -
                            AppConstants.kMinBudget) /
                        AppConstants.kBudgetStep)
                    .round(),
                onChanged: (v) {
                  final snapped =
                      (v / AppConstants.kBudgetStep).round() *
                      AppConstants.kBudgetStep;
                  notifier.setBudget(
                    double.parse(snapped.toStringAsFixed(1)),
                  );
                },
              ),
            ),
            Text(
              'HLTB coverage: ${stats.hltbCovered} / ${stats.hltbTotal} backlog games',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quarter goal
// ─────────────────────────────────────────────

DateTime _quarterStart(DateTime dt) {
  final q = (dt.month - 1) ~/ 3;
  return DateTime(dt.year, q * 3 + 1);
}

String _quarterLabel(DateTime dt) {
  final q = ((dt.month - 1) ~/ 3) + 1;
  return 'Q$q ${dt.year}';
}

int _currentQuarterCompletions(
    List<({int year, int month, int count})> data) {
  final now = DateTime.now();
  final qStart = _quarterStart(now);
  final qMonths = <int>{qStart.month, qStart.month + 1, qStart.month + 2};
  return data
      .where((d) => d.year == qStart.year && qMonths.contains(d.month))
      .fold(0, (s, d) => s + d.count);
}

String _progressCaption(int completed, int goal, DateTime now) {
  final qStart = _quarterStart(now);
  final qEnd = DateTime(qStart.year, qStart.month + 3);
  final totalDays = qEnd.difference(qStart).inDays;
  final elapsed = now.difference(qStart).inDays + 1;
  final expected = goal * elapsed / totalDays;
  if (completed >= expected.floor()) return '$completed / $goal — on track';
  return '$completed / $goal — ${goal - completed} to go';
}

class _QuarterGoalCard extends ConsumerWidget {
  const _QuarterGoalCard();

  Future<void> _editGoal(
      BuildContext context, WidgetRef ref, int? current) async {
    final controller =
        TextEditingController(text: current != null ? '$current' : '');
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quarterly completion goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Games to complete',
            hintText: 'e.g. 3',
          ),
          autofocus: true,
          onSubmitted: (v) {
            final n = int.tryParse(v.trim());
            if (n != null && n > 0) Navigator.of(ctx).pop(n);
          },
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(-1),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n != null && n > 0) Navigator.of(ctx).pop(n);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    if (result == -1) {
      ref.read(quarterGoalProvider.notifier).setGoal(null);
    } else {
      ref.read(quarterGoalProvider.notifier).setGoal(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(quarterGoalProvider);
    final velocityAsync = ref.watch(completionVelocityProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _quarterLabel(now),
                          style: tt.titleSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: '  Completion Goal',
                          style: tt.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _editGoal(context, ref, goal),
                  child: Text(goal == null ? 'Set goal' : 'Edit'),
                ),
              ],
            ),
            if (goal == null)
              Text(
                'Track how many games you want to finish this quarter.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              )
            else
              velocityAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (raw) {
                  final completed = _currentQuarterCompletions(raw);
                  final progress = (completed / goal).clamp(0.0, 1.0);
                  final done = completed >= goal;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                              done ? cs.tertiary : cs.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        done
                            ? '$completed / $goal — goal reached!'
                            : _progressCaption(completed, goal, now),
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Velocity — Jan-Dec static, year dropdown,
//            overflow-safe fixed-height labels
// ─────────────────────────────────────────────

class _VelocityCard extends ConsumerStatefulWidget {
  const _VelocityCard();

  @override
  ConsumerState<_VelocityCard> createState() => _VelocityCardState();
}

class _VelocityCardState extends ConsumerState<_VelocityCard> {
  int _year = DateTime.now().year;
  int? _selectedMonth; // 1-based, null = none selected

  // Cache the derived years list to avoid rebuilding it on every frame.
  List<({int year, int month, int count})>? _rawCache;
  List<int> _cachedYears = [];

  List<int> _getYears(List<({int year, int month, int count})> raw) {
    if (!identical(raw, _rawCache)) {
      _rawCache = raw;
      _cachedYears = ({...raw.map((d) => d.year), DateTime.now().year}.toList()
        ..sort());
    }
    return _cachedYears;
  }

  List<({int year, int month, int count})> _yearData(
    List<({int year, int month, int count})> data,
    int year,
  ) =>
      List.generate(12, (i) {
        final month = i + 1;
        final found = data
            .where((d) => d.year == year && d.month == month)
            .firstOrNull;
        return (year: year, month: month, count: found?.count ?? 0);
      });

  @override
  Widget build(BuildContext context) {
    final velocityAsync = ref.watch(completionVelocityProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + year dropdown
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text('Games Completed / Month',
                      style: tt.titleSmall),
                ),
                velocityAsync.maybeWhen(
                  data: (raw) {
                    final years = _getYears(raw);
                    final sel = years.contains(_year) ? _year : years.last;
                    return DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: sel,
                        isDense: true,
                        items: years.reversed
                            .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Text(
                                    '$y',
                                    style: tt.labelSmall
                                        ?.copyWith(color: cs.primary),
                                  ),
                                ))
                            .toList(),
                        onChanged: (y) {
                          if (y != null) setState(() => _year = y);
                        },
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            // Avg subtitle (or selected-month detail when tapped)
            velocityAsync.maybeWhen(
              data: (raw) {
                final months = _yearData(raw, _year);
                final total = months.fold(0, (s, e) => s + e.count);
                final avg = total / 12;
                final selMonth = _selectedMonth;
                final selData = selMonth != null
                    ? months.firstWhere((m) => m.month == selMonth)
                    : null;
                final subtitle = selData != null
                    ? '${monthAbbr(selData.month)} $_year: ${selData.count} completed'
                    : 'avg ${avg.toStringAsFixed(1)}/mo · $total completed in $_year';
                return Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            // Chart
            velocityAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => const SizedBox(height: 120),
              data: (raw) {
                final months = _yearData(raw, _year);
                final maxCount =
                    months.fold(0, (m, e) => e.count > m ? e.count : m);

                if (maxCount == 0) {
                  return SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'No completions in $_year',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  );
                }

                // Fixed heights to prevent overflow:
                // kLabelH + kGap1 + kBarMax + kGap2 + kLabelH = 116 ≤ 120
                const kBarMax = 82.0;
                const kLabelH = 14.0;
                const kGap1 = 2.0;
                const kGap2 = 4.0;

                return SizedBox(
                  height: kLabelH + kGap1 + kBarMax + kGap2 + kLabelH + 4,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: months.map((m) {
                      final isFuture =
                          m.year == now.year && m.month > now.month;
                      final isNow =
                          m.year == now.year && m.month == now.month;
                      final ratio = m.count / maxCount;
                      final barH = isFuture
                          ? kBarMax * 0.04
                          : ratio.clamp(0.04, 1.0) * kBarMax;

                      final isSelected = _selectedMonth == m.month;
                      return Expanded(
                        child: GestureDetector(
                          onTap: isFuture ? null : () => setState(() {
                            _selectedMonth = isSelected ? null : m.month;
                          }),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Count label — fixed height, no reflow
                                SizedBox(
                                  height: kLabelH,
                                  child: !isFuture && m.count > 0
                                      ? Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Text(
                                            '${m.count}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: isSelected
                                                  ? cs.secondary
                                                  : isNow
                                                      ? cs.primary
                                                      : cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: kGap1),
                                Container(
                                  height: barH,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isFuture
                                          ? [
                                              cs.surfaceContainerHighest
                                                  .withValues(alpha: 0.4),
                                              cs.surfaceContainerHighest
                                                  .withValues(alpha: 0.15),
                                            ]
                                          : isSelected
                                              ? [
                                                  cs.secondary,
                                                  cs.secondary
                                                      .withValues(alpha: 0.5),
                                                ]
                                              : isNow
                                                  ? [
                                                      cs.primary,
                                                      cs.primary
                                                          .withValues(alpha: 0.5),
                                                    ]
                                                  : [
                                                      cs.primaryContainer,
                                                      cs.primaryContainer
                                                          .withValues(alpha: 0.35),
                                                    ],
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: kGap2),
                                // Month label — fixed height
                                SizedBox(
                                  height: kLabelH,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Text(
                                      monthAbbr(m.month),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isSelected
                                            ? cs.secondary
                                            : isNow
                                                ? cs.primary
                                                : isFuture
                                                    ? cs.onSurfaceVariant
                                                        .withValues(alpha: 0.35)
                                                    : cs.onSurfaceVariant,
                                        fontWeight: (isNow || isSelected)
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Details — full stat list rows
// ─────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.stats});
  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final totalTracked = stats.backlogCount + stats.completedCount;
    final avgBacklogHours = stats.hltbCovered > 0
        ? (stats.hoursRemaining / stats.hltbCovered)
        : null;
    final hltbPct = stats.hltbTotal > 0
        ? (stats.hltbCovered / stats.hltbTotal * 100)
        : null;

    final rows = [
      (icon: Icons.inventory_2_outlined, label: 'Total Games Tracked', value: '$totalTracked'),
      (icon: Icons.inbox_outlined, label: 'In Backlog', value: '${stats.backlogCount}'),
      (icon: Icons.check_circle_outline, label: 'Completed', value: '${stats.completedCount}'),
      (icon: Icons.play_circle_outline, label: 'Currently Playing', value: '${stats.playingCount}'),
      (icon: Icons.not_started_outlined, label: 'Never Started', value: '${stats.neverStartedCount}'),
      (icon: Icons.hourglass_empty, label: 'Barely Played (<10%)', value: '${stats.barelyPlayedCount}'),
      (icon: Icons.hourglass_bottom, label: 'At Least Halfway', value: '${stats.halfwayDoneCount}'),
      (icon: Icons.trending_up, label: 'Completed (last 4 months)', value: '${stats.completedQuarterly}'),
      (icon: Icons.schedule_outlined, label: 'Hours Remaining', value: '${stats.hoursRemaining.toStringAsFixed(0)}h'),
      (icon: Icons.access_time_outlined, label: 'Hours Played', value: '${stats.totalHoursPlayed.toStringAsFixed(0)}h'),
      if (avgBacklogHours != null)
        (icon: Icons.timer_outlined, label: 'Avg. Backlog Game Length', value: '${avgBacklogHours.toStringAsFixed(0)}h'),
      if (stats.avgCompletionHours != null)
        (icon: Icons.sports_esports_outlined, label: 'Avg. Completed Game', value: '${stats.avgCompletionHours!.toStringAsFixed(0)}h'),
      if (hltbPct != null)
        (icon: Icons.data_usage, label: 'HLTB Coverage', value: '${hltbPct.toStringAsFixed(0)}%'),
    ];

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'DETAILS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.primary,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
        ),
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Column(
            children: [
              if (i == 0)
                Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Icon(row.icon, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        row.label,
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      row.value,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (i < rows.length - 1)
                Divider(
                  height: 1,
                  indent: 48,
                  endIndent: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
