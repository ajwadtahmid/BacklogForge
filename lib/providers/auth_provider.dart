import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import './database_provider.dart';

/// Represents the user's authentication state: either signed out or signed in with a Steam ID.
sealed class AuthState {
  const AuthState();
  const factory AuthState.signedOut() = _SignedOut;
  const factory AuthState.signedIn(String steamId) = _SignedIn;

  bool get isSignedIn => this is _SignedIn;

  String? get steamId => switch (this) {
    _SignedIn s => s.steamId,
    _ => null,
  };
}

class _SignedOut extends AuthState {
  const _SignedOut();
}

class _SignedIn extends AuthState {
  @override
  final String steamId;
  const _SignedIn(this.steamId);
}

/// Manages authentication state, loading persisted session on startup and handling sign-in/sign-out.
class AuthNotifier extends AsyncNotifier<AuthState> {
  static const _steamIdKey = 'steam_id';
  final _secureStorage = const FlutterSecureStorage();

  @override
  Future<AuthState> build() async {
    try {
      /// Loads the user's persisted Steam ID from secure storage; returns signed-out state if not found.
      final steamId = await _secureStorage.read(key: _steamIdKey);
      return steamId != null
          ? AuthState.signedIn(steamId)
          : const AuthState.signedOut();
    } catch (e) {
      /// Secure storage may fail during cipher migration on first launch; default to signed-out
      return const AuthState.signedOut();
    }
  }

  /// Persists the Steam ID to secure storage, seeds settings for this user if
  /// this is their first sign-in, then updates auth state.
  /// For guest users, skips secure storage persistence.
  Future<void> completeSignIn(String steamId) async {
    try {
      final isGuest = steamId == 'guest_user';
      if (!isGuest) {
        await _secureStorage.write(key: _steamIdKey, value: steamId);
      }
      final db = ref.read(databaseProvider);
      await db.settingsDao.seedIfAbsent(steamId);
      state = AsyncValue.data(AuthState.signedIn(steamId));
    } catch (e) {
      state = AsyncValue.error(Exception('Failed to sign in: $e'), StackTrace.current);
    }
  }

  /// Updates state with a validation error when the Steam redirect is invalid.
  void failSignIn() {
    state = AsyncValue.error(
      Exception('Invalid Steam redirect — please try again.'),
      StackTrace.current,
    );
  }

  /// Updates state with an error message for network or system failures.
  void setError(String message) {
    state = AsyncValue.error(Exception(message), StackTrace.current);
  }

  /// Clears the auth token only. User data stays in the DB so re-signing in
  /// is instant, and other users' data is unaffected.
  Future<void> signOut() async {
    await _secureStorage.delete(key: _steamIdKey);
    state = const AsyncValue.data(AuthState.signedOut());
  }
}

/// Provides authentication state across the app, handling async initialization with loading/error states.
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
