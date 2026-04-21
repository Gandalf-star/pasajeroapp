import 'package:flutter/foundation.dart';

/// Utilidad de logging segura que evita la exposición de datos en producción.
class ClickLogger {
  /// Registra un mensaje solo en modo debug.
  static void d(Object? message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] ${DateTime.now()}: $message');
    }
  }

  /// Registra un error con información opcional de stack trace.
  static void e(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] ${DateTime.now()}: $message');
      if (error != null) debugPrint('Error detail: $error');
      if (stackTrace != null) debugPrint('Stack: $stackTrace');
    }
  }

  /// Registra información importante que debe ser visible solo en desarrollo.
  static void i(Object? message) {
    if (kDebugMode) {
      debugPrint('[INFO] ${DateTime.now()}: $message');
    }
  }

  /// Registra una advertencia.
  static void w(Object? message) {
    if (kDebugMode) {
      debugPrint('[WARN] ${DateTime.now()}: $message');
    }
  }
}
