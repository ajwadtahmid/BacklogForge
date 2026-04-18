import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/drift.dart';
import '../services/database/app_database.dart';
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
  final String steamId;
  const _SignedIn(this.steamId);
}

/// Manages authentication state, loading persisted session on startup and handling sign-in/sign-out.
class AuthNotifier extends AsyncNotifier<AuthState> {
  static const _steamIdKey = 'steam_id';
  final _secureStorage = const FlutterSecureStorage();

  @override
  Future<AuthState> build() async {
    /// Loads the user's persisted Steam ID from secure storage; returns signed-out state if not found.
    final steamId = await _secureStorage.read(key: _steamIdKey);
    return steamId != null
        ? AuthState.signedIn(steamId)
        : const AuthState.signedOut();
  }

  /// Persists the Steam ID to secure storage and updates the auth state on successful sign-in.
  Future<void> completeSignIn(String steamId) async {
    await _secureStorage.write(key: _steamIdKey, value: steamId);
    state = AsyncValue.data(AuthState.signedIn(steamId));
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

  /// Clears all user data and persisted session, leaving zero trace for the next user.
  /// Atomically wipes games and settings tables, re-seeds default settings, and clears auth token.
  /// Ensures the app boots to a fresh onboarding screen next time.
  Future<void> signOut() async {
    final db = ref.read(databaseProvider);

    // Wipe all user data in a single atomic transaction.
    await db.transaction(() async {
      await db.delete(db.games).go();
      await db.delete(db.appSettings).go();
      // Re-seed the singleton settings row with defaults so the app boots cleanly.
      await db.into(db.appSettings).insert(
        AppSettingsCompanion.insert(id: const Value(1)),
      );
    });

    // Clear the auth token from secure storage.
    await _secureStorage.delete(key: _steamIdKey);
    state = const AsyncValue.data(AuthState.signedOut());
  }
}

/// Provides authentication state across the app, handling async initialization with loading/error states.
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
