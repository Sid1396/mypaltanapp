import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/sports.dart';
import '../../data/models/quick_match.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';
import '../widgets/tournament_form_widgets.dart';

/// "Quick match": pick the sport, name the teams, set the rules. Opens the match page when made.
class CreateQuickMatchController extends GetxController {
  ApiService get _api => Get.find<ApiService>();

  final sport = 'CRICKET'.obs;
  final homeCtrl = TextEditingController(text: 'Team A');
  final awayCtrl = TextEditingController(text: 'Team B');
  final groundCtrl = TextEditingController();
  final when = Rx<DateTime?>(null); // null = now
  final mySide = 'HOME'.obs; // HOME, AWAY or '' (not playing)
  final saving = false.obs;

  // Rules
  final overs = 6.obs;
  final lastManStands = false.obs;
  final halfMinutes = 10.obs;
  final racketEvent = 'DOUBLES'.obs;
  final pointsPerGame = 21.obs;
  final games = 3.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    final s = args is Map ? args['sport'] as String? : null;
    if (s != null && Sports.byCode(s) != null) selectSport(s);
  }

  @override
  void onClose() {
    homeCtrl.dispose();
    awayCtrl.dispose();
    groundCtrl.dispose();
    super.onClose();
  }

  void selectSport(String s) {
    sport.value = s;
    pointsPerGame.value = s == 'PICKLEBALL' ? 11 : 21;
    games.value = s == 'PICKLEBALL' ? 1 : 3;
  }

  Map<String, dynamic> get _rules => switch (sport.value) {
        'CRICKET' => {'overs': overs.value, 'last_batter': lastManStands.value},
        'FOOTBALL' => {'half_minutes': halfMinutes.value},
        _ => {'event': racketEvent.value, 'points_per_game': pointsPerGame.value, 'games': games.value},
      };

  Future<void> pickWhen(BuildContext context) async {
    final now = DateTime.now();
    final init = when.value ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      builder: _theme,
    );
    if (d == null || !context.mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init), builder: _theme);
    if (t == null) return;
    when.value = DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  static Widget _theme(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.darkSurface)),
        child: child!,
      );

  String get whenText {
    final w = when.value;
    if (w == null) return 'Now';
    return fmtQuickTime(w);
  }

  Future<void> create() async {
    final home = homeCtrl.text.trim(), away = awayCtrl.text.trim();
    if (home.length < 2 || away.length < 2) return AppSnackbar.error('Team names', 'Give both teams a name (at least 2 letters).');
    if (home.toLowerCase() == away.toLowerCase()) return AppSnackbar.error('Team names', 'Give the two teams different names.');
    final w = when.value;
    saving.value = true;
    try {
      final res = await _api.createQuickMatch({
        'sport': sport.value,
        'home_name': home,
        'away_name': away,
        'rules': _rules,
        if (groundCtrl.text.trim().isNotEmpty) 'ground': groundCtrl.text.trim(),
        if (w != null) 'scheduled_at': '${w.year}-${_pad2(w.month)}-${_pad2(w.day)} ${_pad2(w.hour)}:${_pad2(w.minute)}',
        'my_side': mySide.value.isEmpty ? null : mySide.value,
      });
      if (res['success'] != true) {
        AppSnackbar.error('Could not create', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      Get.offNamed(AppRoutes.quickMatch, arguments: {'code': res['code'], 'created': true});
    } on ApiException catch (e) {
      AppSnackbar.error('Could not create', e.message);
    } finally {
      saving.value = false;
    }
  }
}

String _pad2(int v) => v.toString().padLeft(2, '0');

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Today · 6:30 pm", "Sat 21 Nov · 7:00 am".
String fmtQuickTime(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day), day = DateTime(d.year, d.month, d.day);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final time = '$h:${_pad2(d.minute)} ${d.hour < 12 ? 'am' : 'pm'}';
  final diff = day.difference(today).inDays;
  final label = diff == 0 ? 'Today' : (diff == 1 ? 'Tomorrow' : '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}');
  return '$label · $time';
}

/// Parses the server's India-time "YYYY-MM-DD HH:mm".
DateTime? parseQuickTime(String? s) => s == null ? null : DateTime.tryParse(s.replaceFirst(' ', 'T'));

/// The quick match page. Arguments: {'code': 'ABC123', 'created'?: true}.
class QuickMatchController extends GetxController with LoggerMixin {
  ApiService get _api => Get.find<ApiService>();

  late final String code;
  final match = Rx<QuickMatch?>(null);
  final isLoading = true.obs;
  final error = Rx<String?>(null);
  final busy = false.obs;
  Timer? _refresh;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    code = ((args is Map ? args['code'] as String? : null) ?? '').toUpperCase();
    final created = args is Map && args['created'] == true;
    load().then((_) {
      if (created && match.value != null) shareMatch();
    });
    // People join from the group; keep the lists fresh while the page is open and the match hasn't finished.
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) {
      final m = match.value;
      if (m != null && !m.isCompleted && !m.isCancelled && !busy.value) load(quiet: true);
    });
  }

  @override
  void onClose() {
    _refresh?.cancel();
    super.onClose();
  }

  Future<void> load({bool quiet = false}) async {
    if (!quiet) error.value = null;
    try {
      final res = await _api.getQuickMatch(code);
      if (res['success'] == true && res['match'] is Map) {
        match.value = QuickMatch.fromJson(Map<String, dynamic>.from(res['match'] as Map));
      } else if (!quiet) {
        error.value = res['message']?.toString() ?? 'Could not load this match.';
      }
    } on ApiException catch (e) {
      if (!quiet && match.value == null) error.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _action(String action, {String? side, int? userId, String? title}) async {
    busy.value = true;
    try {
      final res = await _api.quickMatchAction(code, action, side: side, userId: userId);
      if (res['success'] == true) {
        AppSnackbar.success(title ?? 'Quick match', res['message']?.toString() ?? 'Done.');
        await load(quiet: true);
      } else {
        AppSnackbar.error(title ?? 'Quick match', res['message']?.toString() ?? 'Please try again.');
      }
    } on ApiException catch (e) {
      AppSnackbar.error(title ?? 'Quick match', e.message);
    } finally {
      busy.value = false;
    }
  }

  Future<void> join() => _action('JOIN', title: "I'm in");

  /// Creator: put someone in a team (side HOME / AWAY) or take them out of both (null).
  Future<void> assign(QuickPerson p, String? side) => _action('ASSIGN', side: side, userId: p.userId, title: 'Teams');

  void confirmShuffle() => _confirm(
        'Shuffle the teams?',
        'Everyone who is in (except the captains) is split at random into two even teams.',
        'Shuffle',
        () => _action('SHUFFLE', title: 'Teams'),
      );
  Future<void> leave() => _action('LEAVE', title: 'Quick match');

  void confirmCancel() => _confirm('Cancel this match?', 'Everyone with the link will see it as cancelled. This cannot be undone.', 'Cancel match',
      () => _action('CANCEL', title: 'Quick match'),
      danger: true, keepLabel: 'Keep it');

  /// Creator: pick a captain for [side] from the people who are in (or yourself).
  void pickCaptain(String side) {
    final m = match.value;
    if (m == null) return;
    final team = m.sideOf(side);
    final other = m.sideOf(side == 'HOME' ? 'AWAY' : 'HOME');
    // Everyone in the list who isn't playing for the other team; the creator can always pick themselves.
    final options = [
      if (!m.people.any((p) => p.userId == m.myUserId)) QuickPerson(userId: m.myUserId, name: m.creatorName),
      ...m.people,
    ].where((p) => p.userId != other?.captainId).toList(); // a player in the other team moves over when picked
    Get.bottomSheet(
      Builder(
          builder: (sheet) => SheetFrame(title: 'Captain of ${team?.name ?? 'the team'}', children: [
                Text(
                  options.length <= 1
                      ? 'Share the match link first. People who tap "I\'m in" show up here.'
                      : 'Pick from the people who tapped "I\'m in". Captains see the scoring PIN in the app.',
                  style: tfStyle(13.5, color: Colors.white.withAlpha(170), height: 1.4),
                ),
                gapH(12),
                for (final p in options)
                  Padding(
                    padding: EdgeInsets.only(bottom: SizeConfig.h(8)),
                    child: Material(
                      color: team?.captainId == p.userId ? AppColors.primary.withAlpha(60) : const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                      child: InkWell(
                        key: ValueKey('captain-pick-${p.userId}'),
                        borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                        onTap: () {
                          Navigator.of(sheet).pop();
                          _action('SET_CAPTAIN', side: side, userId: p.userId, title: 'Captain');
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(13)),
                          child: Row(children: [
                            Expanded(child: Text(p.userId == m.myUserId ? '${p.name} (you)' : p.name, style: tfStyle(14.5, weight: FontWeight.w700))),
                            if (team?.captainId == p.userId) Text('Captain', style: tfStyle(12, weight: FontWeight.w700, color: AppColors.primary)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                gapH(4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      shareMatch();
                    },
                    child: Text('Share the match link', style: tfStyle(14, weight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ),
              ])),
      isScrollControlled: true,
    );
  }

  // ─── Sharing ──────────────────────────────────────────────────

  String _sportEmoji(String s) => switch (s) { 'CRICKET' => '🏏', 'FOOTBALL' => '⚽', 'BADMINTON' => '🏸', _ => '🏓' };

  String get _whenWhere {
    final m = match.value!;
    final at = parseQuickTime(m.scheduledAt);
    return [if (at != null) fmtQuickTime(at), if (m.ground.isNotEmpty && m.ground != 'Quick match') m.ground].join(' · ');
  }

  Future<void> _share(String text, String subject) async {
    final opened =
        await launchUrl(Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened) await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  Future<void> shareMatch() async {
    final m = match.value;
    if (m == null) return;
    await _share(
      '${_sportEmoji(m.sport)} *${m.name}* on MyPaltan\n${m.rulesText}${_whenWhere.isEmpty ? '' : '\n$_whenWhere'}\n\n'
      'Playing? Tap the link and hit "I\'m in" 👇\n${m.link}',
      m.name,
    );
  }

  void copyPin() {
    final pin = match.value?.scoringPin;
    if (pin == null) return;
    Clipboard.setData(ClipboardData(text: pin));
    AppSnackbar.success('Copied', 'Scoring PIN copied. Give it to whoever will score.');
  }

  /// Opens the match: squads / toss, then scoring (the PIN is asked there if needed).
  Future<void> openMatch() async {
    final m = match.value;
    if (m == null) return;
    await Get.toNamed(AppRoutes.match, arguments: {'id': m.matchId});
    await load(quiet: true);
  }

  void _confirm(String title, String body, String action, VoidCallback onYes, {bool danger = false, String keepLabel = 'Cancel'}) {
    Get.dialog(AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(18))),
      title: Text(title, style: tfStyle(18, weight: FontWeight.w800)),
      content: Text(body, style: tfStyle(13.5, color: Colors.white.withAlpha(180), height: 1.45)),
      actions: [
        TextButton(onPressed: Get.back, child: Text(keepLabel, style: tfStyle(14, color: Colors.white.withAlpha(180)))),
        TextButton(
          key: const ValueKey('quick-confirm'),
          onPressed: () {
            Get.back();
            onYes();
          },
          child: Text(action, style: tfStyle(14, weight: FontWeight.w700, color: danger ? AppColors.negative : AppColors.primary)),
        ),
      ],
    ));
  }
}

/// Tournaments → Quick matches.
class MyQuickMatchesController extends GetxController {
  ApiService get _api => Get.find<ApiService>();

  final items = <MyQuickMatch>[].obs;
  final isLoading = false.obs;
  final loaded = false.obs;

  Future<void> load() async {
    isLoading.value = true;
    try {
      final res = await _api.getMyQuickMatches();
      if (res['success'] == true) {
        items.assignAll((res['matches'] as List? ?? []).whereType<Map>().map((m) => MyQuickMatch.fromJson(Map<String, dynamic>.from(m))));
        loaded.value = true;
      }
    } on ApiException catch (e) {
      AppSnackbar.error('Quick matches', e.message);
    } finally {
      isLoading.value = false;
    }
  }

  void ensureLoaded() {
    if (!loaded.value && !isLoading.value) load();
  }

  Future<void> open(String code) async {
    await Get.toNamed(AppRoutes.quickMatch, arguments: {'code': code});
    load();
  }

  Future<void> create() async {
    await Get.toNamed(AppRoutes.createQuickMatch);
    load();
  }
}
