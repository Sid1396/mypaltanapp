import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mypaltan/config/app_constants.dart';
import 'package:mypaltan/main.dart' as app;
import 'package:mypaltan/presentation/controllers/team_controllers.dart';
import 'package:path_provider/path_provider.dart';

/// Phase 1 (default): a coach (not playing) creates a football team, adds a child by hand, a second player
/// joins through the API, the coach makes them vice-captain and makes the child captain.
/// Phase 2 (--dart-define=JOIN_PHASE=true --dart-define=TEAM_CODE=XXXXXX): a third player opens the team
/// with "Join with code" and joins from the team page.
///
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/team_flow_test.dart
const base = 'https://n8n.sippzy.com/webhook/v2';
const joinPhase = bool.fromEnvironment('JOIN_PHASE');
const teamCodeArg = String.fromEnvironment('TEAM_CODE');
const captainPhone = '9000000021';
const playerPhone = '9000000022';
const joinerPhone = '9000000023';

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

Future<String> _image(String dir, String name, int r, int g, int b, String label) async {
  final im = img.Image(width: 600, height: 600);
  img.fill(im, color: img.ColorRgb8(r, g, b));
  img.fillCircle(im, x: 300, y: 300, radius: 190, color: img.ColorRgb8(255, 255, 255));
  img.drawString(im, label, font: img.arial48, x: 300 - label.length * 13, y: 276, color: img.ColorRgb8(r, g, b));
  final f = File('$dir/$name.png');
  await f.writeAsBytes(img.encodePng(im));
  return f.path;
}

Future<Map<String, dynamic>> _post(String path, Map body, [String? token]) async {
  final r = await http.post(Uri.parse('$base/$path'),
      headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'}, body: jsonEncode(body));
  return jsonDecode(r.body) as Map<String, dynamic>;
}

/// Logs a test user in through the API with a complete football profile.
Future<String> _login(String phone, String name, String photo) async {
  await _post('auth/send-otp', {'phone': phone});
  final v = await _post('auth/verify-otp', {'phone': phone, 'otp': '123456'});
  final token = v['token'] as String;
  if (v['profileComplete'] != true) {
    await _post('users/complete-profile', {
      'name': name,
      'birthdate': '1996-03-10',
      'gender': 'MALE',
      'jersey_name': name.split(' ').first.toUpperCase(),
      'jersey_number': 10,
      'jersey_size': 'M',
      'sports': [
        {'sport': 'FOOTBALL', 'role': 'MIDFIELDER'},
      ],
    }, token);
    final req = http.MultipartRequest('POST', Uri.parse('$base/users/photo'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('photo', photo, contentType: MediaType('image', 'png')));
    await req.send();
  }
  return token;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(joinPhase ? 'join a team with its code' : 'create team → add child → player joins → vice-captain', (t) async {
    await GetStorage.init();
    final box = GetStorage();
    final saved = {for (final k in box.getKeys<Iterable<String>>()) k: box.read(k)};
    addTearDown(() async {
      await box.erase();
      for (final e in saved.entries) {
        await box.write(e.key, e.value);
      }
    });

    final dir = (await getTemporaryDirectory()).path;
    final logo = await _image(dir, 'team_logo', 20, 90, 60, 'TIGERS');
    final kid = await _image(dir, 'kid', 200, 120, 40, 'AARAV');
    final face = await _image(dir, 'face', 90, 90, 160, 'ME');

    final phone = joinPhase ? joinerPhone : captainPhone;
    final token = await _login(phone, joinPhase ? 'Neha Joiner' : 'Coach Ravi', face);
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, phone);
    ImagePickerPlatform.instance = FakeImagePicker([logo, kid]);

    app.main();
    var n = joinPhase ? 20 : 0;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 900));
      await binding.takeScreenshot('tm_${(n++).toString().padLeft(2, '0')}_$name');
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')), timeout: const Duration(seconds: 90));

    if (joinPhase) {
      await t.tap(find.text('My Teams'));
      await pumpUntil(t, find.byKey(const ValueKey('team-join-code')));
      await shot('my_teams_empty');
      await t.tap(find.byKey(const ValueKey('team-join-code')));
      await pumpUntil(t, find.byKey(const ValueKey('team-code-field')));
      await t.enterText(find.byKey(const ValueKey('team-code-field')), teamCodeArg);
      await t.tap(find.byKey(const ValueKey('team-code-go')));
      await pumpUntil(t, find.byKey(const ValueKey('team-join')), timeout: const Duration(seconds: 60));
      await shot('join_card');
      await t.tap(find.byKey(const ValueKey('team-join')));
      await pumpUntil(t, find.text('SQUAD · 3'), timeout: const Duration(seconds: 60));
      await shot('joined');
      await t.tap(find.byKey(const ValueKey('team-back')));
      await pumpUntil(t, find.text('Tigers of Borivali'));
      await shot('my_teams_after_join');
      await pumpFor(t, const Duration(seconds: 4));
      return;
    }

    // Create the team from the Create button
    await t.tap(find.byKey(const ValueKey('nav-create')));
    await pumpUntil(t, find.byKey(const ValueKey('create-team')));
    await t.tap(find.byKey(const ValueKey('create-team')));
    await pumpUntil(t, find.text('Create a team'));
    await shot('form_empty');
    await t.tap(find.text('Football'));
    await t.tap(find.byKey(const ValueKey('team-logo')));
    await t.enterText(find.byKey(const ValueKey('team-name')), 'Tigers of Borivali');
    await t.enterText(find.byKey(const ValueKey('team-area')), 'Borivali West');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.dragUntilVisible(find.byKey(const ValueKey('team-role-coach')), find.byType(ListView).first, const Offset(0, -200));
    await t.tap(find.byKey(const ValueKey('team-role-coach')));
    final form = Get.find<TeamFormController>();
    final waitLogo = DateTime.now().add(const Duration(seconds: 40));
    while ((form.logo.busy.value || !form.logo.isSet) && DateTime.now().isBefore(waitLogo)) {
      await t.pump(const Duration(milliseconds: 250));
    }
    expect(form.shortCtrl.text, 'TOB');
    await shot('form_filled');
    await t.tap(find.byKey(const ValueKey('team-save')));

    // Team page as captain
    await pumpUntil(t, find.text('Invite players'), timeout: const Duration(seconds: 60));
    await shot('team_created');
    final tc = Get.find<TeamController>();
    final code = tc.code;

    // Add a child without the app
    await t.tap(find.byKey(const ValueKey('team-add-kid')));
    await pumpUntil(t, find.byKey(const ValueKey('kid-name')));
    await t.enterText(find.byKey(const ValueKey('kid-name')), 'Aarav Shah');
    await t.tap(find.byKey(const ValueKey('kid-dob')));
    await pumpUntil(t, find.text('OK'));
    await t.tap(find.text('OK'));
    await pumpFor(t, const Duration(milliseconds: 600));
    await t.tap(find.text('Photo'));
    await pumpFor(t, const Duration(seconds: 4));
    await t.tap(find.text('Forward'));
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('kid_sheet');
    await t.ensureVisible(find.byKey(const ValueKey('kid-save')));
    await t.tap(find.byKey(const ValueKey('kid-save')));
    // The coach is not counted, so the child is the first player
    await pumpUntil(t, find.text('SQUAD · 1'), timeout: const Duration(seconds: 60));
    expect(find.text('COACH'), findsWidgets);
    await shot('kid_added');

    // A second player joins through the link (API), then the captain makes them vice-captain
    final playerToken = await _login(playerPhone, 'Sam Player', face);
    final joined = await _post('teams/join', {'code': code}, playerToken);
    expect(joined['success'], true);
    await tc.load();
    await pumpUntil(t, find.text('Sam Player'));
    await t.ensureVisible(find.text('Sam Player'));
    await pumpFor(t, const Duration(milliseconds: 400));
    await t.tap(find.text('Sam Player'));
    await pumpUntil(t, find.text('Make vice-captain'));
    await shot('member_actions');
    await t.tap(find.text('Make vice-captain'));
    await pumpUntil(t, find.text('VC'), timeout: const Duration(seconds: 60));
    await shot('vice_captain');

    // The coach makes the child the on-field captain
    await t.ensureVisible(find.text('Aarav Shah'));
    await pumpFor(t, const Duration(milliseconds: 400));
    await t.tap(find.text('Aarav Shah'));
    await pumpUntil(t, find.text('Make captain'));
    await t.tap(find.text('Make captain'));
    await pumpUntil(t, find.text('Make captain').hitTestable());
    await t.tap(find.text('Make captain').last);
    await pumpUntil(t, find.text('C'), timeout: const Duration(seconds: 60));
    await shot('kid_captain');

    // My Teams tab
    await t.tap(find.byKey(const ValueKey('team-back')));
    await pumpFor(t, const Duration(seconds: 1));
    await t.tap(find.text('My Teams'));
    await pumpUntil(t, find.text('Tigers of Borivali'));
    await shot('my_teams');
    debugPrint('TEAM_CODE=$code');
    await pumpFor(t, const Duration(seconds: 4));
  });
}
