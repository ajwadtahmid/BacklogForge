import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/library_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'onboarding_screen.dart';
import 'tabs/backlog_tab.dart';
import 'tabs/completed_tab.dart';
import 'tabs/play_next_tab.dart';
import 'tabs/stats_tab.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(initialSyncProvider);
    final syncState = ref.watch(syncStateProvider);

    ref.listen<SyncState>(syncStateProvider, (previous, next) {
      if (previous?.status == SyncStatus.syncing &&
          next.status == SyncStatus.idle &&
          next.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.notification!),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    });

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BacklogForge'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add game manually',
              onPressed: () => context.push('/library/search'),
            ),
            IconButton(
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              tooltip: 'Toggle theme',
              onPressed: () async {
                final currentMode =
                    Theme.of(context).brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
                await ref
                    .read(themeProvider.notifier)
                    .setTheme(currentMode);
              },
            ),
            if (syncState.status == SyncStatus.syncing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        syncState.hltbTotal != null
                            ? '${syncState.hltbCurrent}/${syncState.hltbTotal}'
                            : 'Fetching library…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ),
              )
            else
              Consumer(
                builder: (context, ref, _) {
                  final authAsync = ref.watch(authProvider);
                  final isGuest = authAsync.whenOrNull(
                        data: (auth) =>
                            auth.steamId == AuthNotifier.guestSteamId,
                      ) ??
                      false;
                  return Tooltip(
                    message: isGuest
                        ? 'Sign in with Steam to sync your library'
                        : (syncState.errorMessage ?? 'Sync with Steam'),
                    child: IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: syncState.status == SyncStatus.error
                            ? Colors.red
                            : null,
                      ),
                      onPressed: isGuest
                          ? null
                          : () =>
                              ref.read(syncStateProvider.notifier).sync(),
                    ),
                  );
                },
              ),
            Consumer(
              builder: (context, ref, _) {
                final authAsync = ref.watch(authProvider);
                return authAsync.whenOrNull(
                  data: (auth) {
                    final isGuest = auth.steamId == AuthNotifier.guestSteamId;
                    return IconButton(
                      icon: Icon(isGuest ? Icons.login : Icons.logout),
                      tooltip: isGuest ? 'Sign in with Steam' : 'Sign out',
                      onPressed: isGuest
                          ? () => showModalBottomSheet(
                                context: context,
                                builder: (_) => const SignInSheet(),
                              )
                          : () => ref.read(authProvider.notifier).signOut(),
                    );
                  },
                ) ?? IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: null,
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Backlog'),
              Tab(text: 'Completed'),
              Tab(text: 'Play Next'),
              Tab(text: 'Stats'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [BacklogTab(), CompletedTab(), PlayNextTab(), StatsTab()],
        ),
      ),
    );
  }
}
