import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../models/app_user.dart';
import '../providers/local_storage_provider.dart';
import 'api_service.dart';

/// Holds the logged-in user and decides where the app should go after login or launch.
class SessionService extends GetxService {
  final user = Rx<AppUser?>(null);
  final missing = <String>[].obs;

  LocalStorageProvider get _store => Get.find<LocalStorageProvider>();
  ApiService get _api => Get.find<ApiService>();

  bool get isLoggedIn => (_store.readJwtToken() ?? '').isNotEmpty;
  bool get needsOnboarding => missing.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    _api.onUnauthorized = () => logout(expired: true);
  }

  void saveLogin(String token, String phone) {
    _store.writeJwtToken(token);
    _store.writeUserPhone(phone);
  }

  /// Applies any server response that carries `profile` and `missing`.
  void applyProfileResponse(Map<String, dynamic> res) {
    final p = res['profile'];
    if (p is Map) user.value = AppUser.fromJson(Map<String, dynamic>.from(p));
    final m = res['missing'];
    if (m is List) missing.assignAll(m.map((e) => e.toString()));
  }

  /// Loads the profile for a saved login. Returns the route to open, or null if the login is no longer valid.
  Future<String?> resumeSession() async {
    if (!isLoggedIn) return null;
    final res = await _api.getProfile();
    if (res['success'] != true) {
      _store.clearJwtToken();
      return null;
    }
    applyProfileResponse(res);
    return needsOnboarding ? AppRoutes.onboarding : AppRoutes.home;
  }

  void logout({bool expired = false}) {
    if (!isLoggedIn && user.value == null) return;
    _store.clearJwtToken();
    _store.clearUserPhone();
    user.value = null;
    missing.clear();
    Get.offAllNamed(AppRoutes.login);
    if (expired) AppSnackbar.warning('Session expired', 'Please log in again.');
  }
}
