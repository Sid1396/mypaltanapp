import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../data/models/tournament.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/snackbar_helper.dart';

/// Tournaments the user organises (later also plays in or scores).
class MyTournamentsController extends GetxController {
  ApiService get _api => Get.find<ApiService>();

  final items = <MyTournament>[].obs;
  final isLoading = false.obs;
  final loaded = false.obs;

  Future<void> load() async {
    isLoading.value = true;
    try {
      final res = await _api.getMyTournaments();
      if (res['success'] == true) {
        items.assignAll((res['tournaments'] as List? ?? [])
            .whereType<Map>()
            .map((m) => MyTournament.fromJson(Map<String, dynamic>.from(m))));
        loaded.value = true;
      }
    } on ApiException catch (e) {
      AppSnackbar.error('My tournaments', e.message);
    } finally {
      isLoading.value = false;
    }
  }

  void ensureLoaded() {
    if (!loaded.value && !isLoading.value) load();
  }

  Future<void> open(String code) async {
    await Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
    load();
  }

  Future<void> create() async {
    await Get.toNamed(AppRoutes.createTournament);
    load();
  }
}
