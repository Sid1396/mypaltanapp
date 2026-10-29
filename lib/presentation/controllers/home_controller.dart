import 'dart:async';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_routes.dart';
import '../../data/models/home_models.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/snackbar_helper.dart';
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

  // ─── Banner views and taps (shown to MyPaltan in the portal) ───

  final _seenBanners = <int>{};
  final _bannerViews = <int, int>{};
  final _bannerTaps = <int, int>{};
  Timer? _flushTimer;

  /// Counts one view per banner each time the app is opened.
  void bannerSeen(HomeBanner b) {
    if (b.id <= 0 || !_seenBanners.add(b.id)) return;
    _bannerViews[b.id] = (_bannerViews[b.id] ?? 0) + 1;
    _scheduleFlush();
  }

  Future<void> openBanner(HomeBanner b) async {
    final value = b.linkValue;
    if (b.linkType == 'NONE' || value == null || value.isEmpty) return;
    if (b.id > 0) _bannerTaps[b.id] = (_bannerTaps[b.id] ?? 0) + 1;
    _scheduleFlush(soon: true);
    if (b.linkType == 'URL') {
      final uri = Uri.tryParse(value);
      final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!ok) AppSnackbar.error('Link', "Couldn't open this link.");
    } else if (b.linkType == 'TOURNAMENT') {
      // Featured leagues are linked by slug, real tournaments by their 6-character code.
      final featured = tournamentBySlug(value);
      if (featured != null) {
        Get.toNamed(AppRoutes.tournamentDetail, arguments: featured);
      } else {
        Get.toNamed(AppRoutes.tournament, arguments: {'code': value});
      }
    }
  }

  void _scheduleFlush({bool soon = false}) {
    if (soon) _flushTimer?.cancel();
    if (_flushTimer?.isActive ?? false) return;
    _flushTimer = Timer(Duration(seconds: soon ? 2 : 10), _flushBanners);
  }

  void _flushBanners() {
    final ids = {..._bannerViews.keys, ..._bannerTaps.keys};
    if (ids.isEmpty) return;
    final events = [for (final id in ids) {'banner_id': id, 'views': _bannerViews[id] ?? 0, 'taps': _bannerTaps[id] ?? 0}];
    _bannerViews.clear();
    _bannerTaps.clear();
    Get.find<ApiService>().trackBanners(events).catchError((Object e) {
      logError('Banner tracking failed', e);
      return <String, dynamic>{};
    });
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    _flushBanners();
    super.onClose();
  }

  static List<Map<String, dynamic>> _list(dynamic v) =>
      (v is List ? v : const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}
