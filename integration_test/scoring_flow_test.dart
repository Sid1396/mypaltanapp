import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mypaltan/config/app_constants.dart';
import 'package:mypaltan/config/app_routes.dart';
import 'package:mypaltan/main.dart' as app;
import 'package:mypaltan/presentation/controllers/match_setup_controller.dart';
import 'package:mypaltan/presentation/controllers/scoring_controller.dart';

/// Live cricket scoring on data made by the scratchpad's setup_scoring.sh (2 overs, 4 a side).
/// PHASE=scorer  a user with the PIN sets the toss and XI and scores the whole match
/// PHASE=viewer  the organiser sees the result in Fixtures and the scorecard
///
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/scoring_flow_test.dart
///      --dart-define=CODE=XXXXXX --dart-define=MATCH=123 --dart-define=PIN=123456 --dart-define=PHASE=scorer
const base = 'https://n8n.sippzy.com/webhook/v2';
const phase = String.fromEnvironment('PHASE', defaultValue: 'scorer');
const code = String.fromEnvironment('CODE');
const matchId = int.fromEnvironment('MATCH');
const pin = String.fromEnvironment('PIN');

Future<void> pumpUntil(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 40)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<String> _login(String phone) async {
  Future<Map<String, dynamic>> post(String path, Map body) async =>
      jsonDecode((await http.post(Uri.parse('$base/$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))).body) as Map<String, dynamic>;
  await post('auth/send-otp', {'phone': phone});
  return (await post('auth/verify-otp', {'phone': phone, 'otp': '123456'}))['token'] as String;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live scoring · $phase', (t) async {
    await GetStorage.init();
    final box = GetStorage();
    final saved = {for (final k in box.getKeys<Iterable<String>>()) k: box.read(k)};
    addTearDown(() async {
      await box.erase();
      for (final e in saved.entries) {
        await box.write(e.key, e.value);
      }
    });
    final phone = phase == 'scorer' ? '9000000022' : '9000000031';
    final token = await _login(phone);
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, phone);

    app.main();
    var n = phase == 'scorer' ? 0 : 30;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 900));
      await binding.takeScreenshot('sc_${(n++).toString().padLeft(2, '0')}_$name');
    }

    Future<void> tap(String key) async {
      await pumpUntil(t, find.byKey(ValueKey(key)));
      await t.ensureVisible(find.byKey(ValueKey(key)));
      await pumpFor(t, const Duration(milliseconds: 300));
      await t.tap(find.byKey(ValueKey(key)));
      await pumpFor(t, const Duration(milliseconds: 350));
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')), timeout: const Duration(seconds: 90));

    if (phase == 'scorer') {
      Get.toNamed(AppRoutes.match, arguments: {'id': matchId});
      await pumpUntil(t, find.byKey(const ValueKey('match-score')), timeout: const Duration(seconds: 60));
      final needsPin = find.text('Score this match').evaluate().isNotEmpty;
      await shot('match_before');
      await tap('match-score');

      // PIN (only the first time in this tournament)
      if (needsPin) {
        await pumpUntil(t, find.byKey(const ValueKey('scoring-pin')));
        await t.enterText(find.byKey(const ValueKey('scoring-pin')), '000000');
        await tap('scoring-pin-go');
        await pumpUntil(t, find.textContaining('Wrong PIN'), timeout: const Duration(seconds: 30));
        await t.enterText(find.byKey(const ValueKey('scoring-pin')), pin);
        await shot('pin');
        await tap('scoring-pin-go');
      }

      // Toss and Playing XI
      await pumpUntil(t, find.text('Before the match'), timeout: const Duration(seconds: 60));
      final setup = Get.find<MatchSetupController>();
      await pumpUntil(t, find.text('They chose to'));
      final m = setup.match.value!;
      await t.tap(find.text(m.home!.name).first);
      await t.tap(find.text('Bat first'));
      await pumpFor(t, const Duration(milliseconds: 400));
      expect(setup.picked[m.home!.entryId]!.length, 4, reason: 'whole 4-player squad is ticked');
      await shot('setup');
      await tap('setup-save');

      // Innings 1
      await pumpUntil(t, find.byKey(const ValueKey('start-innings')), timeout: const Duration(seconds: 60));
      final sc = Get.find<ScoringController>();
      var s = sc.state.value!;
      final bat = s.playersOf(s.setup.firstBatting), bowl = s.playersOf(s.setup.other(s.setup.firstBatting));
      await tap('start-Striker-${bat[0].id}');
      await tap('start-Non-striker-${bat[1].id}');
      await tap('start-Opening bowler-${bowl[0].id}');
      await shot('start_innings');
      await tap('start-innings');
      await pumpUntil(t, find.byKey(const ValueKey('pad-1')));
      await tap('pad-1');
      await tap('pad-4');
      await tap('pad-W');
      await shot('wicket_sheet');
      await tap('wicket-save');
      await pumpUntil(t, find.text('New batter'));
      await shot('new_batter');
      await tap('pick-${bat[2].id}');
      await tap('pad-0');
      await tap('pad-Wd');
      await tap('runs-WIDE-0');
      await tap('pad-6');
      await tap('pad-2');
      await pumpUntil(t, find.text('Bowler for the next over'));
      await shot('over_end');
      await tap('pick-${bowl[1].id}');
      for (var i = 0; i < 6; i++) {
        await tap('pad-1');
      }
      s = sc.state.value!;
      expect(s.innings.first.runs, 20);
      expect(s.innings.first.wickets, 1);
      expect(s.status, 'INNINGS_BREAK');
      await shot('innings_break');

      // Innings 2: chase 21
      final bat2 = s.playersOf(s.innings.first.bowling), bowl2 = s.playersOf(s.innings.first.batting);
      await tap('start-Striker-${bat2[0].id}');
      await tap('start-Non-striker-${bat2[1].id}');
      await tap('start-Opening bowler-${bowl2[0].id}');
      await tap('start-innings');
      await pumpUntil(t, find.byKey(const ValueKey('pad-6')));
      await tap('pad-6');
      await tap('pad-6');
      await tap('pad-Undo');
      expect(sc.state.value!.current!.runs, 6, reason: 'undo removed the second six');
      await tap('pad-6');
      await tap('pad-6');
      await shot('chasing');
      await tap('pad-4');
      await pumpUntil(t, find.byKey(const ValueKey('score-done')));
      expect(sc.state.value!.winner, s.innings.first.bowling);
      await pumpUntil(t, find.text('Saved'), timeout: const Duration(seconds: 60));
      expect(sc.pending, isEmpty);
      await shot('result');
      await tap('score-done');
      await pumpFor(t, const Duration(seconds: 3));
      await shot('after_done');
      await pumpUntil(t, find.byKey(const ValueKey('match-tab-1')), timeout: const Duration(seconds: 60));
      await tap('match-tab-1');
      await shot('scorecard');
    } else if (phase == 'stats') {
      // After the scored match: leaderboards in the Stats tab.
      Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
      await pumpUntil(t, find.byKey(const ValueKey('tournament-tab-3')), timeout: const Duration(seconds: 60));
      await tap('tournament-tab-3');
      await pumpUntil(t, find.byKey(const ValueKey('stats-most_runs')), timeout: const Duration(seconds: 60));
      await t.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await pumpFor(t, const Duration(milliseconds: 600));
      await shot('stats');
      // In the scored match, Eshan made 22 (6, 6, 6, 4) and Chirag 8.
      expect(find.descendant(of: find.byKey(const ValueKey('stats-most_runs')), matching: find.text('22')), findsOneWidget);
      expect(find.byKey(const ValueKey('stats-most_sixes')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('stats-most_runs')));
      await pumpFor(t, const Duration(seconds: 1));
      await shot('stats_all_runs');
    } else if (phase == 'table') {
      // Both group matches scored: points tables and the final filled with the group winners.
      Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
      await pumpUntil(t, find.byKey(const ValueKey('tournament-tab-2')), timeout: const Duration(seconds: 60));
      await tap('tournament-tab-2');
      await pumpUntil(t, find.textContaining('POINTS TABLE'), timeout: const Duration(seconds: 60));
      await t.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await pumpFor(t, const Duration(milliseconds: 600));
      await shot('points_table');
      expect(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('q-')), findsNWidgets(2),
          reason: 'one qualifier per group, marked once the groups are done');
      await t.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await pumpFor(t, const Duration(milliseconds: 600));
      expect(find.textContaining('Group A'), findsWidgets);
      expect(find.text('1st Group A'), findsNothing, reason: 'the final shows the real teams now');
      await shot('final_filled');
    } else {
      Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
      await pumpUntil(t, find.byKey(const ValueKey('tournament-tab-2')), timeout: const Duration(seconds: 60));
      await tap('tournament-tab-2');
      await pumpUntil(t, find.byKey(const ValueKey('scoring-pin-card')), timeout: const Duration(seconds: 60));
      await tap('scoring-pin-show');
      await pumpUntil(t, find.byKey(const ValueKey('scoring-pin-value')));
      expect(find.textContaining('Aniket Scorer'), findsOneWidget, reason: 'the scorer who used the PIN is listed');
      await t.drag(find.byType(CustomScrollView), const Offset(0, -450));
      await pumpUntil(t, find.textContaining('won by 3 wickets'), timeout: const Duration(seconds: 30));
      await shot('fixtures_result');
      await t.tap(find.textContaining('won by 3 wickets').first);
      await pumpUntil(t, find.byKey(const ValueKey('match-tab-1')), timeout: const Duration(seconds: 60));
      await tap('match-tab-2');
      await shot('commentary');
    }
    await pumpFor(t, const Duration(seconds: 2));
  });
}
