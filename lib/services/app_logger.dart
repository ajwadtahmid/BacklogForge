import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Singleton logger. Writes timestamped lines to a persistent log file in the
/// app's support directory and mirrors output to the debug console in debug builds.
///
/// Call [init] once at app startup before using any log methods.
class AppLogger {
  AppLogger._();
  static final instance = AppLogger._();

  IOSink? _sink;

  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/backlogforge.log');
      _sink = file.openWrite(mode: FileMode.append);
    } catch (_) {
      // Non-fatal — continue without file logging if the directory is unavailable.
    }
  }

  void _write(String level, String message, [Object? error, StackTrace? stackTrace]) {
    final now = DateTime.now().toIso8601String();
    final buf = StringBuffer('[$level] $now $message');
    if (error != null) buf.write('\n  $error');
    if (stackTrace != null) buf.write('\n$stackTrace');
    final line = buf.toString();
    if (kDebugMode) debugPrint(line);
    _sink?.writeln(line);
  }

  void debug(String message) => _write('DEBUG', message);
  void info(String message) => _write('INFO', message);
  void warning(String message, [Object? error]) => _write('WARN', message, error);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _write('ERROR', message, error, stackTrace);
}
