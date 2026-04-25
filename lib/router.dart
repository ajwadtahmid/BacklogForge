import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/library_screen.dart';
import 'screens/game_detail_screen.dart';
import 'screens/manual_search_screen.dart';
import 'services/database/app_database.dart';

/// Bridges Riverpod's async auth provider to go_router's [refreshListenable].
/// Notifies the router whenever auth state changes so the redirect runs again.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this.providerRef) {
    providerRef.listen(authProvider, (_, _) => notifyListeners());
  }

  final Ref providerRef;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = providerRef.read(authProvider);
    if (auth.isLoading) return null;

    final isSignedIn = auth.asData?.value.isSignedIn ?? false;
    final onOnboarding = state.matchedLocation == '/';

    if (!isSignedIn && !onOnboarding) return '/';
    if (isSignedIn && onOnboarding) return '/library';
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
        routes: [
          GoRoute(
            path: 'search',
            builder: (context, state) => const ManualSearchScreen(),
          ),
          GoRoute(
            path: 'game/:id',
            builder: (context, state) {
              final game = state.extra as Game;
              return GameDetailScreen(game: game);
            },
          ),
        ],
      ),
    ],
  );
});
