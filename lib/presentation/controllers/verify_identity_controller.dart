import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/tournament.dart';
import '../../data/services/api_service.dart';
import '../../data/services/session_service.dart';
import '../../utils/helpers/image_prep.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';

/// One-time ID + selfie check for organisers and captains. Reviewed by the MyPaltan team.
class VerifyIdentityController extends GetxController with LoggerMixin {
  ApiService get _api => Get.find<ApiService>();
  final _picker = ImagePicker();

  final status = Rx<VerificationStatus?>(null);
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final preparing = ''.obs; // which photo is being prepared

  final idType = ''.obs;
  final last4Ctrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final front = Rx<String?>(null);
  final back = Rx<String?>(null);
  final selfie = Rx<String?>(null);
  final _tick = 0.obs;

  bool get needsBack => idType.value != 'PASSPORT' && idType.value != 'PAN';

  @override
  void onInit() {
    super.onInit();
    nameCtrl.text = Get.find<SessionService>().user.value?.name ?? '';
    for (final c in [last4Ctrl, nameCtrl]) {
      c.addListener(() => _tick.value++);
    }
    load();
  }

  @override
  void onClose() {
    last4Ctrl.dispose();
    nameCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    try {
      final res = await _api.getVerificationStatus();
      if (res['success'] == true) status.value = VerificationStatus.fromJson(res);
    } on ApiException catch (e) {
      AppSnackbar.error('Verification', e.message);
    } finally {
      isLoading.value = false;
    }
  }

  /// Selfies must come from the camera. The simulator has no camera, so debug builds fall back to the gallery.
  Future<void> pick(String part, ImageSource source) async {
    try {
      final isSelfie = part == 'selfie';
      final picked = await _picker.pickImage(
        source: source,
        preferredCameraDevice: isSelfie ? CameraDevice.front : CameraDevice.rear,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
      );
      if (picked == null) return;
      preparing.value = part;
      final path = await ImagePrep.toJpeg(picked.path, ImageShape.original);
      switch (part) {
        case 'front':
          front.value = path;
        case 'back':
          back.value = path;
        default:
          selfie.value = path;
      }
    } catch (e) {
      final msg = e.toString();
      if (source == ImageSource.camera && kDebugMode && msg.contains('camera')) {
        return pick(part, ImageSource.gallery);
      }
      if (msg.contains('denied')) {
        AppSnackbar.warning('Permission needed', 'Allow ${source == ImageSource.camera ? 'camera' : 'photo'} access for MyPaltan in Settings.');
      } else {
        logError('ID photo pick failed', e);
        AppSnackbar.error('Photo', "Couldn't use that photo. Try again.");
      }
    } finally {
      preparing.value = '';
    }
  }

  String? validate() {
    _tick.value;
    if (idType.value.isEmpty) return 'Choose an ID type.';
    if (!RegExp(r'^[A-Za-z0-9]{4}$').hasMatch(last4Ctrl.text.trim())) return 'Enter the last 4 characters of your ID number.';
    final n = nameCtrl.text.trim();
    if (n.length < 2 || n.length > 100) return 'Enter your name exactly as on the ID.';
    if (front.value == null) return 'Add a photo of the front of your ID.';
    if (needsBack && back.value == null) return 'Add a photo of the back of your ID.';
    if (selfie.value == null) return 'Take a selfie.';
    return null;
  }

  Future<void> submit() async {
    final error = validate();
    if (error != null) return AppSnackbar.error('Check your details', error);
    isSubmitting.value = true;
    try {
      final res = await _api.submitVerification(
        idType: idType.value,
        idLast4: last4Ctrl.text.trim().toUpperCase(),
        nameOnId: nameCtrl.text.trim(),
        frontPath: front.value!,
        backPath: needsBack ? back.value : null,
        selfiePath: selfie.value!,
      );
      if (res['success'] != true) {
        AppSnackbar.error('Could not submit', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      AppSnackbar.success('Submitted', res['message']?.toString() ?? 'We will review your ID within 24 hours.');
      await load();
    } on ApiException catch (e) {
      AppSnackbar.error('Could not submit', e.message);
    } finally {
      isSubmitting.value = false;
    }
  }
}
