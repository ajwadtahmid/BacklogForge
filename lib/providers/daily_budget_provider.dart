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
    yield 1.0;
    return;
  }
  yield* ref
      .watch(databaseProvider)
      .settingsDao
      .watch(steamId)
      .map((s) => s.dailyBudgetHours);
});

final dailyBudgetNotifierProvider =
    NotifierProvider<DailyBudgetNotifier, double>(DailyBudgetNotifier.new);

class DailyBudgetNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  Future<void> setBudget(double hours) async {
    final auth = await ref.read(authProvider.future);
    final steamId = auth.steamId;
    if (steamId == null) return;
    await ref.read(databaseProvider).settingsDao.write(
      AppSettingsCompanion(dailyBudgetHours: Value(hours)),
      steamId,
    );
  }
}
