import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/app_database.dart';
import 'database_provider.dart';

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
  @override
  Future<AuthState> build() async {
    /// Loads the user's persisted Steam ID from the database; returns signed-out state if not found.
    final db = ref.read(databaseProvider);
    final row = await (db.select(
      db.auth,
    )..where((a) => a.id.equals(1))).getSingleOrNull();
    return row != null
        ? AuthState.signedIn(row.steamId)
        : const AuthState.signedOut();
  }

  /// Persists the Steam ID to the database and updates the auth state on successful sign-in.
  Future<void> completeSignIn(String steamId) async {
    final db = ref.read(databaseProvider);
    await db
        .into(db.auth)
        .insertOnConflictUpdate(
          AuthCompanion.insert(id: const Value(1), steamId: steamId),
        );
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

  /// Clears the persisted session and updates the auth state to signed-out.
  Future<void> signOut() async {
    final db = ref.read(databaseProvider);
    await db.delete(db.auth).go();
    state = const AsyncValue.data(AuthState.signedOut());
  }
}

/// Provides authentication state across the app, handling async initialization with loading/error states.
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
