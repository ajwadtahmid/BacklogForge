import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract final class Env {
  @EnviedField(varName: 'BACKEND_URL')
  static final String backendUrl = _Env.backendUrl;

  /// Leave blank to disable auth (self-hosted deployments without a token).
  @EnviedField(varName: 'CLIENT_TOKEN', defaultValue: '')
  static final String clientToken = _Env.clientToken;
}
