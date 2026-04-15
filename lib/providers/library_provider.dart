import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/steam_game.dart';
import '../services/steam_service.dart';
import 'auth_provider.dart';

/// Fetches the authenticated user's Steam game library from the Steam API.
/// Returns an empty list if the user is not signed in.
final libraryProvider = FutureProvider<List<SteamGame>>((ref) async {
  final steamId = ref
      .watch(authProvider)
      .maybeWhen(data: (auth) => auth.steamId, orElse: () => null);

  if (steamId == null) return [];
  return SteamService().getOwnedGames(steamId);
});
