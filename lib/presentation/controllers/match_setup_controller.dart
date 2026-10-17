import 'package:get/get.dart';
import '../../data/models/match.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/snackbar_helper.dart';

/// Toss and Playing XI before the first ball. Arguments: {'id': matchId}. Opens scoring when saved.
class MatchSetupController extends GetxController {
  ApiService get _api => Get.find<ApiService>();

  late final int id;
  final match = Rx<MatchDetail?>(null);
  final isLoading = true.obs;
  final isSaving = false.obs;
  final error = Rx<String?>(null);
  final tossWinner = Rx<int?>(null);
  final decision = Rx<String?>(null);
  final picked = <int, Set<int>>{}.obs; // entry → member ids
  final captain = <int, int>{}.obs; // entry → member id
  final keeper = <int, int>{}.obs;

  int get maxPlayers => (match.value?.matchRules['players_per_side'] as num?)?.toInt() ?? 11;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    id = (args is Map ? args['id'] as int? : null) ?? 0;
    load();
  }

  Future<void> load() async {
    try {
      final res = await _api.getMatch(id);
      if (res['success'] != true || res['match'] is! Map) {
        error.value = res['message']?.toString() ?? 'Could not load the match.';
        return;
      }
      final m = MatchDetail.fromJson(Map<String, dynamic>.from(res['match'] as Map));
      match.value = m;
      tossWinner.value = m.tossWinner;
      decision.value = m.tossDecision;
      // Start from the saved XI, or the whole squad when it fits.
      for (final t in [m.home, m.away].whereType<MatchTeam>()) {
        final saved = m.lineups.where((p) => p.entryId == t.entryId).toList();
        picked[t.entryId] = saved.isNotEmpty
            ? saved.map((p) => p.memberId).toSet()
            : (t.squad.length <= maxPlayers ? t.squad.map((p) => p.memberId).toSet() : <int>{});
        final cap = saved.where((p) => p.captain).firstOrNull;
        final wk = saved.where((p) => p.keeper).firstOrNull;
        if (cap != null) captain[t.entryId] = cap.memberId;
        if (wk != null) keeper[t.entryId] = wk.memberId;
      }
      picked.refresh();
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  void toggle(int entry, int member) {
    final set = {...?picked[entry]};
    if (set.contains(member)) {
      set.remove(member);
      if (captain[entry] == member) captain.remove(entry);
      if (keeper[entry] == member) keeper.remove(entry);
    } else {
      if (set.length >= maxPlayers) return AppSnackbar.warning('Playing XI', 'Pick at most $maxPlayers players.');
      set.add(member);
    }
    picked[entry] = set;
  }

  void setCaptain(int entry, int member) {
    if (!(picked[entry]?.contains(member) ?? false)) toggle(entry, member);
    captain[entry] = member;
  }

  void setKeeper(int entry, int member) {
    if (!(picked[entry]?.contains(member) ?? false)) toggle(entry, member);
    keeper[entry] = member;
  }

  String? validate() {
    final m = match.value!;
    if (tossWinner.value == null) return 'Who won the toss?';
    if (decision.value == null) return 'Did they choose to bat or bowl?';
    for (final t in [m.home!, m.away!]) {
      final n = picked[t.entryId]?.length ?? 0;
      if (n < 2) return 'Pick the Playing XI for ${t.name}.';
    }
    return null;
  }

  /// Saves and returns true; the page then opens scoring.
  Future<bool> save() async {
    final err = validate();
    if (err != null) {
      AppSnackbar.error('Before the match', err);
      return false;
    }
    final m = match.value!;
    isSaving.value = true;
    try {
      final res = await _api.setupMatch({
        'match_id': id,
        'toss_winner_entry_id': tossWinner.value,
        'toss_decision': decision.value,
        'lineups': {
          for (final t in [m.home!, m.away!])
            '${t.entryId}': [
              for (final member in picked[t.entryId] ?? <int>{})
                {'member_id': member, 'captain': captain[t.entryId] == member, 'keeper': keeper[t.entryId] == member},
            ],
        },
      });
      if (res['success'] != true) {
        AppSnackbar.error('Could not save', res['message']?.toString() ?? 'Please try again.');
        return false;
      }
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Could not save', e.message);
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
