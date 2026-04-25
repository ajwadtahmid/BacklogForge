import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/play_next_provider.dart';
import '../../services/database/app_database.dart';
import '../../widgets/pick_card.dart';

class PlayNextTab extends ConsumerWidget {
  const PlayNextTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playNextProvider);
    final notifier = ref.read(playNextProvider.notifier);

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
            icon: const Icon(Icons.shuffle),
            label: Text(state.loading ? 'Finding...' : 'Find Games'),
          ),
          const SizedBox(height: 24),
          if (state.loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.spun)
            _PicksSection(picks: state.picks, method: state.method),
        ],
      ),
    );
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
          value: FindMethod.almostDone,
          icon: Icon(Icons.flag),
          label: Text('Almost Done'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _PicksSection extends StatelessWidget {
  const _PicksSection({required this.picks, required this.method});
  final List<Game> picks;
  final FindMethod method;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) {
      final message = switch (method) {
        FindMethod.almostDone =>
          'No backlog games are halfway through. Start playing something first.',
        _ => 'Your backlog is empty.',
      };
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(message, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    final message = picks.length < 3
        ? 'Only ${picks.length} game${picks.length == 1 ? '' : 's'} matched.'
        : null;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                message,
                style: const TextStyle(color: Colors.amber),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: picks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  SizedBox(height: 100, child: PickCard(game: picks[i])),
            ),
          ),
        ],
      ),
    );
  }
}
