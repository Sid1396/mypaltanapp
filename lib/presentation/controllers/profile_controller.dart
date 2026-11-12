import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../data/models/app_user.dart';
import '../../data/services/api_service.dart';
import '../../data/services/session_service.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';

class ProfileController extends GetxController with LoggerMixin {
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  SessionService get _session => Get.find<SessionService>();
  Rx<AppUser?> get user => _session.user;

  @override
  void onInit() {
    super.onInit();
    if (user.value == null) fetchProfile();
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await Get.find<ApiService>().getProfile();
      if (res['success'] == true) {
        _session.applyProfileResponse(res);
      } else {
        errorMessage.value = res['message']?.toString() ?? 'Could not load your profile.';
      }
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// Opens one onboarding section in edit mode, then refreshes (photo links expire after a day).
  Future<void> edit(String section) async {
    await Get.toNamed(AppRoutes.onboarding, arguments: {'edit': section});
  }

  void logout() => _session.logout();

  final deleting = false.obs;

  Future<void> openPrivacy() async {
    if (!await launchUrl(Uri.parse('https://mypaltan.com/privacy'), mode: LaunchMode.externalApplication).catchError((_) => false)) {
      AppSnackbar.info('Privacy policy', 'mypaltan.com/privacy');
    }
  }

  /// Asks for confirmation, then deletes the account on the server and logs out.
  Future<void> deleteAccount() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Delete your account?', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, color: Colors.white)),
        content: const Text(
          'Your name, photo, date of birth, jersey details, sports and ID check are deleted straight away, and you are logged out. '
          'Teams and tournaments you run stay for the other players but show "Deleted user". This cannot be undone.',
          style: TextStyle(fontFamily: 'Gilroy', color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          TextButton(
            key: const ValueKey('delete-account-confirm'),
            onPressed: () => Get.back(result: true),
            child: const Text('Delete account', style: TextStyle(color: AppColors.negative, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || deleting.value) return;
    deleting.value = true;
    try {
      final res = await Get.find<ApiService>().deleteAccount();
      if (res['success'] == true) {
        AppSnackbar.success('Account deleted', res['message']?.toString() ?? 'Your account has been deleted.');
        _session.logout();
      } else {
        AppSnackbar.error('Could not delete', res['message']?.toString() ?? 'Please try again.');
      }
    } on ApiException catch (e) {
      AppSnackbar.error('Could not delete', e.message);
    } finally {
      deleting.value = false;
    }
  }
}
