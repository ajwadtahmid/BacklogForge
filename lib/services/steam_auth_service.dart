import 'dart:io';

class SteamAuthService {
  // Local HTTP server endpoint where Steam redirects after sign-in.
  static const _returnUrl = 'http://127.0.0.1:8080/auth';
  static const _realm = 'http://127.0.0.1:8080';
  static const _steamLogin = 'https://steamcommunity.com/openid/login';

  /// Constructs the Steam OpenID 2.0 login URL that redirects to our local server after authentication.
  Uri buildLoginUrl() => Uri.parse(_steamLogin).replace(
    queryParameters: {
      'openid.ns': 'http://specs.openid.net/auth/2.0',
      'openid.mode': 'checkid_setup',
      'openid.return_to': _returnUrl,
      'openid.realm': _realm,
      'openid.identity': 'http://specs.openid.net/auth/2.0/identifier_select',
      'openid.claimed_id': 'http://specs.openid.net/auth/2.0/identifier_select',
    },
  );

  /// Extracts and validates the Steam ID from the OpenID redirect URL.
  String? extractSteamId(Uri redirect) {
    const prefix = 'https://steamcommunity.com/openid/id/';
    final claimedId = redirect.queryParameters['openid.claimed_id'];
    if (claimedId == null) return null;
    if (!claimedId.startsWith(prefix)) return null;
    return claimedId.substring(prefix.length);
  }

  /// Starts a temporary local HTTP server to capture the Steam OpenID redirect.
  /// Returns the redirect URI containing the signed-in user's Steam ID.
  Future<Uri> awaitRedirect() async {
    final server = await HttpServer.bind('127.0.0.1', 8080);
    try {
      final request = await server.first;
      final redirectUri = request.requestedUri;
      request.response
        ..headers.contentType = ContentType.html
        ..write(
          '<html><body style="font-family:sans-serif;text-align:center;'
          'padding:40px"><h2>Signed in!</h2>'
          '<p>You can close this tab.</p></body></html>',
        );
      await request.response.close();
      return redirectUri;
    } finally {
      await server.close(force: true);
    }
  }
}
