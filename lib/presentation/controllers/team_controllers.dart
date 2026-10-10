import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/sports.dart';
import '../../data/models/team.dart';
import '../../data/services/api_service.dart';
import '../../data/services/deep_link_service.dart';
import '../../utils/helpers/image_prep.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';
import '../widgets/tournament_form_widgets.dart';
import 'create_tournament_controller.dart' show UploadSlot, UploadedFile;

/// Uploads a square image (team logo or player photo) and returns its key, or null.
Future<UploadedFile?> uploadSquareImage(String kind, UploadSlot slot, {ImageSource source = ImageSource.gallery}) async {
  try {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 95);
    if (picked == null) return null;
    slot.busy.value = true;
    final path = await ImagePrep.toJpeg(picked.path, ImageShape.square);
    final res = await Get.find<ApiService>().uploadFile(kind, path, 'image/jpeg');
    if (res['success'] != true) {
      AppSnackbar.error('Upload failed', res['message']?.toString() ?? 'Please try again.');
      return null;
    }
    final file = UploadedFile(key: res['key'].toString(), url: res['url']?.toString(), localPath: path);
    slot.file.value = file;
    return file;
  } on ApiException catch (e) {
    AppSnackbar.error('Upload failed', e.message);
  } catch (e) {
    AppSnackbar.error('Image', e.toString().contains('denied') ? 'Allow photo access for MyPaltan in Settings.' : "Couldn't use that image. Try another one.");
  } finally {
    slot.busy.value = false;
  }
  return null;
}

// ─── Create / edit team ─────────────────────────────────────────

/// Arguments: none to create, or {'team': Team} to edit.
class TeamFormController extends GetxController {
  ApiService get _api => Get.find<ApiService>();

  Team? editing;
  bool get isEditing => editing != null;
  final sport = ''.obs;
  final nameCtrl = TextEditingController();
  final shortCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  final cityCtrl = TextEditingController(text: 'Mumbai');
  final logo = UploadSlot();
  final isSaving = false.obs;
  final _tick = 0.obs;
  bool _shortEdited = false;

  /// Creating only: true = I play (captain), false = I coach / manage and do not play.
  final playing = Rx<bool?>(null);

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    editing = args is Map ? args['team'] as Team? : null;
    final t = editing;
    if (t != null) {
      sport.value = t.sport;
      nameCtrl.text = t.name;
      shortCtrl.text = t.shortName;
      areaCtrl.text = t.area;
      cityCtrl.text = t.city;
      if (t.logoKey != null) logo.file.value = UploadedFile(key: t.logoKey!, url: t.logoUrl);
      _shortEdited = true;
    }
    nameCtrl.addListener(_suggestShort);
    for (final c in [nameCtrl, shortCtrl, areaCtrl, cityCtrl]) {
      c.addListener(() => _tick.value++);
    }
  }

  @override
  void onClose() {
    for (final c in [nameCtrl, shortCtrl, areaCtrl, cityCtrl]) {
      c.dispose();
    }
    super.onClose();
  }

  /// "Borivali Tigers FC" → "BTF" until the captain types their own short name.
  void _suggestShort() {
    if (_shortEdited) return;
    final words = nameCtrl.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final s = words.length == 1
        ? words.first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase()
        : words.map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')).where((w) => w.isNotEmpty).map((w) => w[0]).join().toUpperCase();
    final short = s.length > 4 ? s.substring(0, 4) : s;
    if (shortCtrl.text != short) shortCtrl.text = short;
  }

  void onShortTyped() => _shortEdited = true;

  Future<void> pickLogo() => uploadSquareImage('TEAM_LOGO', logo);

  String? validate() {
    _tick.value;
    if (sport.value.isEmpty) return 'Choose a sport.';
    if (!isEditing && playing.value == null) return 'Tell us if you play in this team or coach it.';
    final n = nameCtrl.text.trim();
    if (n.length < 2 || n.length > 40) return 'Team name must be 2-40 characters.';
    if (!RegExp(r'^[A-Za-z0-9]{2,4}$').hasMatch(shortCtrl.text.trim())) return 'Short name must be 2-4 letters or numbers.';
    if (logo.busy.value) return 'Wait for the logo to finish uploading.';
    if (!logo.isSet) return 'Add a team logo.';
    if (areaCtrl.text.trim().length < 2) return 'Enter the area your team is from.';
    if (cityCtrl.text.trim().length < 2) return 'Enter the city.';
    return null;
  }

  Future<void> save() async {
    final error = validate();
    if (error != null) return AppSnackbar.error('Check your details', error);
    isSaving.value = true;
    try {
      final res = await _api.saveTeam({
        if (isEditing) 'code': editing!.code,
        'sport': sport.value,
        'name': nameCtrl.text.trim(),
        'short_name': shortCtrl.text.trim().toUpperCase(),
        'logo_key': logo.file.value!.key,
        'area': areaCtrl.text.trim(),
        'city': cityCtrl.text.trim(),
        if (!isEditing) 'playing': playing.value,
      });
      if (res['success'] != true) {
        AppSnackbar.error('Could not save', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      if (isEditing) {
        Get.back(result: true);
        AppSnackbar.success('Saved', 'Team details updated.');
      } else {
        Get.offNamed(AppRoutes.team, arguments: {'code': res['code']});
        AppSnackbar.success('Team created', 'Share the team link so your players can join.');
      }
    } on ApiException catch (e) {
      AppSnackbar.error('Could not save', e.message);
    } finally {
      isSaving.value = false;
    }
  }
}

// ─── Team page ──────────────────────────────────────────────────

/// Arguments: {'code': 'ABC123'}.
class TeamController extends GetxController with LoggerMixin {
  ApiService get _api => Get.find<ApiService>();

  late final String code;
  final team = Rx<Team?>(null);
  final isLoading = true.obs;
  final isBusy = false.obs;
  final error = Rx<String?>(null);

  static String linkFor(String code) => 'https://${DeepLinkService.host}/team/$code';

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    code = (args is Map ? args['code'] as String? : null) ?? '';
    load();
  }

  Future<void> load() async {
    error.value = null;
    try {
      final res = await _api.getTeam(code);
      if (res['success'] == true && res['team'] is Map) {
        team.value = Team.fromJson(Map<String, dynamic>.from(res['team'] as Map));
      } else {
        error.value = res['message']?.toString() ?? 'Could not load this team.';
      }
    } on ApiException catch (e) {
      if (team.value == null) error.value = e.message;
      AppSnackbar.error('Team', e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> join() async {
    isBusy.value = true;
    try {
      final res = await _api.joinTeam(code);
      if (res['success'] == true) {
        AppSnackbar.success('Welcome!', res['message']?.toString() ?? 'You joined the team.');
        await load();
      } else {
        AppSnackbar.error('Could not join', res['message']?.toString() ?? 'Please try again.');
      }
    } on ApiException catch (e) {
      AppSnackbar.error('Could not join', e.message);
    } finally {
      isBusy.value = false;
    }
  }

  /// Runs a team action and reloads. Returns true when it worked.
  Future<bool> manage(Map<String, dynamic> body, {bool leaving = false}) async {
    isBusy.value = true;
    try {
      final res = await _api.manageTeam({'code': code, ...body});
      if (res['success'] != true) {
        AppSnackbar.error('Could not save', res['message']?.toString() ?? 'Please try again.');
        return false;
      }
      AppSnackbar.success('Done', res['message']?.toString() ?? 'Saved.');
      if (leaving) {
        Get.back(result: 'left');
      } else {
        await load();
      }
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Could not save', e.message);
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> edit() async {
    final t = team.value;
    if (t == null) return;
    final changed = await Get.toNamed(AppRoutes.teamForm, arguments: {'team': t});
    if (changed == true) load();
  }

  void confirm(String title, String body, String action, VoidCallback onYes, {bool danger = false}) {
    Get.dialog(AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(18))),
      title: Text(title, style: tfStyle(18, weight: FontWeight.w800)),
      content: Text(body, style: tfStyle(13.5, color: Colors.white.withAlpha(180), height: 1.45)),
      actions: [
        TextButton(onPressed: Get.back, child: Text('Cancel', style: tfStyle(14, color: Colors.white.withAlpha(180)))),
        TextButton(
          onPressed: () {
            Get.back();
            onYes();
          },
          child: Text(action, style: tfStyle(14, weight: FontWeight.w700, color: danger ? AppColors.negative : AppColors.primary)),
        ),
      ],
    ));
  }

  // ─── Sharing the team link ────────────────────────────────────

  String shareMessage(Team t) {
    final sport = Sports.byCode(t.sport)?.label ?? t.sport;
    return '🛡️ Join *${t.name}* on MyPaltan\n$sport · ${t.location}\n\nTap to join the team 👇\n${linkFor(t.code)}';
  }

  Future<void> shareWhatsApp() async {
    final t = team.value;
    if (t == null) return;
    final text = Uri.encodeComponent(shareMessage(t));
    final opened = await launchUrl(Uri.parse('whatsapp://send?text=$text'), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened) await SharePlus.instance.share(ShareParams(text: shareMessage(t), subject: t.name));
  }

  Future<void> shareMore() async {
    final t = team.value;
    if (t != null) await SharePlus.instance.share(ShareParams(text: shareMessage(t), subject: t.name));
  }
}

// ─── My Teams tab ───────────────────────────────────────────────

class MyTeamsController extends GetxController {
  ApiService get _api => Get.find<ApiService>();

  final items = <MyTeam>[].obs;
  final isLoading = false.obs;
  final loaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final res = await _api.getMyTeams();
      if (res['success'] == true) {
        items.assignAll((res['teams'] as List? ?? []).whereType<Map>().map((m) => MyTeam.fromJson(Map<String, dynamic>.from(m))));
        loaded.value = true;
      }
    } on ApiException catch (e) {
      AppSnackbar.error('My teams', e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> open(String code) async {
    await Get.toNamed(AppRoutes.team, arguments: {'code': code});
    load();
  }

  Future<void> create() async {
    await Get.toNamed(AppRoutes.teamForm);
    load();
  }
}
