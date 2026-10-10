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
import 'package:mypaltan/presentation/controllers/fixtures_setup_controller.dart';
import 'package:mypaltan/presentation/controllers/tournament_controller.dart';

/// Fixtures, on data made by the scratchpad's setup_fixtures.sh (Under 7 and Under 9, 4 confirmed teams each).
/// PHASE=org   organiser makes fixtures (Under 7 on 2 pitches), moves one match and publishes
/// PHASE=coach a coach sees the next match and the schedule
///
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/fixtures_flow_test.dart
///      --dart-define=CODE=XXXXXX --dart-define=PHASE=org
const base = 'https://n8n.sippzy.com/webhook/v2';
const phase = String.fromEnvironment('PHASE', defaultValue: 'org');
const code = String.fromEnvironment('CODE');

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

  testWidgets('fixtures · $phase', (t) async {
    await GetStorage.init();
    final box = GetStorage();
    final saved = {for (final k in box.getKeys<Iterable<String>>()) k: box.read(k)};
    addTearDown(() async {
      await box.erase();
      for (final e in saved.entries) {
        await box.write(e.key, e.value);
      }
    });
    final phone = phase == 'org' ? '9000000031' : '9000000021';
    final token = await _login(phone);
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, phone);

    app.main();
    var n = phase == 'org' ? 0 : 20;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 900));
      await binding.takeScreenshot('fx_${(n++).toString().padLeft(2, '0')}_$name');
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')), timeout: const Duration(seconds: 90));
    Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
    await pumpUntil(t, find.byKey(const ValueKey('tournament-cta')), timeout: const Duration(seconds: 60));

    if (phase == 'org') {
      await t.tap(find.byKey(const ValueKey('tournament-tab-2')));
      await pumpUntil(t, find.byKey(const ValueKey('fixtures-make')), timeout: const Duration(seconds: 60));
      await t.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await shot('no_fixtures');
      await t.tap(find.byKey(const ValueKey('fixtures-make')));

      // Setup: defaults give 25 min for 5-minute halves and 30 min for 8-minute halves; Under 9 runs right after Under 7.
      await pumpUntil(t, find.text('Playing hours each day'), timeout: const Duration(seconds: 60));
      final setup = Get.find<FixturesSetupController>();
      expect(setup.plans.map((p) => p.gap.value).toList(), [25, 30]);
      expect(setup.plans[1].afterPrevious.value, true);
      final pitches = find.byKey(ValueKey('fixtures-pitches-${setup.plans[0].d.id}'));
      await t.scrollUntilVisible(pitches, 250, scrollable: find.byType(Scrollable).first);
      await pumpFor(t, const Duration(milliseconds: 400));
      await t.tap(find.descendant(of: pitches, matching: find.byIcon(Icons.add_rounded)));
      await pumpFor(t, const Duration(milliseconds: 300));
      expect(setup.plans[0].pitches.value, 2);
      await shot('setup');
      await t.tap(find.byKey(const ValueKey('fixtures-generate')));

      // Draft schedule, same shape as the Football Fiesta sheet
      await pumpUntil(t, find.text('Draft'), timeout: const Duration(seconds: 60));
      final f = Get.find<TournamentController>().fixtures.value!;
      final times = f.allMatches.map((m) => '${m.at.hour}:${m.at.minute.toString().padLeft(2, '0')}').toList();
      expect(times, ['9:00', '9:00', '9:25', '9:25', '9:50', '9:50', '10:15', '10:40', '11:10', '11:40', '12:10', '12:40', '13:10', '13:40']);
      await shot('draft');
      await t.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await shot('draft_scrolled');

      // Move the Under 9 final to pitch 2
      final u9 = f.divisions.firstWhere((d) => d.name == 'Under 9');
      final finalKey = ValueKey('match-${u9.id}-7');
      await t.scrollUntilVisible(find.byKey(finalKey), 300, scrollable: find.byType(Scrollable).first);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await pumpFor(t, const Duration(milliseconds: 500));
      await t.tap(find.byKey(finalKey));
      await pumpUntil(t, find.byKey(const ValueKey('match-edit-save')));
      await t.tap(find.descendant(of: find.widgetWithText(Row, 'Pitch').last, matching: find.byIcon(Icons.add_rounded)));
      await shot('edit_match');
      await t.tap(find.byKey(const ValueKey('match-edit-save')));
      await pumpUntil(t, find.text('Saved'), timeout: const Duration(seconds: 60));
      expect(Get.find<TournamentController>().fixtures.value!.allMatches.last.pitch, 2);

      // Publish
      await t.scrollUntilVisible(find.byKey(const ValueKey('fixtures-publish')), -300, scrollable: find.byType(Scrollable).first);
      await t.drag(find.byType(CustomScrollView), const Offset(0, 250));
      await pumpFor(t, const Duration(milliseconds: 500));
      await t.tap(find.byKey(const ValueKey('fixtures-publish')));
      await pumpUntil(t, find.byKey(const ValueKey('fixtures-publish-confirm')));
      await t.tap(find.byKey(const ValueKey('fixtures-publish-confirm')));
      await pumpUntil(t, find.text('Published'), timeout: const Duration(seconds: 60));
      await shot('published');
    } else {
      await pumpUntil(t, find.byKey(const ValueKey('next-match-card')), timeout: const Duration(seconds: 60));
      await shot('next_match');
      await t.tap(find.byKey(const ValueKey('tournament-tab-2')));
      await pumpUntil(t, find.byKey(const ValueKey('fixtures-mine')));
      await t.drag(find.byType(CustomScrollView), const Offset(0, -450));
      await shot('fixtures_all');
      await t.tap(find.text('Under 9').first);
      await pumpFor(t, const Duration(milliseconds: 600));
      await shot('fixtures_u9');
    }
    await pumpFor(t, const Duration(seconds: 2));
  });
}
