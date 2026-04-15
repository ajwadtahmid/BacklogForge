import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'providers/auth_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/library_screen.dart';

final logger = Logger();

void main() {
  /// Wrap the app with ProviderScope to enable Riverpod state management across the entire widget tree.
  runApp(const ProviderScope(child: BacklogForgeApp()));
}

class BacklogForgeApp extends ConsumerWidget {
  const BacklogForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Watches authentication state, which handles loading during startup and session restoration.
    final authAsync = ref.watch(authProvider);
    return MaterialApp(
      title: 'BacklogForge',
      theme: ThemeData.dark(),
      home: authAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const OnboardingScreen(),
        data: (auth) =>
            auth.isSignedIn ? const LibraryScreen() : const OnboardingScreen(),
      ),
    );
  }
}
