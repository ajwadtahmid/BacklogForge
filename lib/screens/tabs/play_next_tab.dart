import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/play_next_provider.dart';
import '../../services/database/app_database.dart';
import '../../models/game.dart';
import '../../widgets/pick_card.dart';

class PlayNextTab extends ConsumerWidget {
  const PlayNextTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playNextProvider);
    final notifier = ref.read(playNextProvider.notifier);

    final (buttonLabel, buttonIcon) = _buttonAppearance(state);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MethodSelector(
            selected: state.method,
            onChanged: notifier.setMethod,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: state.loading ? null : notifier.spin,
            icon: Icon(buttonIcon),
            label: Text(buttonLabel),
          ),
          const SizedBox(height: 24),
          if (state.loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.spun)
            _PicksSection(
              picks: state.picks,
              method: state.method,
              focusedView: state.focusedView,
              lockedIds: state.lockedIds,
              onToggleLock: notifier.toggleLock,
            ),
        ],
      ),
    );
  }

  /// Returns the button label and icon for the current state.
  (String, IconData) _buttonAppearance(PlayNextState state) {
    if (state.loading) return ('Finding...', Icons.hourglass_empty);
    if (state.method == FindMethod.shuffle) {
      return ('Find Games', Icons.shuffle);
    }
    // Homestretch mode: label describes what the next press will load.
    if (!state.spun) {
      return ('Show Progress — almost done', Icons.hourglass_bottom);
    }
    return state.focusedView == FocusedView.progress
        ? ('Show Quickest — fewest hours', Icons.bolt)
        : ('Show Progress — almost done', Icons.hourglass_bottom);
  }
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({required this.selected, required this.onChanged});
  final FindMethod selected;
  final ValueChanged<FindMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FindMethod>(
      segments: const [
        ButtonSegment(
          value: FindMethod.shuffle,
          icon: Icon(Icons.shuffle),
          label: Text('Shuffle'),
        ),
        ButtonSegment(
          value: FindMethod.focused,
          icon: Icon(Icons.local_fire_department),
          label: Text('Homestretch'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _PicksSection extends StatelessWidget {
  const _PicksSection({
    required this.picks,
    required this.method,
    required this.focusedView,
    required this.lockedIds,
    required this.onToggleLock,
  });

  final List<Game> picks;
  final FindMethod method;
  final FocusedView focusedView;
  final Set<int> lockedIds;
  final void Function(int) onToggleLock;

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
        final target = game.targetHours ?? game.targetHoursWithFallback;
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
            final target = game.targetHours ?? game.targetHoursWithFallback;
            if (target == null || target <= 0) return '';
            final played = game.playtimeMinutes / 60.0;
            final pct = ((played / target) * 100).clamp(0.0, 100.0);
            final rem = (target - played).clamp(0.0, double.infinity);
            return '${pct.toStringAsFixed(0)}% completed  |  ~${rem.toStringAsFixed(1)}h left';

          case FocusedView.quickest:
            final target = game.targetHours ?? game.targetHoursWithFallback;
            if (target == null) return 'Unknown length';
            final remaining = (target - game.playtimeMinutes / 60.0).clamp(
              0.0,
              double.infinity,
            );
            if (remaining == 0) return 'Almost done!';
            return '~${remaining.toStringAsFixed(1)}h remaining';
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) {
      final message = switch ((method, focusedView)) {
        (FindMethod.focused, FocusedView.progress) =>
          'No backlog games are halfway through. Start playing something first.',
        (FindMethod.focused, FocusedView.quickest) =>
          'No backlog games have time-to-beat data yet. Try syncing first.',
        _ => 'Your backlog is empty.',
      };
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48, color: Colors.grey),
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

    final countMsg = picks.length < 5
        ? 'Only ${picks.length} game${picks.length == 1 ? '' : 's'} matched.'
        : null;

    final isShuffle = method == FindMethod.shuffle;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (countMsg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                countMsg,
                style: const TextStyle(color: Colors.amber),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: picks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => PickCard(
                game: picks[i],
                subtitle: _subtitle(picks[i]),
                locked: isShuffle && lockedIds.contains(picks[i].id),
                onToggleLock: isShuffle
                    ? () => onToggleLock(picks[i].id)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
