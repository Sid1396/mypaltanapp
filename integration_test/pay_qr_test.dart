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

/// Paid team registration: the payment step offers "Save QR to phone" (no "Pay with a UPI app" link,
/// which GPay blocks for personal UPI IDs). Data from the scratchpad's setup_payqr.sh.
///
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/pay_qr_test.dart --dart-define=CODE=XXXXXX --dart-define=TEAM=XXXXXX
const base = 'https://n8n.sippzy.com/webhook/v2';
const code = String.fromEnvironment('CODE');
const team = String.fromEnvironment('TEAM');

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

  testWidgets('paid registration · save QR', (t) async {
    await GetStorage.init();
    final box = GetStorage();
    final saved = {for (final k in box.getKeys<Iterable<String>>()) k: box.read(k)};
    addTearDown(() async {
      await box.erase();
      for (final e in saved.entries) {
        await box.write(e.key, e.value);
      }
    });
    const phone = '9000000021';
    final token = await _login(phone);
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, phone);

    app.main();
    var n = 0;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 900));
      await binding.takeScreenshot('payqr_${(n++).toString().padLeft(2, '0')}_$name');
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')), timeout: const Duration(seconds: 90));
    Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
    await pumpUntil(t, find.text('Register my team'), timeout: const Duration(seconds: 60));
    await t.tap(find.byKey(const ValueKey('tournament-cta')));
    await pumpUntil(t, find.byKey(const ValueKey('reg-step-team')), timeout: const Duration(seconds: 60));
    await pumpUntil(t, find.byKey(const ValueKey('reg-team-$team')));
    await t.tap(find.byKey(const ValueKey('reg-team-$team')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('reg-next')));
    await pumpUntil(t, find.byKey(const ValueKey('reg-step-division')));
    await t.tap(find.text('Open').last);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('reg-next')));
    await pumpUntil(t, find.byKey(const ValueKey('reg-step-squad')));
    final player = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('reg-player-'));
    if (player.evaluate().isNotEmpty) await t.tap(player.first);
    await t.tap(find.byKey(const ValueKey('reg-next')));
    await pumpUntil(t, find.byKey(const ValueKey('reg-step-payment')));
    // UPI-only tournaments skip the UPI / cash choice.
    if (find.byKey(const ValueKey('reg-pay-upi')).evaluate().isNotEmpty) await t.tap(find.byKey(const ValueKey('reg-pay-upi')));
    await pumpFor(t, const Duration(seconds: 2));

    expect(find.text('Pay with a UPI app'), findsNothing);
    final save = find.byKey(const ValueKey('reg-save-qr'));
    await pumpUntil(t, save);
    await t.ensureVisible(save);
    await pumpFor(t, const Duration(seconds: 2)); // QR image loads
    await shot('payment_step');
    await t.tap(save);
    final result = find.byWidgetPredicate((w) =>
        w is Text && RegExp('QR saved to your photos|Could not save the QR|Allow photo access').hasMatch(w.data ?? ''));
    await pumpUntil(t, result, timeout: const Duration(seconds: 30));
    await shot('qr_result');
    expect((result.evaluate().first.widget as Text).data, 'QR saved to your photos');
    await pumpFor(t, const Duration(seconds: 4)); // let the message close before the test ends
  });
}
