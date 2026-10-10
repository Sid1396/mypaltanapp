import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../data/models/entry.dart';
import '../../data/models/tournament.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';
import '../widgets/tournament_form_widgets.dart';
import '../widgets/tournament_media_editors.dart';

/// Tournament page opened by code. Arguments: {'code': 'ABC123'}.
class TournamentController extends GetxController with LoggerMixin {
  ApiService get _api => Get.find<ApiService>();

  late final String code;
  final tournament = Rx<Tournament?>(null);
  final isLoading = true.obs;
  final error = Rx<String?>(null);
  final isPublishing = false.obs;
  final isDeleting = false.obs;
  final tab = 0.obs;

  // Registrations: every entry for the organiser, confirmed teams for everyone else.
  final entries = <TournamentEntry>[].obs;
  final entriesLoaded = false.obs;
  final myEntries = <MyEntry>[].obs; // registrations by teams this user manages
  final expanded = <int>{}.obs;
  final busyEntry = 0.obs;

  // Sponsor impressions, sent in batches. The organiser's own views are not counted.
  final _seen = <int>{};
  final _views = <int, int>{};
  final _taps = <int, int>{};
  Timer? _flushTimer;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    code = (args is Map ? args['code'] as String? : null) ?? '';
    load();
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _flush());
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    _flush();
    super.onClose();
  }

  Future<void> load() async {
    error.value = null;
    try {
      final res = await _api.getTournament(code);
      if (res['success'] == true && res['tournament'] is Map) {
        tournament.value = Tournament.fromJson(Map<String, dynamic>.from(res['tournament'] as Map));
        if (!tournament.value!.isDraft) {
          loadEntries();
          if (!tournament.value!.isOwner) loadMine();
        }
      } else {
        error.value = res['message']?.toString() ?? 'Could not load this tournament.';
      }
    } on ApiException catch (e) {
      if (tournament.value == null) error.value = e.message;
      AppSnackbar.error('Tournament', e.message);
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Registrations ────────────────────────────────────────────

  Future<void> loadEntries() async {
    try {
      final res = await _api.getTournamentEntries(code);
      if (res['success'] == true) {
        entries.assignAll((res['entries'] as List? ?? []).whereType<Map>().map((m) => TournamentEntry.fromJson(Map<String, dynamic>.from(m))));
        entriesLoaded.value = true;
      }
    } on ApiException catch (e) {
      logError('Entries failed', e);
    }
  }

  Future<void> loadMine() async {
    try {
      final res = await _api.getRegistrationOptions(code);
      if (res['success'] == true) myEntries.assignAll(RegOptions.fromJson(res).myEntries);
    } on ApiException catch (e) {
      logError('My entries failed', e);
    }
  }

  /// The registration to show on the page: an active one first, otherwise the latest rejected one.
  MyEntry? get myEntry =>
      myEntries.firstWhereOrNull((e) => e.isActive) ?? myEntries.where((e) => e.status == 'REJECTED').lastOrNull;

  Future<void> register() async {
    final done = await Get.toNamed(AppRoutes.registerTeam, arguments: {'code': code});
    if (done == true) {
      await Future.wait([load(), loadMine()]);
    }
  }

  void toggleExpanded(int id) => expanded.contains(id) ? expanded.remove(id) : expanded.add(id);

  Future<void> _update(int id, String action, {String? reason}) async {
    busyEntry.value = id;
    try {
      final res = await _api.updateEntry(id, action, reason: reason);
      if (res['success'] != true) {
        AppSnackbar.error('Could not save', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      AppSnackbar.success('Done', res['message']?.toString() ?? 'Saved.');
      await Future.wait([load(), if (!(tournament.value?.isOwner ?? false)) loadMine()]);
    } on ApiException catch (e) {
      AppSnackbar.error('Could not save', e.message);
    } finally {
      busyEntry.value = 0;
    }
  }

  void approve(TournamentEntry e) => _confirm(
        'Confirm ${e.teamName}?',
        e.paymentMethod == 'NONE' || e.amount == 0
            ? 'The team gets a confirmed place in ${e.division ?? 'the tournament'}.'
            : 'Only confirm after you have received ${e.paymentMethod == 'CASH' ? 'the cash' : 'the payment in your UPI app'}. '
                'Once a team is confirmed, the fee and age limits of its division are locked.',
        'Confirm team',
        () => _update(e.id, 'APPROVE'),
        key: 'entry-approve-confirm',
      );

  void reject(TournamentEntry e) {
    final ctrl = TextEditingController();
    Get.bottomSheet(
      SheetFrame(title: 'Not accepting ${e.teamName}', children: [
        Text('Tell the team why. They see this message, so they can fix it and register again.',
            style: tfStyle(13.5, color: Colors.white.withAlpha(160), height: 1.4)),
        gapH(14),
        TextField(
          key: const ValueKey('entry-reject-reason'),
          controller: ctrl,
          maxLength: 200,
          maxLines: 3,
          style: tfStyle(14),
          decoration: InputDecoration(
            hintText: 'e.g. Payment not received, or two players are over age',
            hintStyle: tfStyle(13.5, color: Colors.white.withAlpha(90)),
            filled: true,
            fillColor: AppColors.primary.withAlpha(8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14)), borderSide: BorderSide(color: AppColors.primary.withAlpha(35))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14)), borderSide: BorderSide(color: AppColors.primary.withAlpha(35))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14)), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
        gapH(12),
        SizedBox(
          width: double.infinity,
          child: SmallButtonLarge(
            key: const ValueKey('entry-reject-send'),
            label: 'Send and remove team',
            onTap: () {
              final reason = ctrl.text.trim();
              if (reason.length < 3) return AppSnackbar.error('Reason', 'Write a short reason for the team.');
              Get.back();
              _update(e.id, 'REJECT', reason: reason);
            },
          ),
        ),
      ]),
      isScrollControlled: true,
    );
  }

  void withdraw(MyEntry e) => _confirm(
        'Withdraw ${e.teamName}?',
        'Your registration is cancelled and the organiser is told. '
            '${e.amount > 0 && e.paymentMethod == 'UPI' ? 'Ask the organiser directly about a refund. ' : ''}You can register again later.',
        'Withdraw',
        () => _update(e.id, 'WITHDRAW'),
        danger: true,
        key: 'entry-withdraw-confirm',
      );

  Future<void> callNumber(String phone) async {
    final ok = await launchUrl(Uri.parse('tel:$phone')).catchError((_) => false);
    if (!ok) AppSnackbar.info('Phone', phone);
  }

  void _confirm(String title, String body, String action, VoidCallback onYes, {bool danger = false, String? key}) {
    Get.dialog(AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(18))),
      title: Text(title, style: tfStyle(18, weight: FontWeight.w800)),
      content: Text(body, style: tfStyle(13.5, color: Colors.white.withAlpha(180), height: 1.45)),
      actions: [
        TextButton(onPressed: Get.back, child: Text('Cancel', style: tfStyle(14, color: Colors.white.withAlpha(180)))),
        TextButton(
          key: key != null ? ValueKey(key) : null,
          onPressed: () {
            Get.back();
            onYes();
          },
          child: Text(action, style: tfStyle(14, weight: FontWeight.w700, color: danger ? AppColors.negative : AppColors.primary)),
        ),
      ],
    ));
  }

  // ─── Organiser actions ────────────────────────────────────────

  Future<void> edit() async {
    final changed = await Get.toNamed(AppRoutes.createTournament, arguments: {'code': code});
    if (changed == true) load();
  }

  void confirmDeleteDraft() {
    Get.dialog(AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(18))),
      title: Text('Delete this draft?', style: tfStyle(18, weight: FontWeight.w800)),
      content: Text(
        'The tournament, its documents, sponsors and images will be removed. This cannot be undone.',
        style: tfStyle(13.5, color: Colors.white.withAlpha(180), height: 1.45),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('Keep it', style: tfStyle(14, color: Colors.white.withAlpha(180)))),
        TextButton(
          key: const ValueKey('delete-draft-confirm'),
          onPressed: () {
            Get.back();
            _deleteDraft();
          },
          child: Text('Delete', style: tfStyle(14, weight: FontWeight.w700, color: AppColors.negative)),
        ),
      ],
    ));
  }

  Future<void> _deleteDraft() async {
    isDeleting.value = true;
    try {
      final res = await _api.deleteTournament(code);
      if (res['success'] != true) {
        AppSnackbar.error('Could not delete', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      Get.back(result: 'deleted');
      AppSnackbar.success('Draft deleted', '${tournament.value?.name ?? 'The tournament'} was removed.');
    } on ApiException catch (e) {
      AppSnackbar.error('Could not delete', e.message);
    } finally {
      isDeleting.value = false;
    }
  }

  void copyCode() {
    Clipboard.setData(ClipboardData(text: code));
    AppSnackbar.success('Copied', 'Tournament code $code copied. Share it with captains.');
  }

  void showPublishSheet() {
    final t = tournament.value;
    if (t == null) return;
    final public = true.obs;
    Get.bottomSheet(
      Obx(() => SheetFrame(
            title: 'Publish tournament',
            children: [
              Text('Registration opens as soon as you publish. Captains can then register their teams.',
                  style: tfStyle(13.5, color: Colors.white.withAlpha(160), height: 1.4)),
              gapH(16),
              OptionCard(
                key: const ValueKey('publish-public'),
                title: 'Public',
                subtitle: 'Listed in Tournaments for everyone in ${t.city} after the MyPaltan team approves it (usually within 24 hours).',
                icon: Icons.public_rounded,
                selected: public.value,
                onTap: () => public.value = true,
              ),
              gapH(10),
              OptionCard(
                key: const ValueKey('publish-private'),
                title: 'Private',
                subtitle: 'Not listed. Only people you share the code with can find it.',
                icon: Icons.lock_rounded,
                selected: !public.value,
                onTap: () => public.value = false,
              ),
              gapH(20),
              SizedBox(
                width: double.infinity,
                child: SmallButtonLarge(
                  key: const ValueKey('publish-confirm'),
                  label: isPublishing.value ? 'Publishing…' : 'Publish now',
                  onTap: isPublishing.value ? null : () => _publish(public.value),
                ),
              ),
            ],
          )),
      isScrollControlled: true,
    );
  }

  Future<void> _publish(bool public) async {
    isPublishing.value = true;
    try {
      final res = await _api.publishTournament(code, public: public);
      if (Get.isBottomSheetOpen == true) Get.back();
      if (res['success'] == true) {
        AppSnackbar.success('Published', res['message']?.toString() ?? 'Registration is open.');
        await load();
        return;
      }
      if (res['code'] == 'NEEDS_VERIFICATION') return _askToVerify();
      AppSnackbar.error('Could not publish', res['message']?.toString() ?? 'Please try again.');
    } on ApiException catch (e) {
      AppSnackbar.error('Could not publish', e.message);
    } finally {
      isPublishing.value = false;
    }
  }

  void _askToVerify() {
    Get.dialog(AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(18))),
      title: Text('Verify your identity', style: tfStyle(18, weight: FontWeight.w800)),
      content: Text(
        'To keep players safe, every organiser verifies their ID once before publishing. '
        'It takes a minute, and the MyPaltan team reviews it within 24 hours.',
        style: tfStyle(13.5, color: Colors.white.withAlpha(180), height: 1.45),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('Later', style: tfStyle(14, color: Colors.white.withAlpha(180)))),
        TextButton(
          key: const ValueKey('verify-now'),
          onPressed: () {
            Get.back();
            Get.toNamed(AppRoutes.verifyIdentity);
          },
          child: Text('Verify now', style: tfStyle(14, weight: FontWeight.w700, color: AppColors.primary)),
        ),
      ],
    ));
  }

  // ─── Documents ────────────────────────────────────────────────

  void openDocument(TournamentDocument d) {
    if (d.url == null) return AppSnackbar.error('Document', 'This document is not available right now.');
    Get.toNamed(AppRoutes.documentViewer, arguments: {'title': d.title, 'url': d.url, 'pdf': d.isPdf});
  }

  // ─── Sponsors ─────────────────────────────────────────────────

  bool get _track => tournament.value != null && !tournament.value!.isOwner && !tournament.value!.isDraft;

  /// Counts one view per sponsor per visit to this page.
  void sponsorSeen(int id) {
    if (!_track || !_seen.add(id)) return;
    _views[id] = (_views[id] ?? 0) + 1;
  }

  Future<void> openSponsor(TournamentSponsor s) async {
    if (s.linkUrl == null) return;
    if (_track) _taps[s.id] = (_taps[s.id] ?? 0) + 1;
    final uri = Uri.tryParse(s.linkUrl!);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      AppSnackbar.error('Link', "Couldn't open ${s.name}'s link.");
    }
  }

  void _flush() {
    final ids = {..._views.keys, ..._taps.keys};
    if (ids.isEmpty) return;
    final events = [for (final id in ids) {'sponsor_id': id, 'views': _views[id] ?? 0, 'taps': _taps[id] ?? 0}];
    _views.clear();
    _taps.clear();
    _api.trackSponsors(events).catchError((Object e) {
      logError('Sponsor tracking failed', e);
      return <String, dynamic>{};
    });
  }
}
