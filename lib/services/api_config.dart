import '../env.dart';

abstract final class ApiConfig {
  static String get backendUrl => Env.backendUrl;
  static String get clientToken => Env.clientToken;
}
