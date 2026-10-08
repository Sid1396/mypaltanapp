import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../data/models/app_user.dart';
import '../../data/services/api_service.dart';
import '../../data/services/session_service.dart';
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
}
