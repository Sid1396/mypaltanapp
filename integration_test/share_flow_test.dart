import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mypaltan/config/app_constants.dart';
import 'package:mypaltan/data/services/deep_link_service.dart';
import 'package:mypaltan/main.dart' as app;

/// Opens a published tournament by code, shows the share sheet and the QR poster, and checks link parsing.
/// Run with: --dart-define=TOKEN=... --dart-define=PHONE=... --dart-define=CODE=...
const token = String.fromEnvironment('TOKEN');
const phone = String.fromEnvironment('PHONE');
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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('tournament links are parsed', () {
    expect(DeepLinkService.codeFrom(Uri.parse('https://mypaltan.com/tournament/ab12cd')), 'AB12CD');
    expect(DeepLinkService.codeFrom(Uri.parse('https://www.mypaltan.com/tournament/AB12CD?x=1')), 'AB12CD');
    expect(DeepLinkService.codeFrom(Uri.parse('mypaltan://tournament/AB12CD')), 'AB12CD');
    expect(DeepLinkService.codeFrom(Uri.parse('https://evil.com/tournament/AB12CD')), isNull);
    expect(DeepLinkService.codeFrom(Uri.parse('https://mypaltan.com/tournament/AB12')), isNull);
    expect(DeepLinkService.codeFrom(Uri.parse('https://mypaltan.com/login')), isNull);
  });

  testWidgets('join with code → share sheet → QR poster', (t) async {
    await GetStorage.init();
    final box = GetStorage();
    final saved = {for (final k in box.getKeys<Iterable<String>>()) k: box.read(k)};
    addTearDown(() async {
      await box.erase();
      for (final e in saved.entries) {
        await box.write(e.key, e.value);
      }
    });
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, phone);

    app.main();
    var n = 0;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 800));
      await binding.takeScreenshot('sh_${(n++).toString().padLeft(2, '0')}_$name');
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')), timeout: const Duration(seconds: 90));
    await t.tap(find.text('Tournaments'));
    await pumpUntil(t, find.byKey(const ValueKey('join-with-code')));
    await shot('tournaments_tab');
    await t.tap(find.byKey(const ValueKey('join-with-code')));
    await pumpUntil(t, find.byKey(const ValueKey('join-code-field')));
    await t.enterText(find.byKey(const ValueKey('join-code-field')), code.toLowerCase());
    await shot('join_sheet');
    await t.tap(find.byKey(const ValueKey('join-code-go')));
    await pumpFor(t, const Duration(seconds: 4));
    debugPrint('DBG route after join: ${Get.currentRoute} args=${Get.arguments}');
    await shot('after_join');

    await pumpUntil(t, find.text('Share tournament'), timeout: const Duration(seconds: 60));
    await pumpFor(t, const Duration(seconds: 2));
    await shot('tournament_published');
    await t.tap(find.byKey(const ValueKey('tournament-cta')));
    await pumpUntil(t, find.byKey(const ValueKey('share-poster')));
    await shot('share_sheet');
    await t.tap(find.byKey(const ValueKey('share-poster')));
    await pumpUntil(t, find.byKey(const ValueKey('poster-share')));
    await pumpFor(t, const Duration(seconds: 3));
    await shot('poster');
    await t.tap(find.byKey(const ValueKey('poster-close')));
    await pumpFor(t, const Duration(seconds: 1));
  });
}
