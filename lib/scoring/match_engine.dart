// What every sport's scoring engine gives back, so scoring, syncing and the live view work the same way.
import 'cricket_engine.dart' show MatchEvent;

abstract class EngineState {
  /// NOT_STARTED, IN_PROGRESS, INNINGS_BREAK, TIE_DECISION or COMPLETED (the server stores this).
  String get status;
  Map<String, dynamic> toJson();
}

/// Events still in effect: each UNDO removes the latest one before it.
List<MatchEvent> effectiveEvents(List<MatchEvent> events) {
  final kept = <MatchEvent>[];
  for (final e in events) {
    if (e.type == 'UNDO') {
      if (kept.isNotEmpty) kept.removeLast();
    } else {
      kept.add(e);
    }
  }
  return kept;
}
