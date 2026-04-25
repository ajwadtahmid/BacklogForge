import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/theme_provider.dart';
import 'router.dart';
import 'services/app_logger.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();
  runApp(const ProviderScope(child: BacklogForgeApp()));
}

class BacklogForgeApp extends ConsumerWidget {
  const BacklogForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeAsync = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'BacklogForge',
      themeMode: themeAsync.maybeWhen(
        data: (mode) => mode,
        orElse: () => ThemeMode.dark,
      ),
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: router,
    );
  }
}
