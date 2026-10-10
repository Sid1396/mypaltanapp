import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
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
import 'package:mypaltan/presentation/controllers/create_tournament_controller.dart';
import 'package:path_provider/path_provider.dart';

/// Creates a full cricket tournament through the wizard against the live v2 backend, then
/// tries to publish (blocked until verified) and submits ID verification.
/// Phase 2 (PUBLISH_PHASE=1) assumes the test user was verified on the server, publishes and edits.
///
/// Run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/create_tournament_flow_test.dart
const testPhone = '9000000011';
const base = 'https://n8n.sippzy.com/webhook/v2';
const publishPhase = bool.fromEnvironment('PUBLISH_PHASE');

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

/// Returns generated images in order (logo, banner, QR, sponsor logo, ID photos...).
class FakeImagePicker extends ImagePickerPlatform {
  final List<String> queue;
  FakeImagePicker(this.queue);

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async =>
      queue.isEmpty ? null : XFile(queue.removeAt(0));
}

class FakeFilePicker extends FilePickerPlatform {
  final String pdfPath;
  FakeFilePicker(this.pdfPath);

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async =>
      FilePickerResult([PlatformFile(path: pdfPath, name: 'rules.pdf', size: File(pdfPath).lengthSync())]);
}

Future<String> _makeImage(String dir, String name, int w, int h, int r, int g, int b, String label) async {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(r, g, b));
  img.fillCircle(im, x: w ~/ 2, y: h ~/ 2, radius: (h * 0.3).round(), color: img.ColorRgb8(255, 255, 255));
  img.drawString(im, label, font: img.arial48, x: w ~/ 2 - label.length * 12, y: h ~/ 2 - 24, color: img.ColorRgb8(r, g, b));
  final f = File('$dir/$name.png');
  await f.writeAsBytes(img.encodePng(im));
  return f.path;
}

Future<String> _makePdf(String dir) async {
  const pdf = '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
      '3 0 obj<</Type/Page/MediaBox[0 0 300 400]/Parent 2 0 R/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n'
      '4 0 obj<</Length 60>>stream\nBT /F1 22 Tf 40 330 Td (Rule book) Tj ET\nendstream endobj\n'
      '5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n'
      'trailer<</Root 1 0 R>>\n%%EOF\n';
  final f = File('$dir/rules.pdf');
  await f.writeAsString(pdf);
  return f.path;
}

/// Logs the test user in through the API and makes sure the profile is complete, so the app opens on Home.
Future<String> _login(String photoPath) async {
  Future<Map<String, dynamic>> post(String path, Map body, [String? token]) async {
    final r = await http.post(Uri.parse('$base/$path'),
        headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'}, body: jsonEncode(body));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  await post('auth/send-otp', {'phone': testPhone});
  final v = await post('auth/verify-otp', {'phone': testPhone, 'otp': '123456'});
  final token = v['token'] as String;
  if (v['profileComplete'] != true) {
    await post('users/complete-profile', {
      'name': 'Test Organiser',
      'birthdate': '1995-06-01',
      'gender': 'MALE',
      'jersey_name': 'ORGANISER',
      'jersey_number': 9,
      'jersey_size': 'L',
      'sports': [
        {'sport': 'CRICKET', 'role': 'BATTER', 'batting_hand': 'RIGHT', 'bowling_style': 'NONE'},
      ],
    }, token);
    final req = http.MultipartRequest('POST', Uri.parse('$base/users/photo'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('photo', photoPath, contentType: MediaType('image', 'png')));
    final res = await req.send();
    if (res.statusCode != 200) throw TestFailure('Photo upload failed: ${await res.stream.bytesToString()}');
  }
  return token;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(publishPhase ? 'publish and edit' : 'create tournament → publish blocked → verify ID', (t) async {
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
    final logo = await _makeImage(dir, 'logo', 800, 800, 245, 80, 24, 'CPL');
    final banner = await _makeImage(dir, 'banner', 1600, 900, 18, 18, 18, 'CHARKOP PREMIER LEAGUE');
    final qr = await _makeImage(dir, 'qr', 600, 600, 40, 40, 40, 'UPI QR');
    final sponsorLogo = await _makeImage(dir, 'sponsor', 600, 600, 30, 90, 200, 'SHREE');
    final idFront = await _makeImage(dir, 'id_front', 1200, 760, 200, 200, 210, 'PAN CARD');
    final selfie = await _makeImage(dir, 'selfie', 900, 1200, 120, 90, 70, 'SELFIE');
    final pdf = await _makePdf(dir);

    final token = await _login(logo);
    await box.erase();
    await box.write(AppConstants.jwtTokenKey, token);
    await box.write(AppConstants.userPhoneKey, testPhone);

    ImagePickerPlatform.instance = FakeImagePicker([logo, banner, qr, sponsorLogo, idFront, selfie]);
    FilePickerPlatform.instance = FakeFilePicker(pdf);

    app.main();
    var n = publishPhase ? 40 : 0;
    Future<void> shot(String name) async {
      await pumpFor(t, const Duration(milliseconds: 700));
      await binding.takeScreenshot('ct_${(n++).toString().padLeft(2, '0')}_$name');
    }

    Future<void> next() async {
      await t.tap(find.byKey(const ValueKey('t-next')));
      await pumpFor(t, const Duration(milliseconds: 500));
    }

    await pumpUntil(t, find.byKey(const ValueKey('nav-create')));

    if (publishPhase) {
      await _publishAndEdit(t, shot);
      return;
    }

    // Open the wizard from the Create button
    await t.tap(find.byKey(const ValueKey('nav-create')));
    await pumpUntil(t, find.byKey(const ValueKey('create-tournament')));
    await shot('create_sheet');
    await t.tap(find.byKey(const ValueKey('create-tournament')));

    // 1. Sport
    await pumpUntil(t, find.text('Which sport?'));
    await t.tap(find.byKey(const ValueKey('sport-FOOTBALL')));
    await shot('sport');
    await next();

    // 2. Basics
    await pumpUntil(t, find.text('The basics'));
    await shot('basics_empty');
    await t.enterText(find.byKey(const ValueKey('t-name')), 'Junior Football Fiesta 2027');
    await t.tap(find.byKey(const ValueKey('t-logo')));
    await pumpUntil(t, find.byIcon(Icons.edit_rounded));
    await t.tap(find.text('Add banner'));
    await pumpUntil(t, find.byIcon(Icons.close_rounded).hitTestable());
    await pumpFor(t, const Duration(seconds: 1));
    final c = Get.find<CreateTournamentController>();
    final waitUploads = DateTime.now().add(const Duration(seconds: 40));
    while ((c.logo.busy.value || c.banner.busy.value || !c.banner.isSet) && DateTime.now().isBefore(waitUploads)) {
      await t.pump(const Duration(milliseconds: 250));
    }
    await t.tap(find.text('Community'));
    await t.enterText(find.byType(TextField).last, 'One-day football festival for kids, one age group at a time.');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('basics_filled');
    await next();

    // 3. Where & when
    await pumpUntil(t, find.text('Where & when'));
    await t.enterText(find.byKey(const ValueKey('t-area')), 'Borivali West');
    await t.enterText(find.byKey(const ValueKey('t-ground')), 'Pitch 1');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.enterText(find.byKey(const ValueKey('t-ground')), 'Pitch 2');
    await t.tap(find.byKey(const ValueKey('t-add-ground')));
    await pumpFor(t, const Duration(milliseconds: 300));
    expect(c.grounds.toList(), ['Pitch 1', 'Pitch 2']);
    final start = DateTime.now().add(const Duration(days: 30));
    c.setStartDate(DateTime(start.year, start.month, start.day));
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('venue');
    await next();

    // 4. Divisions: Under 7 and Under 9
    await pumpUntil(t, find.text('Divisions'));
    await shot('divisions_one');
    await t.tap(find.byKey(const ValueKey('divisions-many')));
    await pumpFor(t, const Duration(milliseconds: 300));
    await t.tap(find.byKey(const ValueKey('quick-Under 7')));
    await pumpFor(t, const Duration(milliseconds: 300));
    await t.tap(find.byKey(const ValueKey('quick-Under 9')));
    await pumpFor(t, const Duration(milliseconds: 300));
    expect(c.divisions.map((d) => d.name).toList(), ['Under 7', 'Under 9']);
    expect(c.divisions.map((d) => d.maxAge.value).toList(), [6, 8]);
    await shot('divisions_many');
    await next();

    // Under 7: groups + final, 4 teams, 3v3, 5-minute halves, ₹500
    await pumpUntil(t, find.text('Under 7 format'));
    await t.tap(find.byKey(const ValueKey('format-LEAGUE_KNOCKOUT')));
    c.divisions[0].maxTeams.value = 4;
    c.divisions[0].groupCount.value = 1;
    c.divisions[0].qualifyPerGroup.value = 2;
    c.divisions[0].squadMin.value = 6;
    c.divisions[0].squadMax.value = 6;
    await shot('u7_format');
    await next();
    await pumpUntil(t, find.text('Under 7 rules'));
    c.divisions[0].footballPlayers.value = 3;
    c.divisions[0].halfMinutes.value = 5;
    await shot('u7_rules');
    await next();
    await pumpUntil(t, find.text('Under 7 points'));
    expect(c.divisions[0].ptsWin.value, 3);
    await t.tap(find.text('Penalty shootout'));
    await shot('u7_points');
    await next();
    await pumpUntil(t, find.text('Under 7 fee & prize'));
    await t.enterText(find.byKey(const ValueKey('t-fee')), '500');
    await t.tap(find.text('Trophy'));
    await pumpFor(t, const Duration(milliseconds: 300));
    await t.enterText(find.byType(TextField).last, 'Medals for every player, trophy for the winners');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('u7_fees');
    await next();

    // Under 9: copy Under 7, then 5v5 with 8-minute halves and ₹600
    await pumpUntil(t, find.text('Under 9 format'));
    await t.tap(find.byKey(const ValueKey('copy-division-1')));
    await pumpFor(t, const Duration(milliseconds: 500));
    c.divisions[1].squadMin.value = 8;
    c.divisions[1].squadMax.value = 8;
    await shot('u9_format_copied');
    await next();
    await pumpUntil(t, find.text('Under 9 rules'));
    c.divisions[1].footballPlayers.value = 5;
    c.divisions[1].halfMinutes.value = 8;
    await next();
    await pumpUntil(t, find.text('Under 9 points'));
    await next();
    await pumpUntil(t, find.text('Under 9 fee & prize'));
    await t.enterText(find.byKey(const ValueKey('t-fee')), '600');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('u9_fees');
    await next();

    // 8. Payment (appears because there is a fee)
    await pumpUntil(t, find.text('How captains pay you'));
    await t.enterText(find.byKey(const ValueKey('t-upi')), 'fiesta@okaxis');
    await t.enterText(find.byKey(const ValueKey('t-upi-name')), 'Test Organiser');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.tap(find.text('Add QR'));
    await pumpUntil(t, find.byIcon(Icons.close_rounded).hitTestable());
    final waitQr = DateTime.now().add(const Duration(seconds: 40));
    while (!c.qr.isSet && DateTime.now().isBefore(waitQr)) {
      await t.pump(const Duration(milliseconds: 250));
    }
    c.acceptCash.value = true;
    await shot('payment');
    await next();

    // 9. Extras
    await pumpUntil(t, find.text('Food & jerseys'));
    c.foodProvided.value = true;
    await pumpFor(t, const Duration(milliseconds: 300));
    await t.tap(find.text('Dinner'));
    c.jerseyProvided.value = true;
    await pumpFor(t, const Duration(milliseconds: 300));
    await t.enterText(find.byType(TextField).last, '500');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('extras');
    await next();

    // 10. Registration (deadline was set from the start date)
    await pumpUntil(t, find.text('Registration closes'));
    await shot('registration');
    await next();

    // 11. Documents & sponsors
    await pumpUntil(t, find.text('Documents & sponsors'));
    await shot('media_empty');
    await t.tap(find.byKey(const ValueKey('t-add-doc')));
    await pumpUntil(t, find.text('Add a document'));
    await t.tap(find.text('Choose PDF or image'));
    await pumpUntil(t, find.text('PDF uploaded'));
    await shot('doc_sheet');
    await t.tap(find.text('Add document').last);
    await pumpFor(t, const Duration(milliseconds: 800));
    await t.tap(find.text('Add a sponsor'));
    await pumpUntil(t, find.text('Sponsor name'));
    await t.enterText(find.byType(TextField).at(0), 'Shree Sports');
    await t.tap(find.text('Title sponsor').first);
    await t.tap(find.text('Logo'));
    final waitSponsor = DateTime.now().add(const Duration(seconds: 40));
    while (find.byIcon(Icons.edit_rounded).evaluate().isEmpty && DateTime.now().isBefore(waitSponsor)) {
      await t.pump(const Duration(milliseconds: 250));
    }
    await pumpFor(t, const Duration(seconds: 1));
    await t.enterText(find.byType(TextField).at(2), 'shreesports.in');
    await t.enterText(find.byType(TextField).at(3), 'Gear up with the best');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('sponsor_sheet');
    await t.ensureVisible(find.text('Add sponsor'));
    await t.tap(find.text('Add sponsor'));
    await pumpFor(t, const Duration(milliseconds: 800));
    await shot('media_filled');
    await next();

    // 12. Review
    await pumpUntil(t, find.text('Check everything. Tap a section to change it.'));
    await shot('review_top');
    await t.drag(find.byType(ListView).first, const Offset(0, -700));
    await shot('review_middle');
    await t.drag(find.byType(ListView).first, const Offset(0, -900));
    await shot('review_bottom');
    await t.tap(find.text('Create tournament'));

    // Tournament page (draft)
    await pumpUntil(t, find.text('Publish tournament'), timeout: const Duration(seconds: 60));
    await shot('tournament_draft');
    await t.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await shot('tournament_about');
    await t.tap(find.byKey(const ValueKey('tournament-tab-3')));
    await shot('tournament_sponsors');
    await t.tap(find.byKey(const ValueKey('tournament-tab-4')));
    await shot('tournament_documents');
    await t.tap(find.text('Rules'));
    await pumpFor(t, const Duration(seconds: 4));
    await shot('pdf_viewer');
    await t.tap(find.byKey(const ValueKey('doc-back')));
    await pumpFor(t, const Duration(seconds: 1));

    // Publish is blocked until the organiser is verified
    await t.tap(find.byKey(const ValueKey('tournament-cta')));
    await pumpUntil(t, find.byKey(const ValueKey('publish-confirm')));
    await shot('publish_sheet');
    await t.tap(find.byKey(const ValueKey('publish-confirm')));
    await pumpUntil(t, find.byKey(const ValueKey('verify-now')));
    await shot('needs_verification');
    await t.tap(find.byKey(const ValueKey('verify-now')));

    // Verify identity
    await pumpUntil(t, find.text('Verify your identity'));
    await shot('verify_empty');
    await t.tap(find.text('PAN card'));
    await t.enterText(find.byKey(const ValueKey('verify-last4')), '4f7k');
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpFor(t, const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('verify-front')));
    await pumpUntil(t, find.text('Choose from gallery'));
    await t.tap(find.text('Choose from gallery'));
    await pumpUntil(t, find.text('Front of ID · Retake'));
    await t.drag(find.byType(ListView).last, const Offset(0, -500));
    await pumpFor(t, const Duration(milliseconds: 500));
    await t.tap(find.byKey(const ValueKey('verify-selfie')));
    await pumpUntil(t, find.text('Selfie · Retake'));
    await shot('verify_filled');
    await t.tap(find.byKey(const ValueKey('verify-submit')));
    await pumpUntil(t, find.text('Under review'), timeout: const Duration(seconds: 90));
    await shot('verify_pending');
    await pumpFor(t, const Duration(seconds: 5)); // let the snackbar finish before teardown
  });
}

/// Phase 2: the test user is verified on the server. Publish from My tournaments, then edit.
Future<void> _publishAndEdit(WidgetTester t, Future<void> Function(String) shot) async {
  await t.tap(find.text('Tournaments'));
  await pumpFor(t, const Duration(milliseconds: 500));
  await t.tap(find.text('My tournaments'));
  await pumpUntil(t, find.text('Junior Football Fiesta 2027'));
  await shot('my_tournaments');
  await t.tap(find.text('Junior Football Fiesta 2027'));
  await pumpUntil(t, find.text('Publish tournament'));
  await t.tap(find.byKey(const ValueKey('tournament-cta')));
  await pumpUntil(t, find.byKey(const ValueKey('publish-confirm')));
  await t.tap(find.byKey(const ValueKey('publish-confirm')));
  await pumpUntil(t, find.text('Waiting for approval'), timeout: const Duration(seconds: 60));
  await shot('published');

  // Edit opens on the review screen
  await t.tap(find.byKey(const ValueKey('tournament-edit')));
  await pumpUntil(t, find.text('Save changes'));
  await shot('edit_review');
  await t.tap(find.text('BASICS'));
  await pumpUntil(t, find.text('The basics'));
  await t.enterText(find.byKey(const ValueKey('t-name')), 'Junior Football Fiesta 2027 Edition 2');
  FocusManager.instance.primaryFocus?.unfocus();
  await t.tap(find.text('Review'));
  await pumpUntil(t, find.text('Save changes'));
  await t.tap(find.text('Save changes'));
  await pumpUntil(t, find.text('Junior Football Fiesta 2027 Edition 2'), timeout: const Duration(seconds: 60));
  await shot('edited');
  await t.tap(find.byKey(const ValueKey('tournament-back')));
  await pumpUntil(t, find.text('Junior Football Fiesta 2027 Edition 2'));
  await shot('my_tournaments_after');
  await pumpFor(t, const Duration(seconds: 5));
}
