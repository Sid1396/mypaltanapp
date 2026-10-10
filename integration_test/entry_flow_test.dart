import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mypaltan/config/app_constants.dart';
import 'package:mypaltan/config/app_routes.dart';
import 'package:mypaltan/data/services/deep_link_service.dart';
import 'package:mypaltan/main.dart' as app;
import 'package:mypaltan/presentation/controllers/team_controllers.dart';

/// Team registration with the squad link, on data made by the scratchpad's setup_entries.sh.
/// PHASE=coach   coach registers for Open with no players and gets the squad link
/// PHASE=player  Rohan (not in the team) opens the squad link and joins team + squad
/// PHASE=sam     Sam (already in the team) opens the squad link and joins the squad
/// PHASE=edit    coach adds a kid with Edit squad
/// PHASE=org     organiser confirms the team
/// PHASE=check   Rohan sees the tournament under My tournaments
///
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/entry_flow_test.dart
///      --dart-define=CODE=XXXXXX --dart-define=TEAM=XXXXXX --dart-define=PHASE=coach
const base = 'https://n8n.sippzy.com/webhook/v2';
const phase = String.fromEnvironment('PHASE', defaultValue: 'coach');
const code = String.fromEnvironment('CODE');
const teamCode = String.fromEnvironment('TEAM');
const phones = {'coach': '9000000021', 'edit': '9000000021', 'player': '9000000024', 'check': '9000000024', 'sam': '9000000022', 'org': '9000000031'};

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

  testWidgets('team registration · $phase', (t) async {
    await GetStorage.init();
    final box = GetStorage();
    final saved = {for (final k in box.getKeys<Iterable<String>>()) k: box.read(k)};
    addTearDown(() async {
      await box.erase();
      for (final e in saved.entries) {
        await box.write(e.key, e.value);
      }
    });

    final phone = phones[phase]!;
    final token = await _login(phone);
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, phone);

    app.main();
    var n = {'coach': 0, 'player': 10, 'sam': 20, 'edit': 30, 'org': 40, 'check': 50}[phase]!;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 900));
      await binding.takeScreenshot('en_${(n++).toString().padLeft(2, '0')}_$name');
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')), timeout: const Duration(seconds: 90));

    if (phase == 'player' || phase == 'sam') {
      // The squad link opens the team page with the tournament
      final uri = Uri.parse(DeepLinkService.squadUrl(teamCode, code));
      expect(DeepLinkService.targetFrom(uri), ('team', teamCode));
      expect(DeepLinkService.squadTournamentFrom(uri), code);
      Get.toNamed(AppRoutes.team, arguments: {'code': teamCode, 'tournament': code});
      await pumpUntil(t, find.byKey(const ValueKey('squad-join')), timeout: const Duration(seconds: 60));
      await shot('squad_invite');
      await t.tap(find.byKey(const ValueKey('squad-join')));
      await pumpUntil(t, find.text("YOU'RE IN THE SQUAD"), timeout: const Duration(seconds: 60));
      await shot('in_squad');
      if (phase == 'player') {
        expect(Get.find<TeamController>().team.value!.players.any((p) => p.name == 'Rohan Kadam'), true, reason: 'joined the team too');
      }
      await pumpFor(t, const Duration(seconds: 2));
      return;
    }

    if (phase == 'check') {
      await t.tap(find.text('Tournaments').last);
      await pumpUntil(t, find.text('My tournaments'));
      await t.tap(find.text('My tournaments'));
      await pumpUntil(t, find.textContaining('PLAYING'), timeout: const Duration(seconds: 60));
      expect(find.textContaining('Confirmed'), findsOneWidget);
      await shot('my_tournaments_playing');
      return;
    }

    Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
    await pumpUntil(t, find.byKey(const ValueKey('tournament-cta')), timeout: const Duration(seconds: 60));

    if (phase == 'coach') {
      await pumpUntil(t, find.text('Register my team'));
      await t.tap(find.byKey(const ValueKey('tournament-cta')));
      await pumpUntil(t, find.text('Which team?'), timeout: const Duration(seconds: 60));
      await t.tap(find.byKey(const ValueKey('reg-next')));
      await pumpUntil(t, find.text('Which division?'));
      await t.tap(find.text('Open'));
      await t.tap(find.byKey(const ValueKey('reg-next')));
      await pumpUntil(t, find.text('Pick your squad'));
      // Free division: the squad step is the last one, and no players are needed yet
      expect(find.text('Register team'), findsOneWidget);
      await shot('squad_skip');
      await t.tap(find.byKey(const ValueKey('reg-next')));
      await pumpUntil(t, find.text('Now invite your players'), timeout: const Duration(seconds: 60));
      await shot('invite_sheet');
      Navigator.of(t.element(find.text('Now invite your players'))).pop();
      await pumpUntil(t, find.byKey(const ValueKey('my-entry-card')));
      expect(find.textContaining('0 of 6 players · need 3'), findsOneWidget);
      await shot('registered_no_players');
    } else if (phase == 'edit') {
      await pumpUntil(t, find.textContaining('2 of 6 players · need 3'), timeout: const Duration(seconds: 60));
      await shot('two_joined');
      await t.tap(find.byKey(const ValueKey('entry-squad-edit')));
      await pumpUntil(t, find.text('Edit squad'));
      await t.tap(find.text('Aarav Shah'));
      await shot('edit_squad');
      await t.tap(find.byKey(const ValueKey('squad-edit-save')));
      await pumpUntil(t, find.textContaining('3 of 6 players'), timeout: const Duration(seconds: 60));
      await pumpUntil(t, find.text('Squad saved'));
      expect(find.text('3 of 6 picked'), findsNothing, reason: 'sheet closed');
      await shot('three_players');
    } else if (phase == 'org') {
      await t.tap(find.byKey(const ValueKey('tournament-tab-1')));
      await pumpUntil(t, find.textContaining('WAITING FOR YOU'), timeout: const Duration(seconds: 60));
      await t.ensureVisible(find.textContaining('WAITING FOR YOU'));
      await t.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await pumpFor(t, const Duration(milliseconds: 600));
      await t.tap(find.text('Tigers of Borivali'));
      await pumpFor(t, const Duration(milliseconds: 600));
      expect(find.text('Rohan Kadam'), findsOneWidget);
      await shot('org_pending');
      final approve = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('entry-approve-') && w is! TextButton);
      await t.ensureVisible(approve);
      await t.tap(approve);
      await pumpUntil(t, find.byKey(const ValueKey('entry-approve-confirm')));
      await t.tap(find.byKey(const ValueKey('entry-approve-confirm')));
      await pumpUntil(t, find.text('OPEN · 1/4'), timeout: const Duration(seconds: 60));
      await shot('org_confirmed');
    }
    await pumpFor(t, const Duration(seconds: 3));
  });
}
