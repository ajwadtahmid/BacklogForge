import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/steam_auth_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _busy = false;

  /// Initiates the Steam OpenID 2.0 sign-in flow: launches the browser, waits for the redirect,
  /// extracts the Steam ID, and updates the auth state.
  Future<void> _startSignIn() async {
    setState(() => _busy = true);
    try {
      final svc = SteamAuthService();
      final loginUrl = await svc.buildLoginUrl();
      await launchUrl(loginUrl, mode: LaunchMode.externalApplication);
      final redirect = await svc.awaitRedirect().timeout(
        const Duration(minutes: 2),
      );
      final steamId = await svc.extractAndVerifySteamId(redirect);
      if (steamId == null) {
        ref.read(authProvider.notifier).failSignIn();
        return;
      }
      await ref.read(authProvider.notifier).completeSignIn(steamId);
    } on TimeoutException {
      ref
          .read(authProvider.notifier)
          .setError('Sign-in timed out — please try again.');
    } on SocketException {
      ref
          .read(authProvider.notifier)
          .setError('Could not start the local redirect server.');
    } catch (e) {
      ref.read(authProvider.notifier).setError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final errorMsg = auth.whenOrNull(error: (e, _) => e.toString());
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BacklogForge',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _busy ? null : _startSignIn,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(_busy ? 'Signing in…' : 'Sign in with Steam'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : () => ref.read(authProvider.notifier).completeSignIn('guest_user'),
                child: const Text('Use without Steam'),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 16),
                Column(
                  children: [
                    Text(errorMsg, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.read(authProvider.notifier).failSignIn(),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for signing in from within the app (when guest user wants to sign in).
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
      final svc = SteamAuthService();
      final loginUrl = await svc.buildLoginUrl();
      await launchUrl(loginUrl, mode: LaunchMode.externalApplication);
      final redirect = await svc.awaitRedirect().timeout(
        const Duration(minutes: 2),
      );
      final steamId = await svc.extractAndVerifySteamId(redirect);
      if (steamId == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      await ref.read(authProvider.notifier).completeSignIn(steamId);
      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      ref.read(authProvider.notifier).setError('Sign-in timed out — please try again.');
    } on SocketException {
      ref.read(authProvider.notifier).setError('Could not start the local redirect server.');
    } catch (e) {
      ref.read(authProvider.notifier).setError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sign In to BacklogForge',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _busy ? null : _startSignIn,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(_busy ? 'Signing in…' : 'Sign in with Steam'),
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
