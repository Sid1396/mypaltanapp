import 'package:flutter/foundation.dart';

mixin LoggerMixin {
  String get logTag => runtimeType.toString();

  void logInfo(String message) {
    if (kDebugMode) debugPrint('[$logTag] INFO: $message');
  }

  void logWarning(String message) {
    if (kDebugMode) debugPrint('[$logTag] WARN: $message');
  }

  void logError(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[$logTag] ERROR: $message${error != null ? ' - $error' : ''}');
    }
  }
}
