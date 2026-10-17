import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../data/models/match.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../widgets/form_widgets.dart';
import '../widgets/tournament_form_widgets.dart';
import '../widgets/tournament_media_editors.dart' show SmallButtonLarge;

/// A match for everyone: live score, scorecard and commentary. Arguments: {'id': matchId}.
class MatchController extends GetxController {
  ApiService get _api => Get.find<ApiService>();

  late final int id;
  final match = Rx<MatchDetail?>(null);
  final isLoading = true.obs;
  final error = Rx<String?>(null);
  final tab = 0.obs; // 0 live, 1 scorecard, 2 commentary
  Timer? _poll;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    id = (args is Map ? args['id'] as int? : null) ?? 0;
    load();
    // While the match is live, refresh every 5 seconds.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (match.value?.status == 'LIVE') load(quiet: true);
    });
  }

  @override
  void onClose() {
    _poll?.cancel();
    super.onClose();
  }

  Future<void> load({bool quiet = false}) async {
    if (!quiet) error.value = null;
    try {
      final res = await _api.getMatch(id, light: quiet);
      if (res['success'] == true && res['match'] is Map) {
        final m = MatchDetail.fromJson(Map<String, dynamic>.from(res['match'] as Map));
        // Light refreshes leave out squads and the Playing XI; keep the ones already loaded.
        final old = match.value;
        match.value = quiet && old != null
            ? MatchDetail.fromJson({
                ...Map<String, dynamic>.from(res['match'] as Map),
                'home': {'entry_id': old.home?.entryId, 'name': old.home?.name, 'short': old.home?.short, 'logo_url': old.home?.logoUrl},
                'away': {'entry_id': old.away?.entryId, 'name': old.away?.name, 'short': old.away?.short, 'logo_url': old.away?.logoUrl},
              })
            : m;
      } else if (!quiet) {
        error.value = res['message']?.toString() ?? 'Could not load the match.';
      }
    } on ApiException catch (e) {
      if (!quiet && match.value == null) error.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// Opens toss & Playing XI, or the scoring screen, asking for the PIN first if needed.
  Future<void> score() async {
    final m = match.value;
    if (m == null) return;
    if (m.home == null || m.away == null) return AppSnackbar.info('Scoring', 'Both teams must be known before this match can be scored.');
    if (!m.canScore) {
      final ok = await askPin(m.tournamentCode);
      if (!ok) return;
      await load();
    }
    final fresh = match.value!;
    if (!fresh.canScore) return;
    if (!fresh.hasSetup) {
      final saved = await Get.toNamed(AppRoutes.matchSetup, arguments: {'id': id});
      if (saved != true) return load();
    }
    await Get.toNamed(AppRoutes.matchScore, arguments: {'id': id});
    await load();
  }

  /// Asks for the tournament's scoring PIN. Returns true when it was accepted.
  Future<bool> askPin(String tournamentCode) async {
    final ctrl = TextEditingController();
    final busy = false.obs;
    final ok = await Get.bottomSheet<bool>(
      Builder(builder: (sheet) => Obx(() => SheetFrame(title: 'Scoring PIN', children: [
            Text('Ask the organiser for the 6-digit scoring PIN. You only enter it once for this tournament.',
                style: tfStyle(13.5, color: Colors.white.withAlpha(170), height: 1.4)),
            gapH(14),
            FieldTextInput(
              key: const ValueKey('scoring-pin'),
              controller: ctrl,
              hint: '6-digit PIN',
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            gapH(14),
            SizedBox(
              width: double.infinity,
              child: SmallButtonLarge(
                key: const ValueKey('scoring-pin-go'),
                label: busy.value ? 'Checking…' : 'Start scoring',
                onTap: busy.value
                    ? null
                    : () async {
                        busy.value = true;
                        try {
                          final res = await _api.joinScoring(tournamentCode, ctrl.text.trim());
                          busy.value = false;
                          if (res['success'] == true) {
                            if (sheet.mounted) Navigator.of(sheet).pop(true);
                          } else {
                            AppSnackbar.error('Scoring PIN', res['message']?.toString() ?? 'Wrong PIN.');
                          }
                        } on ApiException catch (e) {
                          busy.value = false;
                          AppSnackbar.error('Scoring PIN', e.message);
                        }
                      },
              ),
            ),
          ]))),
      isScrollControlled: true,
    );
    return ok == true;
  }
}
