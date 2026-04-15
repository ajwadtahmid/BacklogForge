import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';

/// Provides a singleton database instance that is automatically closed when the provider is disposed.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
