import 'package:get/get.dart';
import '../../data/models/home_models.dart';
import '../../data/services/api_service.dart';
import '../../utils/mixins/logger_mixin.dart';

/// Feeds the Home and Tournaments tabs from `GET v2/home`.
class HomeController extends GetxController with LoggerMixin {
  final isLoading = true.obs;
  final errorMessage = ''.obs;
  final banners = <HomeBanner>[].obs;
  final tournaments = <FeaturedTournament>[].obs;
  final unreadNotifications = 0.obs;

  // Filled once teams, tournaments and matches exist on the server.
  final liveMatches = <Map<String, dynamic>>[].obs;
  final myTeams = <Map<String, dynamic>>[].obs;
  final myTournaments = <Map<String, dynamic>>[].obs;
  final nextMatch = Rx<Map<String, dynamic>?>(null);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (banners.isEmpty && tournaments.isEmpty) isLoading.value = true;
    errorMessage.value = '';
    try {
      final res = await Get.find<ApiService>().getHome();
      if (res['success'] != true) {
        errorMessage.value = res['message']?.toString() ?? 'Could not load home.';
        return;
      }
      banners.assignAll(_list(res['banners']).map(HomeBanner.fromJson));
      tournaments.assignAll(_list(res['featured_tournaments']).map(FeaturedTournament.fromJson));
      unreadNotifications.value = (res['unread_notifications'] as num?)?.toInt() ?? 0;
      liveMatches.assignAll(_list(res['live_matches']));
      myTeams.assignAll(_list(res['my_teams']));
      myTournaments.assignAll(_list(res['my_tournaments']));
      nextMatch.value = res['next_match'] is Map ? Map<String, dynamic>.from(res['next_match'] as Map) : null;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  FeaturedTournament? tournamentBySlug(String? slug) => tournaments.firstWhereOrNull((t) => t.slug == slug);

  static List<Map<String, dynamic>> _list(dynamic v) =>
      (v is List ? v : const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}
