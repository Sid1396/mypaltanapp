import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:mypaltan/config/app_routes.dart';
import 'package:mypaltan/main.dart' as app;
import 'package:mypaltan/presentation/controllers/onboarding_controller.dart';

/// Walks the full registration against the live v2 backend with a test number.
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/registration_flow_test.dart
const testPhone = '9000000007';

Future<void> pumpUntil(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phone → OTP → about → jersey → sports → photo → done → profile', (t) async {
    await GetStorage.init();
    // Keep the developer's own login on this device: back it up, run from a clean state, restore at the end.
    final box = GetStorage();
    final saved = {for (final k in box.getKeys<Iterable<String>>()) k: box.read(k)};
    addTearDown(() async {
      await box.erase();
      for (final e in saved.entries) {
        await box.write(e.key, e.value);
      }
    });
    await box.erase();
    app.main();
    await t.pump(const Duration(seconds: 2));

    Future<void> shot(String name) async {
      await t.pump(const Duration(milliseconds: 600));
      await binding.takeScreenshot(name);
    }

    // Phone
    Get.toNamed(AppRoutes.login);
    await pumpUntil(t, find.text('Get OTP'));
    await t.enterText(find.byType(TextFormField), testPhone);
    await shot('01_phone');
    await t.tap(find.text('Get OTP'));

    // OTP
    await pumpUntil(t, find.text('Verify'));
    await shot('02_otp');
    final boxes = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await t.enterText(boxes.at(i), '123456'[i]);
      await t.pump(const Duration(milliseconds: 100));
    }

    // About you
    await pumpUntil(t, find.text('About you'));
    await shot('03_about_empty');
    await t.enterText(find.byType(TextField).first, 'Test Player');
    Get.find<OnboardingController>().birthdate.value = DateTime(2000, 5, 15);
    await t.tap(find.text('Male'));
    await shot('04_about_filled');
    await t.tap(find.text('Continue'));

    // Jersey
    await pumpUntil(t, find.text('Your jersey'));
    await t.pump(const Duration(milliseconds: 500));
    await t.enterText(find.byType(TextField).at(1), '7');
    await t.tap(find.text('L'));
    await shot('05_jersey');
    await t.tap(find.text('Size guide'));
    await pumpUntil(t, find.text('Measure around the fullest part of your chest.'));
    await shot('06_size_guide');
    Get.back();
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('Continue'));

    // Sports
    await pumpUntil(t, find.text('Sports & roles'));
    await shot('07_sports_empty');
    await t.tap(find.text('Cricket'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('All-rounder'));
    await t.tap(find.text('Right-handed'));
    await t.tap(find.text('Spin'));
    await t.pump(const Duration(milliseconds: 300));
    await t.ensureVisible(find.text('Football'));
    await t.tap(find.text('Football'));
    await t.pump(const Duration(milliseconds: 300));
    await t.ensureVisible(find.text('Forward'));
    await t.tap(find.text('Forward'));
    await shot('08_sports_filled');
    await t.tap(find.text('Continue'));

    // Photo (native picker can't be driven, so inject a generated square photo)
    await pumpUntil(t, find.text('Add your photo'));
    await shot('09_photo_empty');
    await t.tap(find.text('Tap to add'));
    await pumpUntil(t, find.text('Choose from gallery'));
    await t.pump(const Duration(milliseconds: 600));
    await shot('09b_source_sheet');
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(milliseconds: 600));
    final photo = img.Image(width: 600, height: 600);
    img.fill(photo, color: img.ColorRgb8(245, 80, 24));
    img.fillCircle(photo, x: 300, y: 250, radius: 120, color: img.ColorRgb8(255, 239, 230));
    final file = File('${Directory.systemTemp.path}/mp_test_photo.jpg')..writeAsBytesSync(img.encodeJpg(photo));
    Get.find<OnboardingController>().photoPath.value = file.path;
    await t.pump(const Duration(seconds: 2));
    await shot('10_photo_chosen');
    await t.tap(find.text('Finish'));
    await t.pump(const Duration(seconds: 3));
    await shot('10b_after_finish_3s');
    await t.pump(const Duration(seconds: 5));
    await shot('10c_after_finish_8s');

    // Done
    await pumpUntil(t, find.text("Let's play"), timeout: const Duration(seconds: 60));
    await t.pump(const Duration(seconds: 1));
    await shot('11_done');
    await t.tap(find.text("Let's play"));

    // Home
    await pumpUntil(t, find.text('Live now'), timeout: const Duration(seconds: 40));
    await t.pump(const Duration(seconds: 3));
    await shot('13_home_top');
    await t.drag(find.byType(ListView).first, const Offset(0, -700));
    await t.pump(const Duration(seconds: 2));
    await shot('14_home_middle');
    await t.drag(find.byType(ListView).first, const Offset(0, -900));
    await t.pump(const Duration(seconds: 2));
    await shot('15_home_bottom');

    // Notifications
    await t.drag(find.byType(ListView).first, const Offset(0, 3000));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.notifications_none_rounded));
    await pumpUntil(t, find.text('No notifications yet'));
    await shot('16_notifications');
    Get.back();
    await t.pump(const Duration(seconds: 1));

    // Create sheet
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('nav-create')));
    await pumpUntil(t, find.text('Create a tournament'));
    await t.pump(const Duration(milliseconds: 600));
    await shot('17_create_sheet');
    await t.tap(find.text('Create a team'));
    await pumpUntil(t, find.text('Creating teams is coming soon'));
    await t.pump(const Duration(milliseconds: 600));
    await shot('18_coming_soon');
    await t.tap(find.text('Got it'));
    await t.pump(const Duration(seconds: 1));

    // Tournaments tab + detail
    await t.tap(find.text('Tournaments').last);
    await t.pump(const Duration(seconds: 2));
    await shot('19_tournaments');
    await t.tap(find.text('Sai Siddhi Premier League').first);
    await pumpUntil(t, find.text('Notify me when registration opens'));
    await t.pump(const Duration(seconds: 2));
    await shot('20_tournament_detail');
    Get.back();
    await t.pump(const Duration(seconds: 1));

    // My Teams tab
    await t.tap(find.text('My Teams').last);
    await t.pump(const Duration(seconds: 1));
    await shot('21_my_teams');

    // Profile tab
    await t.tap(find.text('Profile').last);
    await pumpUntil(t, find.text('Log out'), timeout: const Duration(seconds: 30));
    await t.pump(const Duration(seconds: 3));
    await shot('22_profile');
  });
}
