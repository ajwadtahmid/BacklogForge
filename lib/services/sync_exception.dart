/// Typed exceptions thrown by the sync pipeline (Steam + HLTB services).
/// Caught and switched on by [SyncNotifier._friendlySyncError].
sealed class SyncException implements Exception {
  const SyncException();
}

class ProfilePrivateException extends SyncException {
  const ProfilePrivateException();
}

class SteamApiException extends SyncException {
  const SteamApiException();
}

class NotSignedInException extends SyncException {
  const NotSignedInException();
}

class NetworkException extends SyncException {
  const NetworkException();
}

class ServerTimeoutException extends SyncException {
  const ServerTimeoutException();
}

class HltbSearchException extends SyncException {
  final String detail;
  const HltbSearchException(this.detail);
}

class HltbLookupException extends SyncException {
  final String detail;
  const HltbLookupException(this.detail);
}
