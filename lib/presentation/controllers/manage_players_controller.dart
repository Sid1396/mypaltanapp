import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';

/// A child or player in a website-tournament squad (as returned by the coach endpoint).
class SquadMember {
  final int id;
  final String name;
  final String status; // PENDING (waiting for the coach) or ACTIVE (in the squad)
  final int? age; // on the tournament's first day
  final String? birthdate;
  final int? jerseyNumber;
  final String? parentPhone;
  final String? photoUrl;
  final String? joined;
  const SquadMember(
      {required this.id, required this.name, required this.status, this.age, this.birthdate, this.jerseyNumber, this.parentPhone, this.photoUrl, this.joined});

  factory SquadMember.fromJson(Map<String, dynamic> j) => SquadMember(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        status: j['status']?.toString() ?? 'PENDING',
        age: (j['age'] as num?)?.toInt(),
        birthdate: j['birthdate']?.toString(),
        jerseyNumber: (j['jersey_number'] as num?)?.toInt(),
        parentPhone: j['parent_phone']?.toString(),
        photoUrl: j['photo_url']?.toString(),
        joined: j['joined']?.toString(),
      );
}

/// Coach's view of a team registered for a website tournament (e.g. Football Fiesta): the player link for parents,
/// children waiting for approval and the squad. Arguments: {'entry_id', 'slug', 'tournament'}.
class ManagePlayersController extends GetxController with LoggerMixin {
  ApiService get _api => Get.find<ApiService>();

  late final int entryId;
  late final String slug;
  final isLoading = true.obs;
  final error = Rx<String?>(null);
  final busy = Rx<int?>(null);

  final teamName = ''.obs;
  final teamCode = ''.obs;
  final division = ''.obs;
  final status = ''.obs;
  final tournamentName = ''.obs;
  final startDate = ''.obs;
  final started = false.obs;
  final paidPlayers = 0.obs;
  final members = <SquadMember>[].obs;

  List<SquadMember> get waiting => members.where((m) => m.status == 'PENDING').toList();
  List<SquadMember> get squad => members.where((m) => m.status == 'ACTIVE').toList();
  bool get approved => status.value == 'APPROVED';
  bool get locked => started.value || !['PENDING', 'WAITLISTED', 'APPROVED'].contains(status.value);
  String get playerLink => 'https://mypaltan.com/register/$slug/team/${teamCode.value}';

  @override
  void onInit() {
    super.onInit();
    final a = Get.arguments as Map? ?? const {};
    entryId = (a['entry_id'] as num?)?.toInt() ?? 0;
    slug = a['slug']?.toString() ?? '';
    tournamentName.value = a['tournament']?.toString() ?? '';
    load();
  }

  Future<void> load() async {
    error.value = null;
    try {
      final res = await _api.manageWebSquad(entryId);
      if (res['success'] != true) {
        error.value = res['message']?.toString() ?? 'Could not load your players.';
        return;
      }
      final t = Map<String, dynamic>.from(res['team'] as Map? ?? {});
      final tour = Map<String, dynamic>.from(res['tournament'] as Map? ?? {});
      teamName.value = t['name']?.toString() ?? '';
      teamCode.value = t['code']?.toString() ?? '';
      division.value = t['division']?.toString() ?? '';
      status.value = t['status']?.toString() ?? '';
      paidPlayers.value = (t['paid_players'] as num?)?.toInt() ?? 0;
      tournamentName.value = tour['name']?.toString() ?? tournamentName.value;
      startDate.value = tour['start_date']?.toString() ?? '';
      started.value = tour['started'] == true;
      members.assignAll((res['members'] as List? ?? []).whereType<Map>().map((m) => SquadMember.fromJson(Map<String, dynamic>.from(m))));
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> act(String action, SquadMember m) async {
    if (busy.value != null) return;
    busy.value = m.id;
    try {
      final res = await _api.manageWebSquad(entryId, action: action, memberId: m.id);
      if (res['success'] == true) {
        AppSnackbar.success(teamName.value, res['message']?.toString() ?? 'Saved.');
        await load();
      } else {
        AppSnackbar.error('Could not save', res['message']?.toString() ?? 'Please try again.');
      }
    } on ApiException catch (e) {
      AppSnackbar.error('Could not save', e.message);
    } finally {
      busy.value = null;
    }
  }

  String get _shareText => '${teamName.value} – ${tournamentName.value}\nParents, please add your child to our team here:\n$playerLink';

  Future<void> shareWhatsApp() async {
    final opened = await launchUrl(Uri.parse('whatsapp://send?text=${Uri.encodeComponent(_shareText)}'), mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!opened) await SharePlus.instance.share(ShareParams(text: _shareText, subject: teamName.value));
  }

  void copyLink() {
    Clipboard.setData(ClipboardData(text: playerLink));
    AppSnackbar.success('Copied', 'Player link copied.');
  }

  Future<void> callParent(String phone) async {
    if (!await launchUrl(Uri.parse('tel:+91$phone')).catchError((_) => false)) AppSnackbar.info('Parent', '+91 $phone');
  }
}
