import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/library_screen.dart';
import 'theme.dart';

void main() {
  // ProviderScope must wrap the entire app for Riverpod to function.
  runApp(const ProviderScope(child: BacklogForgeApp()));
}

/// Root widget. Watches auth and theme state to decide which screen to show
/// and which theme to apply, with no intermediate navigation layer needed.
class BacklogForgeApp extends ConsumerWidget {
  const BacklogForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final themeAsync = ref.watch(themeProvider);

    return MaterialApp(
      title: 'BacklogForge',
      themeMode: themeAsync.maybeWhen(
        data: (mode) => mode,
        orElse: () => ThemeMode.dark,
      ),
      theme: lightTheme,
      darkTheme: darkTheme,
      home: authAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        // Auth errors fall through to onboarding so the user can retry sign-in.
        error: (error, stackTrace) => const OnboardingScreen(),
        data: (auth) =>
            auth.isSignedIn ? const LibraryScreen() : const OnboardingScreen(),
      ),
    );
  }
}
