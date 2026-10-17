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
import 'package:mypaltan/presentation/controllers/scoring_controller.dart';

/// Football and badminton scoring on data made by the scratchpad's setup_sport.sh.
/// PHASE=football   5-a-side, 3-minute halves: goals, a card, half-time, full time
/// PHASE=badminton  singles to 5, best of 3
///
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/sports_flow_test.dart
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

  testWidgets('sports scoring · $phase', (t) async {
    await GetStorage.init();
    final box = GetStorage();
    final saved = {for (final k in box.getKeys<Iterable<String>>()) k: box.read(k)};
    addTearDown(() async {
      await box.erase();
      for (final e in saved.entries) {
        await box.write(e.key, e.value);
      }
    });
    const phone = '9000000022';
    final token = await _login(phone);
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, phone);

    app.main();
    var n = phase == 'football' ? 0 : 20;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 900));
      await binding.takeScreenshot('sp_${(n++).toString().padLeft(2, '0')}_$name');
    }

    Future<void> tap(String key) async {
      await pumpUntil(t, find.byKey(ValueKey(key)));
      await t.ensureVisible(find.byKey(ValueKey(key)));
      await pumpFor(t, const Duration(milliseconds: 300));
      await t.tap(find.byKey(ValueKey(key)));
      await pumpFor(t, const Duration(milliseconds: 350));
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')), timeout: const Duration(seconds: 90));
    Get.toNamed(AppRoutes.match, arguments: {'id': matchId});
    await pumpUntil(t, find.byKey(const ValueKey('match-score')), timeout: const Duration(seconds: 60));
    await tap('match-score');
    await pumpUntil(t, find.byKey(const ValueKey('scoring-pin')));
    await t.enterText(find.byKey(const ValueKey('scoring-pin')), pin);
    await tap('scoring-pin-go');

    // Players: no toss outside cricket; the whole small squad is ticked already.
    await pumpUntil(t, find.text('Before the match'), timeout: const Duration(seconds: 60));
    expect(find.text('Who won the toss?'), findsNothing);
    await shot('setup');
    await tap('setup-save');

    final sc = Get.find<ScoringController>();
    await pumpUntil(t, find.byKey(const ValueKey('score-sync')), timeout: const Duration(seconds: 60));
    final m = sc.match.value!;
    final home = m.home!.entryId, away = m.away!.entryId;

    if (phase == 'football') {
      await tap('fb-kickoff');
      await tap('fb-goal-$home');
      final scorer = m.lineups.firstWhere((p) => p.entryId == home);
      await tap('scorer-${scorer.memberId}');
      await shot('goal_sheet');
      await tap('fb-goal-save');
      await tap('fb-card-$away');
      final carded = m.lineups.firstWhere((p) => p.entryId == away);
      await tap('card-player-${carded.memberId}');
      await tap('fb-card-save');
      await shot('first_half');
      await tap('fb-period-end');
      expect(find.text('Half-time'), findsWidgets);
      await tap('fb-start-period');
      await tap('fb-goal-$away');
      await tap('fb-goal-save');
      await tap('fb-goal-$home');
      await tap('fb-goal-save');
      await tap('fb-goal-$home');
      await tap('fb-goal-save');
      await tap('fb-undo');
      expect(find.text('2 - 1'), findsOneWidget, reason: 'undo removed the third home goal');
      await shot('second_half');
      await tap('fb-period-end');
      await pumpUntil(t, find.byKey(const ValueKey('score-done')));
      expect(sc.state.value!.toJson()['result'], '{$home} won 2-1');
    } else {
      await tap('rk-serve-$home');
      for (var i = 0; i < 5; i++) {
        await tap('rk-point-$home');
      }
      // Game 2: 0-4, then 4-4, 5-4 is not enough (win by two), 5-5 undone, 6-4 wins.
      for (var i = 0; i < 4; i++) {
        await tap('rk-point-$away');
      }
      for (var i = 0; i < 5; i++) {
        await tap('rk-point-$home');
      }
      expect(sc.state.value!.toJson()['current']['home'], 5, reason: '5-4 is still game 2');
      await shot('deuce');
      await tap('rk-point-$away');
      await tap('rk-undo');
      await tap('rk-point-$home');
      await pumpUntil(t, find.byKey(const ValueKey('score-done')));
      expect(sc.state.value!.toJson()['result'], '{$home} won 5-0, 6-4');
    }
    await pumpUntil(t, find.text('Saved'), timeout: const Duration(seconds: 60));
    expect(sc.pending, isEmpty);
    await shot('result');
    await tap('score-done');
    await pumpFor(t, const Duration(seconds: 3));
    await shot('match_page');
    await pumpFor(t, const Duration(seconds: 2));
  });
}
