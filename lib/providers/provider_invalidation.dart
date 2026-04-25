import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'library_provider.dart';
import 'stats_provider.dart';
import 'sort_provider.dart';

void invalidateLibraryProviders(Ref ref) {
  ref.invalidate(backlogProvider);
  ref.invalidate(completedProvider);
  ref.invalidate(statsProvider);
  ref.invalidate(backlogSortedProvider);
  ref.invalidate(completedSortedProvider);
}
