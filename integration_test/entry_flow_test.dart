import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mypaltan/config/app_constants.dart';
import 'package:mypaltan/config/app_routes.dart';
import 'package:mypaltan/main.dart' as app;
import 'package:mypaltan/presentation/controllers/register_team_controller.dart';
import 'package:path_provider/path_provider.dart';

/// Team registration, on data made by the scratchpad's setup_entries.sh.
/// PHASE=coach (default): the coach registers 3 kids for Under 11, paying by UPI with a UTR and screenshot.
/// PHASE=org: the organiser opens the Teams tab, looks at the screenshot and confirms the team.
/// PHASE=check: the coach sees the confirmed team.
///
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/entry_flow_test.dart
///      --dart-define=CODE=XXXXXX [--dart-define=PHASE=org]
const base = 'https://n8n.sippzy.com/webhook/v2';
const phase = String.fromEnvironment('PHASE', defaultValue: 'coach');
const code = String.fromEnvironment('CODE');
const coachPhone = '9000000021';
const organiserPhone = '9000000031';

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

class FakeImagePicker extends ImagePickerPlatform {
  final List<String> queue;
  FakeImagePicker(this.queue);

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async =>
      queue.isEmpty ? null : XFile(queue.removeAt(0));
}

/// A fake UPI receipt.
Future<String> _receipt(String dir) async {
  final im = img.Image(width: 600, height: 1000);
  img.fill(im, color: img.ColorRgb8(245, 245, 245));
  img.fillRect(im, x1: 0, y1: 0, x2: 600, y2: 180, color: img.ColorRgb8(30, 120, 70));
  img.drawString(im, 'PAID 500', font: img.arial48, x: 190, y: 70, color: img.ColorRgb8(255, 255, 255));
  img.drawString(im, 'UTR 412345678901', font: img.arial24, x: 180, y: 300, color: img.ColorRgb8(40, 40, 40));
  final f = File('$dir/receipt.png');
  await f.writeAsBytes(img.encodePng(im));
  return f.path;
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

    final phone = phase == 'org' ? organiserPhone : coachPhone;
    final token = await _login(phone);
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, phone);
    ImagePickerPlatform.instance = FakeImagePicker([await _receipt((await getTemporaryDirectory()).path)]);

    app.main();
    var n = {'coach': 0, 'org': 20, 'check': 40}[phase]!;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 900));
      await binding.takeScreenshot('en_${(n++).toString().padLeft(2, '0')}_$name');
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')), timeout: const Duration(seconds: 90));
    Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
    await pumpUntil(t, find.byKey(const ValueKey('tournament-cta')), timeout: const Duration(seconds: 60));

    if (phase == 'coach') {
      await pumpUntil(t, find.text('Register my team'));
      await shot('tournament');
      await t.tap(find.byKey(const ValueKey('tournament-cta')));

      // Team: the only team is picked already
      await pumpUntil(t, find.text('Which team?'), timeout: const Duration(seconds: 60));
      expect(find.text('Tigers of Borivali'), findsOneWidget);
      await shot('step_team');
      await t.tap(find.byKey(const ValueKey('reg-next')));

      // Division
      await pumpUntil(t, find.text('Which division?'));
      await t.tap(find.text('Under 11'));
      await shot('step_division');
      await t.tap(find.byKey(const ValueKey('reg-next')));

      // Squad: the 12-year-old and the adult are blocked
      await pumpUntil(t, find.text('Pick your squad'));
      expect(find.textContaining('too old'), findsNWidgets(2));
      await t.tap(find.text('Ishaan Mehta'));
      await pumpFor(t, const Duration(milliseconds: 500));
      expect(find.text('0 of 5 picked'), findsOneWidget);
      for (final name in ['Aarav Shah', 'Vihaan Rao']) {
        await t.tap(find.text(name));
        await t.pump(const Duration(milliseconds: 200));
      }
      await t.tap(find.byKey(const ValueKey('reg-next')));
      await pumpFor(t, const Duration(milliseconds: 500));
      expect(find.text('Pick your squad'), findsOneWidget, reason: '2 players is below the minimum of 3');
      await t.tap(find.text('Kabir Jain'));
      await shot('step_squad');
      await t.tap(find.byKey(const ValueKey('reg-next')));

      // Payment by UPI with UTR and screenshot
      await pumpUntil(t, find.text('Pay the entry fee'));
      await shot('step_payment');
      await t.dragUntilVisible(find.byKey(const ValueKey('reg-proof')), find.byType(ListView).first, const Offset(0, -250));
      await t.enterText(find.byKey(const ValueKey('reg-utr')), '4123 4567 8901');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.ensureVisible(find.byKey(const ValueKey('reg-proof')));
      await pumpFor(t, const Duration(seconds: 1));
      await t.tap(find.byKey(const ValueKey('reg-proof')));
      final reg = Get.find<RegisterTeamController>();
      final waitProof = DateTime.now().add(const Duration(seconds: 40));
      while ((reg.proof.busy.value || !reg.proof.isSet) && DateTime.now().isBefore(waitProof)) {
        await t.pump(const Duration(milliseconds: 250));
      }
      expect(reg.proof.isSet, true, reason: 'payment screenshot uploaded');
      await shot('payment_filled');
      await t.tap(find.byKey(const ValueKey('reg-next')));

      await pumpUntil(t, find.byKey(const ValueKey('my-entry-card')), timeout: const Duration(seconds: 60));
      expect(find.text('Waiting for the organiser'), findsOneWidget);
      await shot('registered');
    } else if (phase == 'org') {
      await t.tap(find.byKey(const ValueKey('tournament-tab-1')));
      await pumpUntil(t, find.textContaining('WAITING FOR YOU'), timeout: const Duration(seconds: 60));
      await t.ensureVisible(find.textContaining('WAITING FOR YOU'));
      await shot('teams_pending');
      expect(find.textContaining('UTR 412345678901'), findsOneWidget);
      await t.tap(find.text('Tigers of Borivali'));
      await pumpFor(t, const Duration(milliseconds: 600));
      await shot('squad_open');
      final proof = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('entry-proof-'));
      await t.tap(proof);
      await pumpFor(t, const Duration(seconds: 3));
      await shot('proof');
      await t.tapAt(const Offset(200, 400));
      await pumpFor(t, const Duration(milliseconds: 800));
      final approve = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('entry-approve-') && w is! TextButton);
      await t.ensureVisible(approve);
      await t.tap(approve);
      await pumpUntil(t, find.byKey(const ValueKey('entry-approve-confirm')));
      await shot('confirm_dialog');
      await t.tap(find.byKey(const ValueKey('entry-approve-confirm')));
      await pumpUntil(t, find.text('UNDER 11 · 1/2'), timeout: const Duration(seconds: 60));
      expect(find.textContaining('WAITING FOR YOU'), findsNothing);
      await shot('confirmed');
    } else {
      await pumpUntil(t, find.text('Your team is in!'), timeout: const Duration(seconds: 60));
      await shot('coach_confirmed');
      await t.tap(find.byKey(const ValueKey('tournament-tab-1')));
      await pumpUntil(t, find.text('UNDER 11 · 1/2'));
      await shot('coach_teams');
    }
    await pumpFor(t, const Duration(seconds: 3));
  });
}
