import 'dart:io';
import 'package:http/http.dart' as http;

class SteamAuthService {
  static const _steamLogin = 'https://steamcommunity.com/openid/login';

  HttpServer? _server;

  /// Binds to a free local port, then constructs the Steam OpenID 2.0 login URL.
  /// Uses port 0 so the OS picks an available port instead of failing on a busy fixed port.
  Future<Uri> buildLoginUrl() async {
    _server = await HttpServer.bind('127.0.0.1', 0);
    final port = _server!.port;
    return Uri.parse(_steamLogin).replace(
      queryParameters: {
        'openid.ns': 'http://specs.openid.net/auth/2.0',
        'openid.mode': 'checkid_setup',
        'openid.return_to': 'http://127.0.0.1:$port/auth',
        'openid.realm': 'http://127.0.0.1:$port',
        'openid.identity': 'http://specs.openid.net/auth/2.0/identifier_select',
        'openid.claimed_id': 'http://specs.openid.net/auth/2.0/identifier_select',
      },
    );
  }

  /// Waits for Steam's redirect on the server started by [buildLoginUrl].
  Future<Uri> awaitRedirect() async {
    final server = _server!;
    _server = null;
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

  /// Verifies the Steam OpenID response signature via check_authentication,
  /// then extracts and returns the Steam ID. Returns null if invalid.
  Future<String?> extractAndVerifySteamId(Uri redirect) async {
    const prefix = 'https://steamcommunity.com/openid/id/';
    final claimedId = redirect.queryParameters['openid.claimed_id'];
    if (claimedId == null || !claimedId.startsWith(prefix)) return null;

    // Ask Steam to confirm the signed response is authentic.
    final params = Map<String, String>.from(redirect.queryParameters);
    params['openid.mode'] = 'check_authentication';
    final res = await http.post(Uri.parse(_steamLogin), body: params);
    if (res.statusCode != 200 || !res.body.contains('is_valid:true')) return null;

    return claimedId.substring(prefix.length);
  }
}
