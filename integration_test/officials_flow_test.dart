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
import 'package:mypaltan/presentation/controllers/create_tournament_controller.dart';
import 'package:mypaltan/presentation/widgets/tournament_form_widgets.dart';

/// Officials, on data made by the scratchpad's setup_officials.sh (2-day tournament).
/// PHASE=request    organiser edits the tournament, asks for a scorer, 2 referees and streaming, and saves
/// PHASE=confirmed  after staff confirm on mypaltan.com/approvals, the organiser sees who is coming
///
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/officials_flow_test.dart
///      --dart-define=CODE=XXXXXX --dart-define=PHASE=request
const base = 'https://n8n.sippzy.com/webhook/v2';
const phase = String.fromEnvironment('PHASE', defaultValue: 'request');
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

  testWidgets('officials · $phase', (t) async {
    await GetStorage.init();
    final box = GetStorage();
    final saved = {for (final k in box.getKeys<Iterable<String>>()) k: box.read(k)};
    addTearDown(() async {
      await box.erase();
      for (final e in saved.entries) {
        await box.write(e.key, e.value);
      }
    });
    final token = await _login('9000000031');
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, '9000000031');

    app.main();
    var n = phase == 'request' ? 0 : 10;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 900));
      await binding.takeScreenshot('of_${(n++).toString().padLeft(2, '0')}_$name');
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')), timeout: const Duration(seconds: 90));
    Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
    await pumpUntil(t, find.byKey(const ValueKey('tournament-cta')), timeout: const Duration(seconds: 60));

    if (phase == 'request') {
      expect(find.byKey(const ValueKey('officials-card')), findsNothing);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await pumpFor(t, const Duration(milliseconds: 500));
      await t.tap(find.byKey(const ValueKey('tournament-edit')));
      await pumpUntil(t, find.text('Edit tournament'), timeout: const Duration(seconds: 60));
      final c = Get.find<CreateTournamentController>();
      await pumpUntil(t, find.byKey(const ValueKey('t-next')));
      await pumpFor(t, const Duration(seconds: 2));
      c.goTo('officials');
      await pumpUntil(t, find.text('Need a scorer?'));
      await shot('step_off');
      await t.tap(find.descendant(of: find.byKey(const ValueKey('t-need-scorer')), matching: find.byType(Switch)));
      await t.tap(find.descendant(of: find.byKey(const ValueKey('t-need-umpires')), matching: find.byType(Switch)));
      await pumpFor(t, const Duration(milliseconds: 400));
      await t.tap(find.descendant(of: find.widgetWithText(NumberStepper, 'Referees per day'), matching: find.byIcon(Icons.add_rounded)));
      await t.tap(find.descendant(of: find.byKey(const ValueKey('t-need-stream')), matching: find.byType(Switch)));
      await pumpFor(t, const Duration(milliseconds: 400));
      // 1 scorer + 2 referees over 2 match days at ₹1,000-1,500 a day
      expect(c.officialPeople, 3);
      expect(c.matchDayCount, 2);
      expect(find.text('₹6,000 – ₹9,000'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('t-officials-note')), 'Streaming for the final only');
      FocusManager.instance.primaryFocus?.unfocus();
      await shot('step_on');
      c.goTo('review');
      await pumpUntil(t, find.text('Save changes'));
      await pumpFor(t, const Duration(seconds: 1));
      expect(find.text('1 scorer a day', skipOffstage: false), findsOneWidget);
      expect(find.text('2 referees a day', skipOffstage: false), findsOneWidget);
      await shot('review');
      await t.tap(find.byKey(const ValueKey('t-next')));
      await pumpUntil(t, find.byKey(const ValueKey('officials-card')), timeout: const Duration(seconds: 60));
      expect(find.text('MyPaltan is arranging your officials'), findsOneWidget);
      await shot('arranging');
    } else {
      await pumpUntil(t, find.text('Officials confirmed'), timeout: const Duration(seconds: 60));
      expect(find.byKey(const ValueKey('watch-live')), findsOneWidget);
      await shot('confirmed');
    }
    await pumpFor(t, const Duration(seconds: 2));
  });
}
