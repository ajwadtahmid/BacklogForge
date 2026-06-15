import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart'; // for sharedPrefsProvider

const _kQuarterGoalKey = 'quarter_goal';

class QuarterGoalNotifier extends Notifier<int?> {
  @override
  int? build() => ref.read(sharedPrefsProvider).getInt(_kQuarterGoalKey);

  void setGoal(int? goal) {
    state = goal;
    if (goal == null) {
      ref.read(sharedPrefsProvider).remove(_kQuarterGoalKey);
    } else {
      ref.read(sharedPrefsProvider).setInt(_kQuarterGoalKey, goal);
    }
  }
}

final quarterGoalProvider =
    NotifierProvider<QuarterGoalNotifier, int?>(QuarterGoalNotifier.new);
