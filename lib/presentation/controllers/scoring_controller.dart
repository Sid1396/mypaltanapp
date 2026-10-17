import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../data/models/match.dart';
import '../../data/services/api_service.dart';
import '../../scoring/cricket_engine.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';

/// Ball-by-ball scoring for one match. Arguments: {'id': matchId}.
///
/// Every action is an event. Events are kept on the phone first (so scoring works without signal) and sent to the
/// server in order; the server only accepts them on top of the count it already has, so two phones can never mix.
class ScoringController extends GetxController with LoggerMixin {
  ApiService get _api => Get.find<ApiService>();
  final _box = GetStorage();

  late final int matchId;
  final match = Rx<MatchDetail?>(null);
  final state = Rx<CricketState?>(null);
  final isLoading = true.obs;
  final error = Rx<String?>(null);

  /// Events the server has, and events made on this phone that are not sent yet.
  final _saved = <MatchEvent>[];
  final pending = <MatchEvent>[].obs;
  final syncing = false.obs;
  final offline = false.obs;
  final lockedBy = Rx<String?>(null);

  // Picks on the "start innings" panel.
  final startStriker = Rx<int?>(null);
  final startNonStriker = Rx<int?>(null);
  final startBowler = Rx<int?>(null);
  Timer? _retry;
  Timer? _heartbeat;

  String get _key => 'score_pending_$matchId';

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    matchId = (args is Map ? args['id'] as int? : null) ?? 0;
    load();
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) {
      if (pending.isEmpty && lockedBy.value == null) _send(heartbeat: true);
    });
  }

  @override
  void onClose() {
    _retry?.cancel();
    _heartbeat?.cancel();
    if (pending.isEmpty) _api.syncMatch({'match_id': matchId, 'base_count': _saved.length, 'release': true}).catchError((_) => <String, dynamic>{});
    super.onClose();
  }

  // ─── Loading ──────────────────────────────────────────────────

  Future<void> load() async {
    error.value = null;
    try {
      final res = await _api.getMatch(matchId);
      if (res['success'] != true || res['match'] is! Map) {
        error.value = res['message']?.toString() ?? 'Could not load the match.';
        return;
      }
      final m = MatchDetail.fromJson(Map<String, dynamic>.from(res['match'] as Map));
      match.value = m;
      lockedBy.value = m.lockedBy;
      _saved
        ..clear()
        ..addAll(m.events);
      _restorePending(m);
      _recompute();
      if (pending.isNotEmpty) _send();
    } on ApiException catch (e) {
      // No signal: keep scoring from what this phone already has.
      if (match.value == null) error.value = e.message;
      offline.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  /// Puts back balls scored on this phone that never reached the server.
  void _restorePending(MatchDetail m) {
    final raw = _box.read(_key);
    pending.clear();
    if (raw is! Map) return;
    final list = (raw['events'] as List? ?? []).whereType<Map>().map((e) => MatchEvent.fromJson(Map<String, dynamic>.from(e))).toList();
    final onServer = {for (final e in m.events) e.clientId};
    final left = list.where((e) => !onServer.contains(e.clientId)).toList();
    if (left.isEmpty) {
      _box.remove(_key);
      return;
    }
    if ((raw['base'] as num?)?.toInt() == m.eventCount || onServer.contains(list.first.clientId)) {
      pending.addAll(left);
    } else {
      _box.remove(_key);
      AppSnackbar.warning('Score changed', 'The match was scored on another phone, so ${left.length} unsent balls from this phone were dropped.');
    }
  }

  void _persist() {
    if (pending.isEmpty) {
      _box.remove(_key);
    } else {
      _box.write(_key, {'base': _saved.length, 'events': [for (final e in pending) e.toJson()]});
    }
  }

  List<MatchEvent> get allEvents => [..._saved, ...pending];

  void _recompute() {
    final m = match.value;
    if (m == null || !m.hasSetup) return;
    try {
      state.value = CricketEngine.replay(m.cricketSetup(), m.cricketRules(), allEvents);
    } on ScoringError catch (e) {
      logError('Replay failed', e);
      error.value = 'The score could not be rebuilt: ${e.message}';
    }
  }

  // ─── Adding events ────────────────────────────────────────────

  static final _rand = Random.secure();
  String _newId() => '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${List.generate(8, (_) => _rand.nextInt(36).toRadixString(36)).join()}';

  /// Checks the event against the rules, keeps it on the phone and sends it. Returns false if it is not allowed.
  bool add(String type, [Map<String, dynamic> data = const {}]) {
    final m = match.value;
    if (m == null) return false;
    if (lockedBy.value != null) {
      AppSnackbar.warning('Scoring', '${lockedBy.value} is scoring this match. Take over to continue.');
      return false;
    }
    final e = MatchEvent(_newId(), type, data);
    try {
      state.value = CricketEngine.tryAdd(m.cricketSetup(), m.cricketRules(), allEvents, e);
    } on ScoringError catch (err) {
      AppSnackbar.error('Not allowed', err.message);
      return false;
    }
    pending.add(e);
    _persist();
    _send();
    return true;
  }

  void startInnings(int striker, int nonStriker, int bowler) => add('START_INNINGS', {'striker': striker, 'non_striker': nonStriker, 'bowler': bowler});
  void runs(int r, {bool boundary = false}) => add('BALL', {'runs': r, 'extra': 'NONE', if (boundary) 'boundary': true});
  void extra(String type, int r, {bool nbByes = false, bool boundary = false}) =>
      add('BALL', {'runs': r, 'extra': type, if (nbByes) 'nb_byes': true, if (boundary) 'boundary': true});
  bool wicket(String how, int outId, {int? fielder, int runs = 0, String extraType = 'NONE'}) => add('BALL', {
        'runs': runs,
        'extra': extraType,
        'wicket': {'how': how, 'out': outId, if (fielder != null) 'fielder': fielder},
      });
  void newBatter(int id, String position) => add('NEW_BATTER', {'id': id, 'position': position});
  void newBowler(int id) => add('NEW_BOWLER', {'id': id});
  void swapStrike() => add('SWAP_STRIKE');
  void retire(int id, {required bool out}) => add('RETIRE', {'id': id, 'out': out});
  void endInnings(String reason) => add('END_INNINGS', {'reason': reason});
  void endMatch({int? winner, required String text}) => add('END_MATCH', {if (winner != null) 'winner': winner, 'text': text});

  void undo() {
    if (CricketEngine.effective(allEvents).isEmpty) return AppSnackbar.info('Undo', 'Nothing to undo.');
    add('UNDO');
  }

  // ─── Sending ──────────────────────────────────────────────────

  Future<void> _send({bool takeOver = false, bool heartbeat = false}) async {
    if (syncing.value || (!heartbeat && !takeOver && pending.isEmpty)) return;
    syncing.value = true;
    final batch = heartbeat ? <MatchEvent>[] : pending.toList();
    try {
      final res = await _api.syncMatch({
        'match_id': matchId,
        'base_count': _saved.length,
        'events': [for (final e in batch) e.toJson()],
        if (batch.isNotEmpty) 'live': state.value?.toJson(),
        if (takeOver) 'take_over': true,
      });
      offline.value = false;
      _retry?.cancel();
      if (res['success'] == true) {
        lockedBy.value = null;
        _saved.addAll(batch);
        pending.removeRange(0, batch.length.clamp(0, pending.length));
        _persist();
        if (pending.isNotEmpty) {
          syncing.value = false;
          return _send();
        }
      } else if (res['code'] == 'LOCKED') {
        lockedBy.value = res['scorer']?.toString() ?? 'Someone';
      } else if (res['code'] == 'CONFLICT') {
        AppSnackbar.warning('Score changed', res['message']?.toString() ?? 'Reloading the latest score.');
        pending.clear();
        _box.remove(_key);
        syncing.value = false;
        await load();
        return;
      } else {
        AppSnackbar.error('Could not save', res['message']?.toString() ?? 'Please try again.');
      }
    } on ApiException {
      offline.value = true;
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 6), _send);
    } finally {
      syncing.value = false;
    }
  }

  /// Scoring from this phone when another phone held the match.
  Future<void> takeOver() async {
    lockedBy.value = null;
    await _send(takeOver: true);
    if (lockedBy.value == null) await load();
  }

  // ─── Helpers for the screen ───────────────────────────────────

  String teamName(int? entry) => match.value?.teamName(entry) ?? 'Team';
  String fill(String? text) => match.value?.fill(text) ?? (text ?? '');
}
