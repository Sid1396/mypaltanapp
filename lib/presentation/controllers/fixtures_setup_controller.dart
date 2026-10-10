import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/fixtures.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/snackbar_helper.dart';

/// One division's schedule choices on the "Make fixtures" screen.
class DivisionPlan {
  final FixtureDivision d;
  final include = true.obs;
  final afterPrevious = false.obs; // start straight after the previous division
  final start = DateTime(2000).obs;
  final pitches = 1.obs;
  final gap = 30.obs;
  final draw = 'RANDOM'.obs;
  final groups = <int, int>{}.obs; // entry id → group no (manual draw)
  final seeds = <int>[].obs; // entry ids, best first (manual knockout draw)

  DivisionPlan(this.d);

  int get teamCount => d.teams.length;
  bool get canSchedule => teamCount >= 2;
  int get groupCount => d.groupsFor(teamCount);
  bool get isKnockout => d.format == 'KNOCKOUT';

  /// Random or manual only matters when there is a draw to make.
  bool get hasDraw => isKnockout || groupCount > 1;

  List<int> groupSizes() {
    final g = groupCount;
    if (g <= 1) return [teamCount];
    if (draw.value == 'MANUAL') return [for (var k = 1; k <= g; k++) groups.values.where((v) => v == k).length];
    return [for (var k = 0; k < g; k++) teamCount ~/ g + (k < teamCount % g ? 1 : 0)];
  }

  int get qualifiers {
    if (d.format != 'LEAGUE_KNOCKOUT') return 0;
    final sizes = groupSizes();
    final smallest = sizes.isEmpty ? 0 : sizes.reduce((a, b) => a < b ? a : b);
    return groupCount * (d.qualifyPerGroup ?? 1).clamp(1, smallest < 1 ? 1 : smallest);
  }

  int get matchCount {
    if (isKnockout) return teamCount - 1;
    final group = groupSizes().fold<int>(0, (a, n) => a + n * (n - 1) ~/ 2);
    final q = qualifiers;
    return group + (q >= 2 ? q - 1 : 0);
  }

  /// '4 teams · 1 group · top 2 play the final · 7 matches'
  String get summary {
    final parts = ['$teamCount teams'];
    if (isKnockout) {
      parts.add('knockout');
    } else {
      parts.add(groupCount == 1 ? (d.format == 'LEAGUE' ? 'everyone plays everyone' : '1 group') : '$groupCount groups');
      final q = qualifiers;
      if (q == 2) parts.add('top 2 play the final');
      if (q > 2) parts.add('top $q go to the knockouts');
    }
    parts.add('$matchCount matches');
    return parts.join(' · ');
  }

  /// Default time between kick-offs: match length plus a 10-minute changeover, rounded up to 5 minutes.
  static int defaultGap(Map<String, dynamic> rules) {
    int roundUp(num m) => ((m / 5).ceil() * 5).clamp(10, 300);
    if (rules['half_minutes'] != null) return roundUp((rules['half_minutes'] as num) * 2 + 1 + 10);
    if (rules['overs'] != null) return roundUp((rules['overs'] as num) * 2 * 4 + 20);
    return 25;
  }
}

/// "Make fixtures" for the organiser. Arguments: {'code': 'ABC123'}. Returns true when fixtures were made.
class FixturesSetupController extends GetxController {
  ApiService get _api => Get.find<ApiService>();

  late final String code;
  final fixtures = Rx<Fixtures?>(null);
  final plans = <DivisionPlan>[].obs;
  final isLoading = true.obs;
  final isSaving = false.obs;
  final error = Rx<String?>(null);
  final dayStart = const TimeOfDay(hour: 9, minute: 0).obs;
  final dayEnd = const TimeOfDay(hour: 21, minute: 0).obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    code = (args is Map ? args['code'] as String? : null) ?? '';
    load();
  }

  static TimeOfDay? _tod(String? s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s ?? '');
    return m == null ? null : TimeOfDay(hour: int.parse(m[1]!), minute: int.parse(m[2]!));
  }

  static String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> load() async {
    error.value = null;
    try {
      final res = await _api.getFixtures(code);
      if (res['success'] != true) {
        error.value = res['message']?.toString() ?? 'Could not load the tournament.';
        return;
      }
      final f = Fixtures.fromJson(res);
      fixtures.value = f;
      dayStart.value = _tod(f.dayStart) ?? dayStart.value;
      dayEnd.value = _tod(f.dayEnd) ?? dayEnd.value;
      final first = DateTime(f.startDate.year, f.startDate.month, f.startDate.day, dayStart.value.hour, dayStart.value.minute);
      var firstIncluded = true;
      plans.assignAll(f.divisions.map((d) {
        final p = DivisionPlan(d);
        final s = d.settings;
        p.include.value = p.canSchedule;
        p.pitches.value = s?.pitches ?? 1;
        p.gap.value = s?.gapMinutes ?? DivisionPlan.defaultGap(d.matchRules);
        p.draw.value = s?.draw ?? 'RANDOM';
        p.start.value = s?.start ?? first;
        p.afterPrevious.value = p.canSchedule && !firstIncluded && s?.start == null;
        if (p.canSchedule) firstIncluded = false;
        // Manual draw starts from the current groups / seeds, or an even split.
        final g = p.groupCount;
        for (var i = 0; i < d.teams.length; i++) {
          final t = d.teams[i];
          p.groups[t.entryId] = (t.groupNo != null && t.groupNo! <= g) ? t.groupNo! : (g <= 1 ? 1 : i % g + 1);
        }
        final bySeed = [...d.teams]..sort((a, b) => (a.seed ?? 999).compareTo(b.seed ?? 999));
        p.seeds.assignAll(bySeed.map((t) => t.entryId));
        return p;
      }));
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  List<DivisionPlan> get included => plans.where((p) => p.include.value && p.canSchedule).toList();

  /// The division before [p] in the schedule, for "Right after Under 7".
  DivisionPlan? previousOf(DivisionPlan p) {
    final list = included;
    final i = list.indexOf(p);
    return i > 0 ? list[i - 1] : null;
  }

  void moveSeed(DivisionPlan p, int index, int by) {
    final j = index + by;
    if (j < 0 || j >= p.seeds.length) return;
    final v = p.seeds.removeAt(index);
    p.seeds.insert(j, v);
  }

  String? validate() {
    final list = included;
    if (list.isEmpty) return 'No division has 2 confirmed teams yet. Confirm teams in the Teams tab first.';
    final s = dayStart.value, e = dayEnd.value;
    if (e.hour * 60 + e.minute <= s.hour * 60 + s.minute) return 'The day must end after it starts.';
    for (final p in list) {
      if (p.draw.value == 'MANUAL' && !p.isKnockout && p.groupCount > 1) {
        for (var k = 1; k <= p.groupCount; k++) {
          if (p.groups.values.where((v) => v == k).length < 2) return '${p.d.name}: Group ${groupLetters[k - 1]} needs at least 2 teams.';
        }
      }
    }
    return null;
  }

  Future<void> generate() async {
    final err = validate();
    if (err != null) return AppSnackbar.error('Check the schedule', err);
    isSaving.value = true;
    try {
      final res = await _api.generateFixtures({
        'code': code,
        'day_start': hhmm(dayStart.value),
        'day_end': hhmm(dayEnd.value),
        'divisions': [
          for (final p in included)
            {
              'division_id': p.d.id,
              'start': p.afterPrevious.value && previousOf(p) != null ? null : fixtureTimeString(p.start.value),
              'pitches': p.pitches.value,
              'gap_minutes': p.gap.value,
              'draw': p.hasDraw ? p.draw.value : 'RANDOM',
              if (p.draw.value == 'MANUAL' && !p.isKnockout) 'groups': {for (final e in p.groups.entries) '${e.key}': e.value},
              if (p.draw.value == 'MANUAL' && p.isKnockout) 'seeds': p.seeds.toList(),
            },
        ],
      });
      if (res['success'] != true) {
        AppSnackbar.error('Could not make fixtures', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      Get.back(result: true);
      AppSnackbar.success('Fixtures ready', res['message']?.toString() ?? 'Check them, then publish.');
    } on ApiException catch (e) {
      AppSnackbar.error('Could not make fixtures', e.message);
    } finally {
      isSaving.value = false;
    }
  }
}
