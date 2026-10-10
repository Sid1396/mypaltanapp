import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../data/models/team.dart';
import '../../utils/helpers/size_config.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../controllers/create_tournament_controller.dart' show UploadSlot, UploadedFile;
import '../controllers/team_controllers.dart';
import '../widgets/create_tournament_steps.dart' show fmtDate;
import '../widgets/form_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/tournament_form_widgets.dart';
import '../widgets/tournament_media_editors.dart' show SmallButtonLarge;

String _roleLabel(String sport, String? code) => code == null ? '' : Sports.labelOf(Sports.byCode(sport)?.roles ?? const [], code);

class TeamPage extends GetView<TeamController> {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Obx(() {
          final t = controller.team.value;
          if (controller.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          if (t == null) {
            return Column(children: [
              _TopBar(team: null),
              const Spacer(),
              EmptyCard(
                icon: Icons.shield_outlined,
                title: 'Could not open team',
                message: controller.error.value ?? 'Team not found.',
                actions: [SmallButton(label: 'Try again', onTap: controller.load)],
              ),
              const Spacer(flex: 2),
            ]);
          }
          return Column(
            children: [
              _TopBar(team: t),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: controller.load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(4), SizeConfig.w(20), SizeConfig.h(30)),
                    children: [
                      _Header(t: t),
                      gapH(18),
                      if (controller.tournamentCode != null && controller.squad.value != null) ...[
                        _SquadCard(t: t, s: controller.squad.value!),
                        gapH(18),
                      ],
                      if (!t.isMember) ...[if (controller.squad.value == null) _JoinCard(t: t)] else ...[
                        _InviteCard(t: t),
                        gapH(22),
                        _Squad(t: t),
                        ...[
                          gapH(24),
                          Center(
                            child: TextButton.icon(
                              key: const ValueKey('team-leave'),
                              onPressed: () => controller.confirm(
                                'Leave ${t.name}?',
                                'You can join again later with the team link.',
                                'Leave',
                                () => controller.manage({'action': 'LEAVE'}, leaving: true),
                                danger: true,
                              ),
                              icon: Icon(Icons.logout_rounded, size: SizeConfig.r(17), color: AppColors.negative),
                              label: Text('Leave team', style: tfStyle(13.5, weight: FontWeight.w700, color: AppColors.negative)),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _TopBar extends GetView<TeamController> {
  final Team? team;
  const _TopBar({required this.team});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback onTap, {Key? key}) => GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            width: SizeConfig.r(40),
            height: SizeConfig.r(40),
            decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
            child: Icon(icon, size: SizeConfig.r(18), color: Colors.white),
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(10), SizeConfig.w(20), SizeConfig.h(10)),
      child: Row(
        children: [
          btn(Icons.arrow_back_ios_new_rounded, Get.back, key: const ValueKey('team-back')),
          const Spacer(),
          if (team?.canManage == true) ...[btn(Icons.edit_rounded, controller.edit, key: const ValueKey('team-edit')), SizedBox(width: SizeConfig.w(8))],
          if (team?.isMember == true) btn(Icons.ios_share_rounded, controller.shareMore),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Team t;
  const _Header({required this.t});

  @override
  Widget build(BuildContext context) {
    final sport = Sports.byCode(t.sport);
    return Row(
      children: [
        Container(
          width: SizeConfig.r(84),
          height: SizeConfig.r(84),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(SizeConfig.r(20))),
          child: t.logoUrl != null
              ? Image.network(t.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())
              : Icon(Icons.shield_rounded, color: Colors.white.withAlpha(60), size: SizeConfig.r(36)),
        ),
        SizedBox(width: SizeConfig.w(14)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${sport?.label.toUpperCase() ?? t.sport} · ${t.shortName}',
                  style: tfStyle(11, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.8)),
              gapH(3),
              Text(t.name, style: tfStyle(22, weight: FontWeight.w900, height: 1.1)),
              gapH(4),
              Text('${t.location} · ${t.members} ${t.members == 1 ? 'player' : 'players'}', style: tfStyle(12.5, color: Colors.white.withAlpha(140))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opened from a squad link: join the team's squad for a tournament (joins the team too).
class _SquadCard extends GetView<TeamController> {
  final Team t;
  final SquadInvite s;
  const _SquadCard({required this.t, required this.s});

  @override
  Widget build(BuildContext context) {
    final color = s.inSquad ? AppColors.positive : (s.problem != null ? const Color(0xFFFFB74D) : AppColors.primary);
    final count = s.squadMax != null ? '${s.squadCount} of ${s.squadMax} players' : '${s.squadCount} players';
    return Container(
      key: const ValueKey('squad-card'),
      padding: EdgeInsets.all(SizeConfig.r(16)),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(SizeConfig.r(16)),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.inSquad ? "YOU'RE IN THE SQUAD" : 'SQUAD INVITE', style: tfStyle(11, weight: FontWeight.w800, color: color).copyWith(letterSpacing: 0.8)),
          gapH(6),
          Text(s.tournamentName, style: tfStyle(18, weight: FontWeight.w900)),
          gapH(2),
          Text([if (s.division != null) s.division!, count].join(' · '), style: tfStyle(13, color: Colors.white.withAlpha(170))),
          gapH(10),
          Text(
            s.inSquad
                ? "You'll play for ${t.name}. The organiser shares the match schedule closer to the day."
                : s.problem ?? '${t.captainName} invited you to play for ${t.name}.${s.inTeam ? '' : ' Joining the squad also adds you to the team.'}',
            style: tfStyle(13.5, color: Colors.white.withAlpha(200), height: 1.45),
          ),
          gapH(14),
          if (s.inSquad || s.problem != null)
            SizedBox(
              width: double.infinity,
              child: SmallButton(key: const ValueKey('squad-open-tournament'), label: 'View tournament', filled: false, onTap: controller.openTournament),
            )
          else
            Obx(() => SizedBox(
                  width: double.infinity,
                  child: SmallButtonLarge(
                    key: const ValueKey('squad-join'),
                    label: controller.isBusy.value ? 'Joining…' : 'Join the squad',
                    onTap: controller.isBusy.value ? null : controller.joinSquad,
                  ),
                )),
        ],
      ),
    );
  }
}

class _JoinCard extends GetView<TeamController> {
  final Team t;
  const _JoinCard({required this.t});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: SizeConfig.r(16),
                backgroundColor: const Color(0xFF2A2A2A),
                backgroundImage: t.captainPhotoUrl != null ? NetworkImage(t.captainPhotoUrl!) : null,
                onBackgroundImageError: t.captainPhotoUrl != null ? (_, __) {} : null,
              ),
              SizedBox(width: SizeConfig.w(10)),
              Expanded(child: Text('${t.managerRole == 'COACH' ? 'Coach' : 'Captain'}: ${t.captainName}', style: tfStyle(14, weight: FontWeight.w700))),
            ],
          ),
          gapH(12),
          Text(
            t.removed
                ? 'The captain removed you from this team. Ask them to add you back.'
                : 'Join to appear in the squad. The coach or captain picks the squad when the team enters a tournament.',
            style: tfStyle(13.5, color: Colors.white.withAlpha(180), height: 1.45),
          ),
          if (!t.removed) ...[
            gapH(14),
            Obx(() => SizedBox(
                  width: double.infinity,
                  child: SmallButtonLarge(
                    key: const ValueKey('team-join'),
                    label: controller.isBusy.value ? 'Joining…' : 'Join ${t.name}',
                    onTap: controller.isBusy.value ? null : controller.join,
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _InviteCard extends GetView<TeamController> {
  final Team t;
  const _InviteCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final link = TeamController.linkFor(t.code);
    Widget action(IconData icon, String label, Color color, VoidCallback onTap, {Key? key}) => Expanded(
          child: GestureDetector(
            key: key,
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: SizeConfig.h(10)),
              decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(10))),
              child: Column(
                children: [
                  Icon(icon, color: color, size: SizeConfig.r(20)),
                  gapH(4),
                  Text(label, style: tfStyle(12, weight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invite players', style: tfStyle(15, weight: FontWeight.w800)),
          gapH(3),
          Text('Anyone with this link can join. Players under 13 can be added by the coach or captain below.',
              style: tfStyle(12.5, color: Colors.white.withAlpha(170), height: 1.4)),
          gapH(10),
          Text(link.replaceFirst('https://', ''), style: tfStyle(13.5, weight: FontWeight.w700, color: AppColors.primary)),
          gapH(12),
          Row(
            children: [
              action(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366), controller.shareWhatsApp, key: const ValueKey('team-share-whatsapp')),
              SizedBox(width: SizeConfig.w(8)),
              action(Icons.copy_rounded, 'Copy link', Colors.white, () {
                Clipboard.setData(ClipboardData(text: link));
                AppSnackbar.success('Link copied', 'Send it to your players.');
              }),
              SizedBox(width: SizeConfig.w(8)),
              action(Icons.ios_share_rounded, 'More', Colors.white, controller.shareMore),
            ],
          ),
        ],
      ),
    );
  }
}

class _Squad extends GetView<TeamController> {
  final Team t;
  const _Squad({required this.t});

  @override
  Widget build(BuildContext context) {
    final coaches = t.coaches, players = t.players;
    Widget label(String text) =>
        Text(text, style: tfStyle(12, weight: FontWeight.w800, color: Colors.white.withAlpha(140)).copyWith(letterSpacing: 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (coaches.isNotEmpty) ...[
          label(coaches.length == 1 ? 'COACH' : 'COACHES'),
          gapH(10),
          for (final m in coaches) ...[_MemberRow(t: t, m: m), gapH(8)],
          gapH(14),
        ],
        Row(
          children: [
            label('SQUAD · ${players.length}'),
            const Spacer(),
            if (t.canManage)
              GestureDetector(
                key: const ValueKey('team-add-kid'),
                onTap: () => showGuestSheet(t),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, size: SizeConfig.r(17), color: AppColors.primary),
                    SizedBox(width: SizeConfig.w(5)),
                    Text('Add player under 13', style: tfStyle(13, weight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),
          ],
        ),
        gapH(10),
        if (players.isEmpty)
          Text('No players yet. Share the team link, or add children under 13 yourself.', style: tfStyle(13, color: Colors.white.withAlpha(140)))
        else
          for (final m in players) ...[_MemberRow(t: t, m: m), gapH(8)],
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final Team t;
  final TeamMember m;
  const _MemberRow({required this.t, required this.m});

  @override
  Widget build(BuildContext context) {
    // Coaches do not play, so no playing role or jersey for them.
    final details = [
      if (m.isCoach) 'Runs the team, does not play',
      if (m.position != null && !m.isCoach) _roleLabel(t.sport, m.position),
      if (m.isGuest && m.age != null) 'Age ${m.age}',
      if (m.isGuest) 'added by coach',
    ].join(' · ');
    final initials = m.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();
    return GestureDetector(
      key: ValueKey('member-${m.id}'),
      onTap: () => showMemberActions(t, m),
      child: Container(
        padding: EdgeInsets.all(SizeConfig.r(10)),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(color: m.isMe ? AppColors.primary.withAlpha(90) : Colors.white.withAlpha(12)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: SizeConfig.r(22),
              backgroundColor: const Color(0xFF2A2A2A),
              backgroundImage: m.photoUrl != null ? NetworkImage(m.photoUrl!) : null,
              onBackgroundImageError: m.photoUrl != null ? (_, __) {} : null,
              child: m.photoUrl == null ? Text(initials, style: tfStyle(14, weight: FontWeight.w800, color: Colors.white.withAlpha(170))) : null,
            ),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(m.isMe ? '${m.name} (you)' : m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14.5, weight: FontWeight.w700))),
                      if (m.isCaptain || m.isVice) ...[
                        SizedBox(width: SizeConfig.w(6)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(6), vertical: SizeConfig.h(1)),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(SizeConfig.r(6))),
                          child: Text(m.isCaptain ? 'C' : 'VC', style: tfStyle(10.5, weight: FontWeight.w900)),
                        ),
                      ],
                    ],
                  ),
                  if (details.isNotEmpty) Text(details, style: tfStyle(12, color: Colors.white.withAlpha(130))),
                ],
              ),
            ),
            if (m.jerseyNumber != null && !m.isCoach)
              Column(
                children: [
                  Text('${m.jerseyNumber}', style: tfStyle(18, weight: FontWeight.w900)),
                  if (m.jerseyName != null) Text(m.jerseyName!, style: tfStyle(9.5, weight: FontWeight.w700, color: Colors.white.withAlpha(120))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sheets ─────────────────────────────────────────────────────

void showMemberActions(Team t, TeamMember m) {
  final c = Get.find<TeamController>();
  void setRole(String role) => c.manage({'action': 'SET_ROLE', 'member_id': m.id, 'role': role});
  final roleOptions = <(IconData, String, VoidCallback, bool)>[
    if (t.isAdmin && !m.isCaptain && !m.isCoach)
      (
        Icons.star_rounded,
        'Make captain',
        () => c.confirm('Make ${m.name} captain?', 'The current captain becomes a regular player.', 'Make captain', () => setRole('CAPTAIN')),
        false
      ),
    if (t.isAdmin && !m.isVice && !m.isCoach) (Icons.star_half_rounded, 'Make vice-captain', () => setRole('VICE_CAPTAIN'), false),
    if (t.isAdmin && (m.isCaptain || m.isVice || m.isCoach) && !(m.isMe && !t.isAdmin)) (Icons.person_rounded, 'Make regular player', () => setRole('PLAYER'), false),
    if (t.isAdmin && !m.isGuest && !m.isCoach)
      (
        Icons.assignment_ind_rounded,
        'Make coach (does not play)',
        () => c.confirm('Make ${m.name} a coach?', 'Coaches run the team but are not counted in the squad.', 'Make coach', () => setRole('COACH')),
        false
      ),
  ];
  final options = <(IconData, String, VoidCallback, bool)>[
    if (m.isMe && !m.isCoach) (Icons.checkroom_rounded, 'Edit my jersey and role', () => showJerseySheet(t, m), false),
    if (t.canManage && m.isGuest) (Icons.edit_rounded, 'Edit player', () => showGuestSheet(t, member: m), false),
    if (t.canManage && !m.isGuest && !m.isMe && !m.isCoach) (Icons.checkroom_rounded, 'Edit jersey and role', () => showJerseySheet(t, m), false),
    ...roleOptions,
    if (t.canManage && !m.isMe && (t.isAdmin || (!m.isCaptain && !m.isVice && !m.isCoach)))
      (
        Icons.person_remove_rounded,
        'Remove from team',
        () => c.confirm('Remove ${m.name}?', m.isGuest ? 'Their details will be deleted.' : 'They will not be able to rejoin with the team link.', 'Remove',
            () => c.manage({'action': 'REMOVE', 'member_id': m.id}), danger: true),
        true
      ),
  ];
  if (options.isEmpty) return;
  Get.bottomSheet(SheetFrame(title: m.name, children: [
    for (final (icon, label, onTap, danger) in options)
      GestureDetector(
        onTap: () {
          Get.back();
          onTap();
        },
        child: Container(
          margin: EdgeInsets.only(bottom: SizeConfig.h(8)),
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(14)),
          decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(SizeConfig.r(14))),
          child: Row(
            children: [
              Icon(icon, color: danger ? AppColors.negative : AppColors.primary, size: SizeConfig.r(20)),
              SizedBox(width: SizeConfig.w(12)),
              Text(label, style: tfStyle(15, weight: FontWeight.w700, color: danger ? AppColors.negative : Colors.white)),
            ],
          ),
        ),
      ),
  ]));
}

void showJerseySheet(Team t, TeamMember m) {
  Get.bottomSheet(_JerseySheet(t: t, m: m), isScrollControlled: true);
}

class _JerseySheet extends StatefulWidget {
  final Team t;
  final TeamMember m;
  const _JerseySheet({required this.t, required this.m});

  @override
  State<_JerseySheet> createState() => _JerseySheetState();
}

class _JerseySheetState extends State<_JerseySheet> {
  late final _name = TextEditingController(text: widget.m.jerseyName ?? '');
  late final _number = TextEditingController(text: widget.m.jerseyNumber?.toString() ?? '');
  late String _position = widget.m.position ?? '';

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TeamController>();
    return SheetFrame(title: 'Jersey & role', children: [
      Text('For ${widget.t.name} only. Other teams keep the details from the profile.', style: tfStyle(13, color: Colors.white.withAlpha(150))),
      gapH(16),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FormLabel('Name on jersey'),
              FieldTextInput(controller: _name, hint: 'e.g. SID', maxLength: 12, textCapitalization: TextCapitalization.characters),
            ]),
          ),
          SizedBox(width: SizeConfig.w(10)),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FormLabel('Number'),
              FieldTextInput(controller: _number, hint: '0-99', maxLength: 2, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
            ]),
          ),
        ],
      ),
      gapH(16),
      const FormLabel('Playing role'),
      ChoiceChips(options: Sports.byCode(widget.t.sport)?.roles ?? const [], selected: _position, onSelected: (v) => setState(() => _position = v)),
      gapH(20),
      Obx(() => SizedBox(
            width: double.infinity,
            child: SmallButtonLarge(
              label: 'Save',
              onTap: c.isBusy.value
                  ? null
                  : () async {
                      final ok = await c.manage({
                        'action': 'SET_JERSEY',
                        'member_id': widget.m.id,
                        'jersey_name': _name.text.trim(),
                        'jersey_number': _number.text.trim().isEmpty ? null : int.parse(_number.text.trim()),
                        'position': _position.isEmpty ? null : _position,
                      });
                      // Close this sheet itself: Get.back() would close the success message instead.
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
            ),
          )),
    ]);
  }
}

/// Add or edit a player under 13 who does not have the app.
void showGuestSheet(Team t, {TeamMember? member}) {
  Get.bottomSheet(_GuestSheet(t: t, m: member), isScrollControlled: true);
}

class _GuestSheet extends StatefulWidget {
  final Team t;
  final TeamMember? m;
  const _GuestSheet({required this.t, this.m});

  @override
  State<_GuestSheet> createState() => _GuestSheetState();
}

class _GuestSheetState extends State<_GuestSheet> {
  late final _name = TextEditingController(text: widget.m?.name ?? '');
  late final _jerseyName = TextEditingController(text: widget.m?.jerseyName ?? '');
  late final _jerseyNumber = TextEditingController(text: widget.m?.jerseyNumber?.toString() ?? '');
  late final _parent = TextEditingController(text: widget.m?.parentPhone ?? '');
  late DateTime? _birthdate = widget.m?.birthdate == null ? null : DateTime.tryParse(widget.m!.birthdate!);
  late String _gender = widget.m?.gender ?? '';
  late String _position = widget.m?.position ?? '';
  final _photo = UploadSlot();

  @override
  void initState() {
    super.initState();
    if (widget.m?.photoUrl != null && widget.m!.isGuest) {
      // Keep the existing photo unless a new one is uploaded (the key is not sent back to clients).
      _photo.file.value = UploadedFile(key: '', url: widget.m!.photoUrl);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _jerseyName, _jerseyNumber, _parent]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 8, now.month, now.day),
      firstDate: DateTime(now.year - 13, now.month, now.day + 1),
      lastDate: DateTime(now.year - 3, now.month, now.day),
      helpText: 'Date of birth',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary, onPrimary: Colors.white, surface: AppColors.darkSurface, onSurface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _birthdate = d);
  }

  Future<void> _save() async {
    final c = Get.find<TeamController>();
    final name = _name.text.trim();
    if (name.length < 2) return AppSnackbar.error('Player', "Enter the player's full name.");
    if (_birthdate == null) return AppSnackbar.error('Player', 'Choose the date of birth.');
    if (_photo.busy.value) return AppSnackbar.error('Player', 'Wait for the photo to finish uploading.');
    final b = _birthdate!;
    final photoKey = _photo.file.value?.key;
    final ok = await c.manage({
      'action': widget.m == null ? 'ADD_GUEST' : 'EDIT_GUEST',
      if (widget.m != null) 'member_id': widget.m!.id,
      'name': name,
      'birthdate': '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
      'gender': _gender.isEmpty ? 'UNDISCLOSED' : _gender,
      'jersey_name': _jerseyName.text.trim(),
      'jersey_number': _jerseyNumber.text.trim().isEmpty ? null : int.parse(_jerseyNumber.text.trim()),
      'position': _position.isEmpty ? null : _position,
      'parent_phone': _parent.text.trim(),
      if (photoKey != null && photoKey.isNotEmpty) 'photo_key': photoKey,
    });
    // Close this sheet itself: Get.back() would close the success message instead.
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TeamController>();
    return SheetFrame(title: widget.m == null ? 'Add a player under 13' : 'Edit player', children: [
      Text('For children who do not have MyPaltan. Only coaches, the captain and vice-captain see their date of birth and parent\'s number.',
          style: tfStyle(12.5, color: Colors.white.withAlpha(150), height: 1.4)),
      gapH(16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UploadBox(
            slot: _photo,
            aspectRatio: 1,
            width: SizeConfig.w(84),
            label: 'Photo',
            hint: 'Optional',
            icon: Icons.add_a_photo_rounded,
            onPick: () => uploadSquareImage('PLAYER_PHOTO', _photo),
          ),
          SizedBox(width: SizeConfig.w(12)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FormLabel('Full name'),
              FieldTextInput(key: const ValueKey('kid-name'), controller: _name, hint: 'e.g. Aarav Shah', maxLength: 50, textCapitalization: TextCapitalization.words),
            ]),
          ),
        ],
      ),
      gapH(14),
      const FormLabel('Date of birth', hint: 'Used to check age groups in tournaments.'),
      FieldPicker(
        key: const ValueKey('kid-dob'),
        icon: Icons.cake_rounded,
        label: _birthdate == null ? 'Choose date' : fmtDate(_birthdate),
        filled: _birthdate != null,
        onTap: _pickBirthdate,
      ),
      gapH(14),
      const FormLabel('Gender', optional: true),
      ChoiceChips(options: Sports.genders, selected: _gender, onSelected: (v) => setState(() => _gender = v)),
      gapH(14),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FormLabel('Name on jersey', optional: true),
              FieldTextInput(controller: _jerseyName, hint: 'AARAV', maxLength: 12, textCapitalization: TextCapitalization.characters),
            ]),
          ),
          SizedBox(width: SizeConfig.w(10)),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FormLabel('Number', optional: true),
              FieldTextInput(controller: _jerseyNumber, hint: '0-99', maxLength: 2, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
            ]),
          ),
        ],
      ),
      gapH(14),
      const FormLabel('Playing role', optional: true),
      ChoiceChips(options: Sports.byCode(widget.t.sport)?.roles ?? const [], selected: _position, allowDeselect: true, onSelected: (v) => setState(() => _position = v)),
      gapH(14),
      const FormLabel("Parent's mobile", optional: true, hint: 'So you can reach the family about matches.'),
      FieldTextInput(controller: _parent, hint: '10-digit number', prefixText: '+91 ', maxLength: 10, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
      gapH(20),
      Obx(() => SizedBox(
            width: double.infinity,
            child: SmallButtonLarge(
              key: const ValueKey('kid-save'),
              label: c.isBusy.value ? 'Saving…' : (widget.m == null ? 'Add to squad' : 'Save'),
              onTap: c.isBusy.value ? null : _save,
            ),
          )),
    ]);
  }
}
