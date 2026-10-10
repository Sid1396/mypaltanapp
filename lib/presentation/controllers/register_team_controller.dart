import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_routes.dart';
import '../../data/models/entry.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/image_prep.dart';
import '../../utils/helpers/snackbar_helper.dart';
import 'create_tournament_controller.dart' show UploadSlot, UploadedFile;

enum RegStep { team, division, squad, payment }

/// Registers one of the user's teams for a tournament. Arguments: {'code': 'ABC123'}. Returns true when registered.
class RegisterTeamController extends GetxController {
  ApiService get _api => Get.find<ApiService>();

  late final String code;
  final options = Rx<RegOptions?>(null);
  final isLoading = true.obs;
  final error = Rx<String?>(null);
  final isSubmitting = false.obs;

  final step = 0.obs;
  final teamCode = ''.obs;
  final divisionId = 0.obs;
  final picked = <int>{}.obs; // team_members ids
  final method = 'UPI'.obs;
  final utrCtrl = TextEditingController();
  final proof = UploadSlot();
  final _tick = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    code = (args is Map ? args['code'] as String? : null) ?? '';
    utrCtrl.addListener(() => _tick.value++);
    load();
  }

  @override
  void onClose() {
    utrCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    error.value = null;
    try {
      final res = await _api.getRegistrationOptions(code);
      if (res['success'] != true) {
        error.value = res['message']?.toString() ?? 'Could not load registration.';
        return;
      }
      final o = RegOptions.fromJson(res);
      options.value = o;
      // Pre-select when there is only one choice.
      final free = o.teams.where((t) => entryFor(t.code) == null).toList();
      if (teamCode.value.isEmpty && free.length == 1) teamCode.value = free.first.code;
      if (divisionId.value == 0 && o.divisions.length == 1) divisionId.value = o.divisions.first.id;
      if (o.payment != null && !o.payment!.acceptCash) method.value = 'UPI';
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Derived state ────────────────────────────────────────────

  MyEntry? entryFor(String teamCode) => options.value?.myEntries.firstWhereOrNull((e) => e.teamCode == teamCode && e.isActive);

  RegTeam? get team => options.value?.teams.firstWhereOrNull((t) => t.code == teamCode.value);
  RegDivision? get division => options.value?.divisions.firstWhereOrNull((d) => d.id == divisionId.value);
  int get fee => division?.entryFee ?? 0;
  bool get needsPayment => fee > 0;

  List<RegStep> get steps => [RegStep.team, RegStep.division, RegStep.squad, if (needsPayment) RegStep.payment];
  RegStep get current => steps[step.value.clamp(0, steps.length - 1)];
  bool get isLast => step.value >= steps.length - 1;

  /// Why this player can't be picked for the chosen division, or null.
  String? blockedReason(RegPlayer p) => squadBlockReason(p, division, options.value!, teamCode.value);

  void selectTeam(String code) {
    if (teamCode.value == code) return;
    teamCode.value = code;
    picked.clear();
  }

  void selectDivision(int id) {
    if (divisionId.value == id) return;
    divisionId.value = id;
    // Drop players who no longer fit the age limits.
    final t = team;
    if (t != null) picked.removeWhere((m) => t.players.any((p) => p.memberId == m && blockedReason(p) != null));
  }

  void togglePlayer(RegPlayer p) {
    final reason = blockedReason(p);
    if (reason != null) return AppSnackbar.warning(p.name, reason);
    if (picked.contains(p.memberId)) {
      picked.remove(p.memberId);
    } else {
      final max = division?.squadMax ?? 99;
      if (picked.length >= max) return AppSnackbar.warning('Squad full', 'This division allows up to $max players.');
      picked.add(p.memberId);
    }
  }

  String? validateStep(RegStep s) {
    _tick.value;
    switch (s) {
      case RegStep.team:
        if (team == null) return 'Choose the team you are registering.';
        final e = entryFor(teamCode.value);
        if (e != null) return '${e.teamName} is already registered.';
        return null;
      case RegStep.division:
        if (division == null) return 'Choose a division.';
        return null;
      case RegStep.squad:
        // Players can also join later through the squad link, so only the maximum applies now.
        final d = division!;
        if (picked.length > d.squadMax) return 'Pick at most ${d.squadMax} players.';
        return null;
      case RegStep.payment:
        if (method.value == 'CASH') return null;
        if (proof.busy.value) return 'Wait for the screenshot to finish uploading.';
        final utr = utrCtrl.text.replaceAll(' ', '');
        if (utr.isEmpty && !proof.isSet) return 'Enter the UTR number or add a payment screenshot.';
        if (utr.isNotEmpty && !RegExp(r'^[A-Za-z0-9]{6,30}$').hasMatch(utr)) return 'The UTR is the 12-digit number in your UPI app\'s payment details.';
        return null;
    }
  }

  void next() {
    final err = validateStep(current);
    if (err != null) return AppSnackbar.error('Check this step', err);
    if (isLast) {
      submit();
    } else {
      step.value++;
    }
  }

  void back() {
    if (step.value == 0) {
      Get.back();
    } else {
      step.value--;
    }
  }

  // ─── Payment ──────────────────────────────────────────────────

  String get payNote => 'MyPaltan $code ${team?.name ?? ''}'.trim();

  Future<void> payWithUpiApp() async {
    final p = options.value?.payment;
    if (p == null) return;
    final uri = Uri(scheme: 'upi', host: 'pay', queryParameters: {
      'pa': p.upiId,
      'pn': p.upiName,
      'am': fee.toString(),
      'cu': 'INR',
      'tn': payNote.length > 40 ? payNote.substring(0, 40) : payNote,
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened) AppSnackbar.info('No UPI app found', 'Copy the UPI ID and pay from any UPI app.');
  }

  void copyUpi() {
    final p = options.value?.payment;
    if (p == null) return;
    Clipboard.setData(ClipboardData(text: p.upiId));
    AppSnackbar.success('Copied', p.upiId);
  }

  Future<void> pickProof() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400, imageQuality: 95);
      if (x == null) return;
      proof.busy.value = true;
      final path = await ImagePrep.toJpeg(x.path, ImageShape.original);
      final res = await _api.uploadFile('PAYMENT_PROOF', path, 'image/jpeg');
      if (res['success'] != true) {
        AppSnackbar.error('Upload failed', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      proof.file.value = UploadedFile(key: res['key'].toString(), url: res['url']?.toString(), localPath: path);
    } on ApiException catch (e) {
      AppSnackbar.error('Upload failed', e.message);
    } catch (e) {
      AppSnackbar.error('Image', e.toString().contains('denied') ? 'Allow photo access for MyPaltan in Settings.' : "Couldn't use that image. Try another one.");
    } finally {
      proof.busy.value = false;
    }
  }

  // ─── Submit ───────────────────────────────────────────────────

  Future<void> createTeam() async {
    await Get.toNamed(AppRoutes.teamForm);
    isLoading.value = true;
    await load();
  }

  Future<void> submit() async {
    isSubmitting.value = true;
    try {
      final res = await _api.registerTeam({
        'tournament_code': code,
        'team_code': teamCode.value,
        'division_id': divisionId.value,
        'member_ids': picked.toList(),
        'payment_method': needsPayment ? method.value : 'NONE',
        if (needsPayment && method.value == 'UPI' && utrCtrl.text.trim().isNotEmpty) 'utr': utrCtrl.text.replaceAll(' ', ''),
        if (needsPayment && method.value == 'UPI' && proof.isSet) 'proof_key': proof.file.value!.key,
      });
      if (res['success'] != true) {
        AppSnackbar.error('Could not register', res['message']?.toString() ?? 'Please try again.');
        if (res['message']?.toString().contains('Refresh') == true) load();
        return;
      }
      Get.back(result: {'team_code': teamCode.value, 'team_name': team?.name ?? '', 'division': division?.name});
      AppSnackbar.success(res['status'] == 'WAITLISTED' ? 'On the waitlist' : 'Registered', res['message']?.toString() ?? 'The organiser will confirm your team.');
    } on ApiException catch (e) {
      AppSnackbar.error('Could not register', e.message);
    } finally {
      isSubmitting.value = false;
    }
  }
}
