import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../services/database/app_database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

/// Streams the persisted daily play budget (hours/day) from the database.
final dailyBudgetProvider = StreamProvider<double>((ref) async* {
  final auth = await ref.watch(authProvider.future);
  final steamId = auth.steamId;
  if (steamId == null) {
    yield 0.0;
    return;
  }
  yield* ref
      .watch(databaseProvider)
      .settingsDao
      .watch(steamId)
      .map((s) => s.dailyBudgetHours);
});

/// Exposes [DailyBudgetNotifier.setBudget]. Read-only; use [dailyBudgetProvider]
/// to watch the current value.
final dailyBudgetNotifierProvider =
    Provider<DailyBudgetNotifier>((ref) => DailyBudgetNotifier(ref));

class DailyBudgetNotifier {
  DailyBudgetNotifier(this._ref);
  final Ref _ref;

  Future<void> setBudget(double hours) async {
    final auth = await _ref.read(authProvider.future);
    final steamId = auth.steamId;
    if (steamId == null) return;
    await _ref.read(databaseProvider).settingsDao.write(
      AppSettingsCompanion(dailyBudgetHours: Value(hours)),
      steamId,
    );
  }
}
