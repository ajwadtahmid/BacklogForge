import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Singleton logger. Writes timestamped lines to a persistent log file in the
/// app's support directory and mirrors output to the debug console in debug builds.
///
/// Call [init] once at app startup before using any log methods.
/// The logger registers itself as a [WidgetsBindingObserver] so the file sink
/// is flushed whenever the app is backgrounded or detached, preventing log
/// loss on crash or force-quit.
class AppLogger with WidgetsBindingObserver {
  AppLogger._();
  static final instance = AppLogger._();

  IOSink? _sink;

  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/backlogforge.log');
      _sink = file.openWrite(mode: FileMode.append);
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // Non-fatal — continue without file logging if the directory is unavailable.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _sink?.flush();
    }
  }

  /// Flushes buffered log data to disk immediately.
  Future<void> flush() => _sink?.flush() ?? Future.value();

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
