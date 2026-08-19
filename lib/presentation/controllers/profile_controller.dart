import 'package:get/get.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/providers/local_storage_provider.dart';
import '../../data/services/api_service.dart';
import '../../utils/mixins/logger_mixin.dart';

class ProfileController extends GetxController with LoggerMixin {
  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final profile = Rx<UserProfileModel?>(null);

  String get phone => Get.find<LocalStorageProvider>().readUserPhone() ?? '';

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await Get.find<ApiService>().getProfile();
      if (res['success'] == true && res['user'] != null) {
        profile.value = UserProfileModel.fromJson(res['user'] as Map<String, dynamic>);
      } else {
        errorMessage.value = res['message']?.toString() ?? 'Could not load profile';
      }
    } catch (e) {
      logError('Fetch profile failed', e);
      errorMessage.value = 'Check your connection and try again';
    } finally {
      isLoading.value = false;
    }
  }
}
