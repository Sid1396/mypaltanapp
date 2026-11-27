import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/mixins/logger_mixin.dart';
import '../../data/models/home_models.dart';
import 'home_widgets.dart' show EmptyCard, TournamentCard;
import 'tournament_media_editors.dart' show SmallButtonLarge;
import 'tournament_form_widgets.dart';

/// Tournaments → All: every listed tournament (live, upcoming, completed) with sport and status filters, 20 at a time.
class AllTournamentsController extends GetxController with LoggerMixin {
  ApiService get _api => Get.find<ApiService>();

  final sport = 'ALL'.obs;
  final status = 'ALL'.obs; // ALL | LIVE | OPEN | DONE
  final items = <Map<String, dynamic>>[].obs;
  final featured = <FeaturedTournament>[].obs; // "Registrations open soon" leagues (first page, any status)
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final error = Rx<String?>(null);
  int? _next;
  int _seq = 0;

  bool get hasMore => _next != null;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void setFilters(String sport, String status) {
    if (sport == this.sport.value && status == this.status.value) return;
    this.sport.value = sport;
    this.status.value = status;
    load();
  }

  Future<void> load() async {
    final seq = ++_seq;
    isLoading.value = true;
    error.value = null;
    try {
      final res = await _api.getAllTournaments(sport: sport.value, status: status.value);
      if (seq != _seq) return;
      if (res['success'] == true) {
        items.assignAll((res['tournaments'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)));
        featured.assignAll((res['featured'] as List? ?? []).whereType<Map>().map((m) => FeaturedTournament.fromJson(Map<String, dynamic>.from(m))));
        _next = (res['next_offset'] as num?)?.toInt();
      } else {
        error.value = res['message']?.toString() ?? 'Could not load tournaments.';
      }
    } on ApiException catch (e) {
      if (seq == _seq) error.value = e.message;
      logError('All tournaments failed', e);
    } finally {
      if (seq == _seq) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    final from = _next;
    if (from == null || isLoadingMore.value || isLoading.value) return;
    final seq = _seq;
    isLoadingMore.value = true;
    try {
      final res = await _api.getAllTournaments(sport: sport.value, status: status.value, offset: from);
      if (seq != _seq || res['success'] != true) return;
      items.addAll((res['tournaments'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)));
      _next = (res['next_offset'] as num?)?.toInt();
    } on ApiException catch (e) {
      logError('All tournaments (more) failed', e);
    } finally {
      isLoadingMore.value = false;
    }
  }
}

const _statuses = [('ALL', 'Any status'), ('LIVE', '🔴 Live'), ('OPEN', 'Registration open'), ('DONE', 'Completed')];

/// The All tab's rows for the Tournaments page list (Filters button, cards, "Show more").
List<Widget> allTournaments(AllTournamentsController a) {
  final pad = EdgeInsets.symmetric(horizontal: SizeConfig.w(20));
  final count = (a.sport.value != 'ALL' ? 1 : 0) + (a.status.value != 'ALL' ? 1 : 0);
  final summary = [
    if (a.sport.value != 'ALL') Sports.all.firstWhereOrNull((s) => s.code == a.sport.value)?.label ?? a.sport.value,
    if (a.status.value != 'ALL') _statuses.firstWhere((x) => x.$1 == a.status.value).$2,
  ];
  return [
    Padding(
      padding: pad,
      child: Row(children: [
        Expanded(
          child: Text(summary.isEmpty ? 'All tournaments' : summary.join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(13.5, weight: FontWeight.w700, color: Colors.white.withAlpha(170))),
        ),
        GestureDetector(
          key: const ValueKey('all-filters'),
          onTap: () => _filters(a),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(8)),
            decoration: BoxDecoration(
              color: count > 0 ? AppColors.primary.withAlpha(40) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(SizeConfig.r(100)),
              border: Border.all(color: count > 0 ? AppColors.primary : Colors.white.withAlpha(25)),
            ),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: SizeConfig.r(16), color: Colors.white),
              SizedBox(width: SizeConfig.w(6)),
              Text(count > 0 ? 'Filters · $count' : 'Filters', style: tfStyle(13, weight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    ),
    gapH(14),
    if (a.isLoading.value && a.items.isEmpty)
      Padding(padding: EdgeInsets.only(top: SizeConfig.h(60)), child: const Center(child: CircularProgressIndicator(color: AppColors.primary)))
    else if (a.error.value != null && a.items.isEmpty)
      Padding(padding: pad, child: EmptyCard(icon: Icons.cloud_off_rounded, title: 'Could not load', message: a.error.value!))
    else if (a.items.isEmpty && a.featured.isEmpty)
      Padding(
        padding: pad,
        child: const EmptyCard(icon: Icons.emoji_events_rounded, title: 'No tournaments', message: 'No tournaments match these filters yet.'),
      )
    else ...[
      // Live and upcoming, then the leagues opening soon, then completed.
      for (final t in a.items.where((t) => t['stage'] != 'COMPLETED')) _cardRow(TournamentCard(t: _card(t))),
      for (final f in a.featured) _cardRow(TournamentCard(t: f)),
      for (final t in a.items.where((t) => t['stage'] == 'COMPLETED')) _cardRow(TournamentCard(t: _card(t))),
      if (a.hasMore)
        Center(
          child: TextButton(
            key: const ValueKey('all-more'),
            onPressed: a.isLoadingMore.value ? null : a.loadMore,
            child: Text(a.isLoadingMore.value ? 'Loading…' : 'Show more', style: tfStyle(14, weight: FontWeight.w800, color: AppColors.primary)),
          ),
        ),
    ],
  ];
}

void _filters(AllTournamentsController a) {
  final sport = a.sport.value.obs, status = a.status.value.obs;
  Widget group(String title, List<(String, String)> options, RxString value, String prefix) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tfStyle(12, weight: FontWeight.w900, color: Colors.white.withAlpha(150)).copyWith(letterSpacing: 1)),
          gapH(10),
          Wrap(spacing: SizeConfig.w(8), runSpacing: SizeConfig.h(8), children: [
            for (final (code, label) in options)
              GestureDetector(
                key: ValueKey('$prefix-$code'),
                onTap: () => value.value = code,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(8)),
                  decoration: BoxDecoration(
                    color: value.value == code ? AppColors.primary.withAlpha(40) : const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                    border: Border.all(color: value.value == code ? AppColors.primary : Colors.transparent),
                  ),
                  child: Text(label, style: tfStyle(13, weight: FontWeight.w700, color: value.value == code ? Colors.white : Colors.white.withAlpha(170))),
                ),
              ),
          ]),
        ],
      );
  Get.bottomSheet(
    Builder(
      builder: (sheet) => Obx(() => SheetFrame(title: 'Filters', children: [
            group('SPORT', [('ALL', 'All sports'), for (final s in Sports.all) (s.code, s.label)], sport, 'all-sport'),
            gapH(18),
            group('STATUS', _statuses, status, 'all-status'),
            gapH(22),
            Row(children: [
              TextButton(
                onPressed: () {
                  sport.value = 'ALL';
                  status.value = 'ALL';
                },
                child: Text('Clear', style: tfStyle(14, weight: FontWeight.w700, color: Colors.white.withAlpha(170))),
              ),
              SizedBox(width: SizeConfig.w(10)),
              Expanded(
                child: SmallButtonLarge(
                  key: const ValueKey('all-filters-apply'),
                  label: 'Show tournaments',
                  onTap: () {
                    Navigator.of(sheet).pop();
                    a.setFilters(sport.value, status.value);
                  },
                ),
              ),
            ]),
          ])),
    ),
    isScrollControlled: true,
  );
}

Widget _cardRow(Widget card) => Padding(padding: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), SizeConfig.h(14)), child: card);

/// The Upcoming tab's card for an All-tab row: same look, with format and team count as its tags.
FeaturedTournament _card(Map<String, dynamic> t) {
  final teams = (t['teams'] as num?)?.toInt() ?? 0;
  return FeaturedTournament.fromJson({
    ...t,
    'slug': t['code'],
    'tags': [
      if (t['format'] != null) t['format'],
      if (teams > 0) '$teams teams',
    ],
  });
}
