import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../data/models/entry.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/register_team_controller.dart';
import '../widgets/create_tournament_steps.dart' show rupees;
import '../widgets/form_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/onboarding_widgets.dart';
import '../widgets/tournament_form_widgets.dart';

const _amber = Color(0xFFFFB74D);
const _roleLabels = {'COACH': 'Coach', 'CAPTAIN': 'Captain', 'VICE_CAPTAIN': 'Vice-captain'};

class RegisterTeamPage extends GetView<RegisterTeamController> {
  const RegisterTeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.back();
      },
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        body: SafeArea(
          child: Obx(() {
            final o = c.options.value;
            if (c.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            if (o == null) return _Message(title: 'Registration', message: c.error.value ?? 'Could not load registration.', onRetry: c.load);
            if (o.isOwner) return const _Message(title: "It's your tournament", message: 'Organisers cannot register a team in their own tournament.');
            if (!o.open) return const _Message(title: 'Registration closed', message: 'This tournament is not taking registrations right now.');
            final steps = c.steps;
            return Column(
              children: [
                _TopBar(title: o.name, step: c.step.value + 1, of: steps.length, onBack: c.back),
                Expanded(
                  child: ListView(
                    key: ValueKey('reg-step-${c.current.name}'),
                    padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(24)),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: switch (c.current) {
                      RegStep.team => _teamStep(c, o),
                      RegStep.division => _divisionStep(c, o),
                      RegStep.squad => _squadStep(c),
                      RegStep.payment => _paymentStep(c, o),
                    },
                  ),
                ),
                if (!(c.current == RegStep.team && o.teams.isEmpty))
                  StepBottomButton(
                    key: const ValueKey('reg-next'),
                    label: c.isLast ? (c.division?.isFull == true ? 'Join the waitlist' : 'Register team') : 'Continue',
                    loading: c.isSubmitting.value,
                    onPressed: c.next,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ─── Step 1: team ─────────────────────────────────────────────

  List<Widget> _teamStep(RegisterTeamController c, RegOptions o) => [
        const StepIntro(title: 'Which team?', subtitle: 'Coaches, captains and vice-captains can register a team.'),
        gapH(20),
        if (o.teams.isEmpty)
          EmptyCard(
            icon: Icons.shield_rounded,
            title: 'You need a team first',
            message: 'Create your team, add your players, then come back to register. Only teams you coach or captain show here.',
            actions: [SmallButton(key: const ValueKey('reg-create-team'), label: 'Create a team', onTap: c.createTeam)],
          )
        else ...[
          for (final t in o.teams) ...[
            _TeamTile(team: t, entry: c.entryFor(t.code), selected: c.teamCode.value == t.code, onTap: () => c.selectTeam(t.code)),
            gapH(10),
          ],
          gapH(6),
          Center(
            child: TextButton(
              onPressed: c.createTeam,
              child: Text('Create another team', style: tfStyle(13.5, weight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
        ],
      ];

  // ─── Step 2: division ─────────────────────────────────────────

  List<Widget> _divisionStep(RegisterTeamController c, RegOptions o) => [
        StepIntro(title: o.divisions.length == 1 ? 'Your division' : 'Which division?', subtitle: 'Players must fit the age limit on the first match day.'),
        gapH(20),
        for (final d in o.divisions) ...[
          _DivisionTile(d: d, selected: c.divisionId.value == d.id, onTap: () => c.selectDivision(d.id)),
          gapH(10),
        ],
      ];

  // ─── Step 3: squad ────────────────────────────────────────────

  List<Widget> _squadStep(RegisterTeamController c) {
    final t = c.team!;
    final d = c.division!;
    final range = d.squadMin == d.squadMax ? '${d.squadMin}' : '${d.squadMin} to ${d.squadMax}';
    final players = [...t.players]..sort((a, b) => (c.blockedReason(a) == null ? 0 : 1).compareTo(c.blockedReason(b) == null ? 0 : 1));
    return [
      StepIntro(title: 'Pick your squad', subtitle: 'Choose $range players from ${t.name}. Coaches are not counted.'),
      gapH(16),
      Row(
        children: [
          Text('${c.picked.length} of ${d.squadMax} picked',
              style: tfStyle(14, weight: FontWeight.w800, color: c.picked.length >= d.squadMin ? AppColors.primary : Colors.white)),
          const Spacer(),
          if (c.picked.length < d.squadMin) Text('${d.squadMin - c.picked.length} more needed', style: tfStyle(12.5, color: Colors.white.withAlpha(140))),
        ],
      ),
      gapH(10),
      if (players.isEmpty)
        const InfoNote('Your team has no players yet. Share the team link or add players from the team page.')
      else
        for (final p in players) ...[
          _PlayerTile(p: p, blocked: c.blockedReason(p), selected: c.picked.contains(p.memberId), onTap: () => c.togglePlayer(p)),
          gapH(8),
        ],
      if (players.length < d.squadMin && players.isNotEmpty) ...[
        gapH(8),
        InfoNote('This division needs at least ${d.squadMin} players. Add more players to ${t.name} first.'),
      ],
      if (c.isLast) ...[gapH(16), _Summary(c: c)],
    ];
  }

  // ─── Step 4: payment ──────────────────────────────────────────

  List<Widget> _paymentStep(RegisterTeamController c, RegOptions o) {
    final p = o.payment;
    return [
      StepIntro(title: 'Pay the entry fee', subtitle: 'The organiser checks your payment and then confirms your team.'),
      gapH(16),
      _Summary(c: c),
      gapH(16),
      if (p == null)
        const InfoNote('The organiser has not added payment details. Contact them before registering.')
      else ...[
        if (p.acceptCash) ...[
          OptionCard(
            key: const ValueKey('reg-pay-upi'),
            title: 'Pay by UPI',
            subtitle: 'Pay now and add the UTR number or a screenshot.',
            icon: Icons.qr_code_2_rounded,
            selected: c.method.value == 'UPI',
            onTap: () => c.method.value = 'UPI',
          ),
          gapH(10),
          OptionCard(
            key: const ValueKey('reg-pay-cash'),
            title: 'Pay cash to the organiser',
            subtitle: 'Your team is confirmed after the organiser gets the cash.',
            icon: Icons.payments_rounded,
            selected: c.method.value == 'CASH',
            onTap: () => c.method.value = 'CASH',
          ),
          gapH(16),
        ],
        if (c.method.value == 'UPI') ...[
          FormCard(
            padding: EdgeInsets.all(SizeConfig.r(16)),
            child: Column(
              children: [
                Text(rupees(c.fee), style: tfStyle(30, weight: FontWeight.w900)),
                Text('to ${p.upiName}', style: tfStyle(13, color: Colors.white.withAlpha(160))),
                if (p.qrUrl != null) ...[
                  gapH(14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                    child: Image.network(p.qrUrl!,
                        width: SizeConfig.r(190), height: SizeConfig.r(190), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ],
                gapH(14),
                GestureDetector(
                  key: const ValueKey('reg-copy-upi'),
                  onTap: c.copyUpi,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(10)),
                    decoration: BoxDecoration(color: Colors.black.withAlpha(90), borderRadius: BorderRadius.circular(SizeConfig.r(10))),
                    child: Row(
                      children: [
                        Expanded(child: Text(p.upiId, overflow: TextOverflow.ellipsis, style: tfStyle(14.5, weight: FontWeight.w800))),
                        Icon(Icons.copy_rounded, size: SizeConfig.r(16), color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                gapH(10),
                SizedBox(width: double.infinity, child: SmallButton(key: const ValueKey('reg-upi-app'), label: 'Pay with a UPI app', onTap: c.payWithUpiApp)),
                if (p.note != null) ...[
                  gapH(10),
                  Text(p.note!, textAlign: TextAlign.center, style: tfStyle(12.5, color: Colors.white.withAlpha(150), height: 1.4)),
                ],
              ],
            ),
          ),
          gapH(20),
          const FormLabel('UTR number', hint: 'The 12-digit reference in your UPI app\'s payment details.'),
          FieldTextInput(
            key: const ValueKey('reg-utr'),
            controller: c.utrCtrl,
            hint: 'e.g. 412345678901',
            maxLength: 30,
            textCapitalization: TextCapitalization.characters,
          ),
          gapH(16),
          const FormLabel('Payment screenshot', optional: true),
          Align(
            alignment: Alignment.centerLeft,
            child: UploadBox(
              key: const ValueKey('reg-proof'),
              slot: c.proof,
              aspectRatio: 1,
              width: SizeConfig.w(130),
              label: 'Add screenshot',
              icon: Icons.receipt_long_rounded,
              onPick: c.pickProof,
              onRemove: () => c.proof.file.value = null,
            ),
          ),
        ] else
          InfoNote('Pay ${rupees(c.fee)} in cash to the organiser. Your place is confirmed only after they mark it paid.', icon: Icons.payments_rounded),
      ],
    ];
  }
}

// ─── Pieces ─────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  final int step;
  final int of;
  final VoidCallback onBack;
  const _TopBar({required this.title, required this.step, required this.of, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(4)),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                key: const ValueKey('reg-back'),
                onTap: onBack,
                child: Container(
                  width: SizeConfig.r(40),
                  height: SizeConfig.r(40),
                  decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
                  child: Icon(Icons.arrow_back_rounded, size: SizeConfig.r(18), color: Colors.white),
                ),
              ),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REGISTER TEAM · STEP $step OF $of',
                        style: tfStyle(10.5, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.6)),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(15, weight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          gapH(12),
          Row(
            children: [
              for (var i = 1; i <= of; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i == of ? 0 : SizeConfig.w(4)),
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.primary : Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const _Message({required this.title, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(onPressed: Get.back, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.zero,
          child: EmptyCard(
            icon: Icons.how_to_reg_rounded,
            title: title,
            message: message,
            actions: [
              if (onRetry != null) SmallButton(label: 'Try again', onTap: onRetry!) else SmallButton(label: 'Back', filled: false, onTap: Get.back),
            ],
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

class _Selectable extends StatelessWidget {
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  final Widget child;
  const _Selectable({super.key, required this.selected, required this.onTap, required this.child, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(SizeConfig.r(12)),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(25) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(color: selected ? AppColors.primary : Colors.white.withAlpha(14), width: selected ? 2 : 1),
        ),
        child: Opacity(opacity: disabled ? 0.45 : 1, child: child),
      ),
    );
  }
}

Widget _avatar(String? url, double size, {double radius = 100}) => ClipRRect(
      borderRadius: BorderRadius.circular(SizeConfig.r(radius)),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A)))
            : ColoredBox(color: const Color(0xFF2A2A2A), child: Icon(Icons.person_rounded, color: Colors.white.withAlpha(80), size: size * 0.55)),
      ),
    );

class _TeamTile extends StatelessWidget {
  final RegTeam team;
  final MyEntry? entry;
  final bool selected;
  final VoidCallback onTap;
  const _TeamTile({required this.team, required this.entry, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Selectable(
      key: ValueKey('reg-team-${team.code}'),
      selected: selected,
      disabled: entry != null,
      onTap: onTap,
      child: Row(
        children: [
          _avatar(team.logoUrl, SizeConfig.r(50), radius: 12),
          SizedBox(width: SizeConfig.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(15.5, weight: FontWeight.w800)),
                Text(
                  entry != null
                      ? 'Already registered · ${entryStatusLabel(entry!.status)}'
                      : '${_roleLabels[team.myRole] ?? 'Manager'} · ${team.players.length} ${team.players.length == 1 ? 'player' : 'players'}',
                  style: tfStyle(12.5, color: Colors.white.withAlpha(150)),
                ),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle_rounded, color: AppColors.primary, size: SizeConfig.r(22)),
        ],
      ),
    );
  }
}

class _DivisionTile extends StatelessWidget {
  final RegDivision d;
  final bool selected;
  final VoidCallback onTap;
  const _DivisionTile({required this.d, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final squad = d.squadMin == d.squadMax ? '${d.squadMin} players' : '${d.squadMin}-${d.squadMax} players';
    return _Selectable(
      key: ValueKey('reg-division-${d.id}'),
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: tfStyle(15.5, weight: FontWeight.w800)),
                gapH(2),
                Text([if (d.ageLabel != null) d.ageLabel!, squad, d.entryFee > 0 ? rupees(d.entryFee) : 'Free entry'].join(' · '),
                    style: tfStyle(12.5, color: Colors.white.withAlpha(160))),
                gapH(4),
                Text(
                  d.isFull ? 'Full. New teams join the waitlist.' : '${d.placesLeft} of ${d.maxTeams} places left',
                  style: tfStyle(12, weight: FontWeight.w700, color: d.isFull ? _amber : AppColors.primary),
                ),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle_rounded, color: AppColors.primary, size: SizeConfig.r(22)),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final RegPlayer p;
  final String? blocked;
  final bool selected;
  final VoidCallback onTap;
  const _PlayerTile({required this.p, required this.blocked, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (p.age != null) 'Age ${p.age}',
      if (p.jerseyNumber != null) '#${p.jerseyNumber}',
      if (p.position != null) p.position!.replaceAll('_', ' ').toLowerCase().capitalizeFirst!,
      if (p.isGuest) 'Added by coach',
    ].join(' · ');
    return _Selectable(
      key: ValueKey('reg-player-${p.memberId}'),
      selected: selected,
      disabled: blocked != null,
      onTap: onTap,
      child: Row(
        children: [
          _avatar(p.photoUrl, SizeConfig.r(40)),
          SizedBox(width: SizeConfig.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14.5, weight: FontWeight.w700)),
                Text(blocked ?? details, style: tfStyle(12, color: blocked != null ? _amber : Colors.white.withAlpha(140))),
              ],
            ),
          ),
          Icon(
            blocked != null ? Icons.block_rounded : (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
            color: selected ? AppColors.primary : Colors.white.withAlpha(90),
            size: SizeConfig.r(22),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final RegisterTeamController c;
  const _Summary({required this.c});

  @override
  Widget build(BuildContext context) {
    final d = c.division!;
    Widget row(String k, String v) => Padding(
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(4)),
          child: Row(
            children: [
              Text(k, style: tfStyle(13, color: Colors.white.withAlpha(140))),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(child: Text(v, textAlign: TextAlign.right, style: tfStyle(13.5, weight: FontWeight.w700))),
            ],
          ),
        );
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      child: Column(
        children: [
          row('Team', c.team!.name),
          row('Division', d.name),
          row('Squad', '${c.picked.length} players'),
          row('Entry fee', d.entryFee > 0 ? rupees(d.entryFee) : 'Free'),
          if (d.isFull) ...[
            gapH(8),
            const InfoNote('This division is full. Your team goes on the waitlist and moves up if a place opens.', icon: Icons.hourglass_top_rounded),
          ],
        ],
      ),
    );
  }
}

String entryStatusLabel(String s) => switch (s) {
      'PENDING' => 'waiting for organiser',
      'APPROVED' => 'confirmed',
      'WAITLISTED' => 'on the waitlist',
      'REJECTED' => 'not accepted',
      'WITHDRAWN' => 'withdrawn',
      _ => s.toLowerCase(),
    };
