import 'package:get/get.dart';
import '../../data/models/home_models.dart';
import '../../data/services/api_service.dart';
import 'home_controller.dart';

class NotificationsController extends GetxController {
  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final items = <AppNotification>[].obs;

  ApiService get _api => Get.find<ApiService>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await _api.getNotifications();
      if (res['success'] != true) {
        errorMessage.value = res['message']?.toString() ?? 'Could not load notifications.';
        return;
      }
      items.assignAll(((res['notifications'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => AppNotification.fromJson(Map<String, dynamic>.from(m))));
      if (items.any((n) => !n.isRead)) _markAllRead();
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markNotificationsRead();
      if (Get.isRegistered<HomeController>()) Get.find<HomeController>().unreadNotifications.value = 0;
    } on ApiException {
      // Not critical; they'll be marked next time.
    }
  }
}
