import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/app_logger.dart';
import '../services/steam_auth_service.dart';

Future<String?> _runSteamAuthFlow(WidgetRef ref) async {
  try {
    final svc = SteamAuthService();
    final loginUrl = await svc.buildLoginUrl();
    await launchUrl(loginUrl, mode: LaunchMode.externalApplication);
    final redirect = await svc.awaitRedirect().timeout(
      const Duration(minutes: 2),
    );
    return await svc.extractAndVerifySteamId(redirect);
  } on TimeoutException {
    ref.read(authProvider.notifier).setError('Sign-in timed out — please try again.');
    return null;
  } on SocketException {
    ref.read(authProvider.notifier).setError('Could not start the local redirect server.');
    return null;
  } catch (e, st) {
    AppLogger.instance.error('Steam auth flow failed', e, st);
    ref.read(authProvider.notifier).setError('Something went wrong. Please try again.');
    return null;
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _busy = false;

  Future<void> _startSignIn() async {
    setState(() => _busy = true);
    try {
      final steamId = await _runSteamAuthFlow(ref);
      if (steamId == null) {
        // _runSteamAuthFlow already called setError() with a specific message
        // in all error branches. Only fall back to the generic message when
        // no error was set (e.g. the user closed the browser tab silently).
        if (ref.read(authProvider) is! AsyncError) {
          ref.read(authProvider.notifier).failSignIn();
        }
        return;
      }
      await ref.read(authProvider.notifier).completeSignIn(steamId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final auth = ref.watch(authProvider);
    final errorMsg = auth.whenOrNull(
      error: (e, _) => e.toString().replaceFirst('Exception: ', ''),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Brand ────────────────────────────────────────────────
                  Icon(Icons.videogame_asset_rounded,
                      size: 64, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    'BacklogForge',
                    textAlign: TextAlign.center,
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stop drowning in games.\nFind what to play next.',
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),

                  const SizedBox(height: 36),

                  // ── Feature highlights ───────────────────────────────────
                  _FeatureBullet(
                    icon: Icons.timer_outlined,
                    title: 'See how long every game will take',
                    body: 'HowLongToBeat data is pulled automatically — '
                        'know if you\'re looking at 6 hours or 60.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureBullet(
                    icon: Icons.bolt_outlined,
                    title: 'Find what\'s almost done',
                    body: 'Homestretch mode surfaces games you\'re '
                        'already halfway through, so you can finally finish them.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureBullet(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Auto-complete when you\'re done',
                    body: 'Once your playtime clears the finish line, '
                        'BacklogForge marks the game completed for you.',
                  ),

                  const SizedBox(height: 36),

                  // ── Sign-in ───────────────────────────────────────────────
                  FilledButton.icon(
                    onPressed: _busy ? null : _startSignIn,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.login),
                    label: Text(_busy ? 'Opening Steam…' : 'Sign in with Steam'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await ref
                                  .read(authProvider.notifier)
                                  .completeSignIn(AuthNotifier.guestSteamId);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Browse without Steam'),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Guest mode lets you explore the app and add games manually. '
                    'Sign in later from Settings to sync your Steam library.',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),

                  if (errorMsg != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg,
                              style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.read(authProvider.notifier).failSignIn(),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(body,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for signing in from within the app (guest → signed-in).
class SignInSheet extends ConsumerStatefulWidget {
  const SignInSheet({super.key});

  @override
  ConsumerState<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends ConsumerState<SignInSheet> {
  bool _busy = false;

  Future<void> _startSignIn() async {
    setState(() => _busy = true);
    try {
      final steamId = await _runSteamAuthFlow(ref);
      if (steamId == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      await ref.read(authProvider.notifier).completeSignIn(steamId);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign In to BacklogForge',
            textAlign: TextAlign.center,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your Steam account to sync your library and playtime automatically.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _startSignIn,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.login),
            label: Text(_busy ? 'Opening Steam…' : 'Sign in with Steam'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Continue as Guest'),
          ),
        ],
      ),
    );
  }
}
