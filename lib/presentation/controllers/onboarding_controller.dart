import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/sports.dart';
import '../../data/models/app_user.dart';
import '../../data/services/api_service.dart';
import '../../data/services/session_service.dart';
import '../../utils/helpers/image_prep.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';

/// Editable selection for one sport while onboarding.
class SportDraft {
  String? role;
  String? battingHand;
  String? bowlingStyle;

  SportDraft({this.role, this.battingHand, this.bowlingStyle});

  bool isCompleteFor(String sport) =>
      role != null && (sport != 'CRICKET' || (battingHand != null && bowlingStyle != null));
}

/// Drives both first-time signup (only the missing steps) and later edits of a single section.
/// Steps: about, jersey, sports, photo, done.
class OnboardingController extends GetxController with LoggerMixin {
  late final PageController pageController;
  final nameController = TextEditingController();
  final jerseyNameController = TextEditingController();
  final jerseyNumberController = TextEditingController();

  final steps = <String>[].obs;
  final _index = 0.obs;
  final birthdate = Rx<DateTime?>(null);
  final gender = ''.obs;
  final name = ''.obs;
  final jerseyName = ''.obs;
  final jerseyNumber = ''.obs;
  final jerseySize = ''.obs;
  final sportOrder = <String>[].obs;
  final sportDrafts = <String, SportDraft>{}.obs;
  final photoPath = Rx<String?>(null);
  final existingPhotoUrl = Rx<String?>(null);
  final isSaving = false.obs;
  final isPreparingPhoto = false.obs;

  /// Section being edited from the profile, or null during signup.
  String? editSection;

  bool get isEditing => editSection != null;
  int get index => _index.value;
  String get currentStep => steps.isEmpty ? 'done' : steps[_index.value];
  int get dataStepCount => steps.where((s) => s != 'done').length;

  SessionService get _session => Get.find<SessionService>();
  ApiService get _api => Get.find<ApiService>();
  final _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
    nameController.addListener(() => name.value = nameController.text);
    jerseyNameController.addListener(() => jerseyName.value = jerseyNameController.text);
    jerseyNumberController.addListener(() => jerseyNumber.value = jerseyNumberController.text);

    final args = Get.arguments;
    editSection = args is Map ? args['edit'] as String? : null;
    if (isEditing) {
      steps.assignAll([editSection!]);
    } else {
      const order = ['about', 'jersey', 'sports', 'photo'];
      final missing = _session.missing;
      steps.assignAll([...order.where(missing.contains), 'done']);
    }
    _prefill(_session.user.value);
  }

  void _prefill(AppUser? u) {
    if (u == null) return;
    nameController.text = u.name ?? '';
    birthdate.value = u.birthdate;
    gender.value = u.gender ?? '';
    jerseyNameController.text = u.jerseyName ?? '';
    jerseyNumberController.text = u.jerseyNumber?.toString() ?? '';
    jerseySize.value = u.jerseySize ?? '';
    existingPhotoUrl.value = u.photoUrl;
    for (final s in u.sports) {
      sportOrder.add(s.sport);
      sportDrafts[s.sport] = SportDraft(role: s.role, battingHand: s.battingHand, bowlingStyle: s.bowlingStyle);
    }
  }

  @override
  void onClose() {
    pageController.dispose();
    nameController.dispose();
    jerseyNameController.dispose();
    jerseyNumberController.dispose();
    super.onClose();
  }

  // ─── Navigation ───────────────────────────────────────────────

  void _goTo(int i) {
    FocusManager.instance.primaryFocus?.unfocus();
    _index.value = i;
    if (steps[i] == 'done') return; // shown outside the pager
    pageController.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  void back() {
    if (isSaving.value) return;
    if (isEditing) return Get.back();
    if (_index.value > 0 && currentStep != 'done') return _goTo(_index.value - 1);
    _confirmLeave();
  }

  void _confirmLeave() {
    Get.dialog(AlertDialog(
      backgroundColor: AppColors.darkSurface,
      title: const Text('Leave signup?', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, color: Colors.white)),
      content: Text(
        "You'll need to log in again to finish your profile.",
        style: TextStyle(fontFamily: 'Gilroy', color: Colors.white.withAlpha(180)),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Stay', style: TextStyle(color: Colors.white))),
        TextButton(
          onPressed: () {
            Get.back();
            _session.logout();
          },
          child: const Text('Log out', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    ));
  }

  /// Continue button for the current step.
  Future<void> next() async {
    final step = currentStep;
    final error = validate(step);
    if (error != null) return AppSnackbar.error('Check your details', error);

    if (isEditing) return _saveEdit(step);

    if (step == 'photo') return _uploadPhoto();

    // Save all profile fields once the last data step before the photo is done.
    final nextStep = steps[_index.value + 1];
    if (nextStep == 'photo' || nextStep == 'done') {
      final ok = await _saveProfile();
      if (!ok) return;
    }
    _goTo(_index.value + 1);
  }

  void onEnterJerseyStep() {
    if (jerseyNameController.text.trim().isEmpty && name.value.trim().isNotEmpty) {
      jerseyNameController.text = name.value.trim().split(' ').first.toUpperCase();
    }
  }

  void finish() => Get.offAllNamed(AppRoutes.home);

  // ─── Validation (mirrors the server rules) ───────────────────

  String? validate(String step) {
    switch (step) {
      case 'about':
        final n = name.value.trim();
        if (n.length < 2 || n.length > 50 || !RegExp(r"^[A-Za-z][A-Za-z .'-]*$").hasMatch(n)) {
          return 'Enter your full name (2-50 letters).';
        }
        if (birthdate.value == null) return 'Select your date of birth.';
        if (ageOf(birthdate.value!) < 13) return 'You must be 13 or older to use MyPaltan.';
        if (gender.value.isEmpty) return 'Choose a gender option.';
        return null;
      case 'jersey':
        final j = jerseyName.value.trim();
        if (j.length < 2 || j.length > 12 || !RegExp(r'^[A-Za-z][A-Za-z ]*$').hasMatch(j)) {
          return 'Jersey name must be 2-12 letters.';
        }
        final num = int.tryParse(jerseyNumber.value);
        if (num == null || num < 0 || num > 99) return 'Jersey number must be between 0 and 99.';
        if (jerseySize.value.isEmpty) return 'Choose a jersey size.';
        return null;
      case 'sports':
        if (sportOrder.isEmpty) return 'Choose at least one sport.';
        for (final s in sportOrder) {
          final d = sportDrafts[s]!;
          if (d.role == null) return 'Choose your role for ${Sports.byCode(s)!.label.toLowerCase()}.';
          if (!d.isCompleteFor(s)) return 'Choose your batting hand and bowling style.';
        }
        return null;
      case 'photo':
        if (photoPath.value == null) return 'Add your photo to continue.';
        return null;
    }
    return null;
  }

  bool isStepValid(String step) => validate(step) == null;

  static int ageOf(DateTime d) {
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a;
  }

  // ─── Field helpers ────────────────────────────────────────────

  Future<void> pickBirthdate(BuildContext context) async {
    final now = DateTime.now();
    final latest = DateTime(now.year - 13, now.month, now.day);
    final result = await showDatePicker(
      context: context,
      initialDate: birthdate.value ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1920),
      lastDate: latest,
      helpText: 'Date of birth',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.darkSurface,
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppColors.darkSurface),
        ),
        child: child!,
      ),
    );
    if (result != null) birthdate.value = result;
  }

  void toggleSport(String code) {
    if (sportOrder.contains(code)) {
      sportOrder.remove(code);
      sportDrafts.remove(code);
    } else {
      sportOrder.add(code);
      sportDrafts[code] = SportDraft();
    }
  }

  void setSportField(String sport, {String? role, String? battingHand, String? bowlingStyle}) {
    final d = sportDrafts[sport];
    if (d == null) return;
    if (role != null) d.role = role;
    if (battingHand != null) d.battingHand = battingHand;
    if (bowlingStyle != null) d.bowlingStyle = bowlingStyle;
    sportDrafts.refresh();
  }

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1400, maxHeight: 1400, imageQuality: 92);
      if (picked == null) return;
      isPreparingPhoto.value = true;
      photoPath.value = await ImagePrep.toJpeg(picked.path, ImageShape.square);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('access_denied') || msg.contains('denied')) {
        AppSnackbar.warning(
          'Permission needed',
          'Allow ${source == ImageSource.camera ? 'camera' : 'photo'} access for MyPaltan in Settings.',
        );
      } else {
        logError('Photo pick failed', e);
        AppSnackbar.error('Photo', "Couldn't use that photo. Try another one.");
      }
    } finally {
      isPreparingPhoto.value = false;
    }
  }

  // ─── Server calls ─────────────────────────────────────────────

  String _dob(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _sportsPayload() => sportOrder.map((s) {
        final d = sportDrafts[s]!;
        return SportRole(
          sport: s,
          role: d.role!,
          battingHand: s == 'CRICKET' ? d.battingHand : null,
          bowlingStyle: s == 'CRICKET' ? d.bowlingStyle : null,
        ).toJson();
      }).toList();

  Map<String, dynamic> _fieldsFor(String step) {
    switch (step) {
      case 'about':
        return {'name': name.value.trim(), 'birthdate': _dob(birthdate.value!), 'gender': gender.value};
      case 'jersey':
        return {
          'jersey_name': jerseyName.value.trim().toUpperCase(),
          'jersey_number': int.parse(jerseyNumber.value),
          'jersey_size': jerseySize.value,
        };
      case 'sports':
        return {'sports': _sportsPayload()};
    }
    return {};
  }

  Future<bool> _saveProfile() async {
    isSaving.value = true;
    try {
      final res = await _api.completeProfile({
        ..._fieldsFor('about'),
        ..._fieldsFor('jersey'),
        ..._fieldsFor('sports'),
      });
      if (res['success'] != true) {
        AppSnackbar.error('Could not save', res['message']?.toString() ?? 'Please try again.');
        return false;
      }
      _session.applyProfileResponse(res);
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error('Could not save', e.message);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _uploadPhoto() async {
    isSaving.value = true;
    try {
      final res = await _api.uploadPhoto(photoPath.value!);
      if (res['success'] != true) {
        AppSnackbar.error('Upload failed', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      _session.applyProfileResponse(res);
      if (isEditing) {
        Get.back();
        AppSnackbar.success('Photo updated', 'Your new photo is saved.');
      } else {
        _goTo(_index.value + 1);
      }
    } on ApiException catch (e) {
      AppSnackbar.error('Upload failed', e.message);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _saveEdit(String step) async {
    if (step == 'photo') return _uploadPhoto();
    isSaving.value = true;
    try {
      final res = await _api.updateProfile(_fieldsFor(step));
      if (res['success'] != true) {
        AppSnackbar.error('Could not save', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      _session.applyProfileResponse(res);
      Get.back();
      AppSnackbar.success('Saved', 'Your profile is updated.');
    } on ApiException catch (e) {
      AppSnackbar.error('Could not save', e.message);
    } finally {
      isSaving.value = false;
    }
  }
}
