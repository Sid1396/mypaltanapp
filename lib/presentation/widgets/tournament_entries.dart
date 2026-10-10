import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../data/models/entry.dart';
import '../../data/models/tournament.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/tournament_controller.dart';
import 'create_tournament_steps.dart' show rupees;
import 'tournament_form_widgets.dart';

const _amber = Color(0xFFFFB74D);

Color _statusColor(String s) => switch (s) {
      'APPROVED' => AppColors.positive,
      'PENDING' || 'WAITLISTED' => _amber,
      _ => AppColors.negative,
    };

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(8), vertical: SizeConfig.h(3)),
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
        child: Text(text, style: tfStyle(10.5, weight: FontWeight.w800, color: color).copyWith(letterSpacing: 0.4)),
      );
}

Widget _logo(String? url, double size) => ClipRRect(
      borderRadius: BorderRadius.circular(SizeConfig.r(10)),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A)))
            : ColoredBox(color: const Color(0xFF2A2A2A), child: Icon(Icons.shield_rounded, color: Colors.white.withAlpha(70), size: size * 0.5)),
      ),
    );

// ─── The user's own registration ────────────────────────────────

/// Shows the team's registration status, with Withdraw while it is not yet confirmed.
class MyEntryCard extends GetView<TournamentController> {
  final MyEntry e;
  final Tournament t;
  const MyEntryCard({super.key, required this.e, required this.t});

  @override
  Widget build(BuildContext context) {
    final division = t.divisions.firstWhereOrNull((d) => d.id == e.divisionId)?.name;
    final (String title, String body) = switch (e.status) {
      'APPROVED' => ('Your team is in!', '${e.teamName} has a confirmed place${division != null ? ' in $division' : ''}.'),
      'WAITLISTED' => ('On the waitlist', '${division ?? 'The division'} is full. ${e.teamName} moves up if a team drops out.'),
      'REJECTED' => ('Registration not accepted', e.rejectReason != null ? 'The organiser said: "${e.rejectReason}". You can fix it and register again.' : 'You can register again.'),
      _ => (
          'Waiting for the organiser',
          e.paymentMethod == 'CASH'
              ? 'Pay ${rupees(e.amount)} in cash to the organiser. They confirm ${e.teamName} after that.'
              : 'The organiser checks your ${e.amount > 0 ? 'payment' : 'registration'} and confirms ${e.teamName}.',
        ),
    };
    final color = _statusColor(e.status);
    return Container(
      key: const ValueKey('my-entry-card'),
      padding: EdgeInsets.all(SizeConfig.r(14)),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(e.status == 'APPROVED' ? Icons.verified_rounded : (e.status == 'REJECTED' ? Icons.error_outline_rounded : Icons.hourglass_top_rounded),
                  color: color, size: SizeConfig.r(20)),
              SizedBox(width: SizeConfig.w(8)),
              Expanded(child: Text(title, style: tfStyle(15, weight: FontWeight.w800))),
            ],
          ),
          gapH(6),
          Text(body, style: tfStyle(12.5, color: Colors.white.withAlpha(190), height: 1.4)),
          gapH(4),
          Text('${e.players} players${e.amount > 0 ? ' · ${rupees(e.amount)} ${e.paymentMethod == 'CASH' ? 'cash' : 'UPI'}' : ''}',
              style: tfStyle(12, color: Colors.white.withAlpha(130))),
          if (e.status == 'PENDING' || e.status == 'WAITLISTED') ...[
            gapH(10),
            Obx(() => GestureDetector(
                  key: const ValueKey('entry-withdraw'),
                  onTap: controller.busyEntry.value == e.id ? null : () => controller.withdraw(e),
                  child: Text(controller.busyEntry.value == e.id ? 'Withdrawing…' : 'Withdraw registration',
                      style: tfStyle(13, weight: FontWeight.w700, color: AppColors.negative)),
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Teams tab ──────────────────────────────────────────────────

class TeamsTabBody extends GetView<TournamentController> {
  final Tournament t;
  const TeamsTabBody({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (t.isDraft) return _empty('Publish the tournament to start taking team registrations.');
      if (!controller.entriesLoaded.value) {
        return Padding(
          padding: EdgeInsets.only(top: SizeConfig.h(30)),
          child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        );
      }
      final all = controller.entries;
      final mine = t.isOwner ? null : controller.myEntry;
      if (all.isEmpty && mine == null) {
        return _empty(t.isOwner
            ? 'Share the tournament link with captains and coaches. Their registrations show here, and you confirm each team once you receive its fee.'
            : 'Confirmed teams appear here.');
      }
      final pending = all.where((e) => e.status == 'PENDING').toList();
      final waiting = all.where((e) => e.status == 'WAITLISTED').toList();
      final closed = all.where((e) => e.status == 'REJECTED' || e.status == 'WITHDRAWN').toList();
      final divisions = t.divisions.isEmpty ? [null] : t.divisions;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mine != null) ...[MyEntryCard(e: mine, t: t), gapH(20)],
          if (pending.isNotEmpty) ...[
            _heading('WAITING FOR YOU', pending.length, hint: 'Check the payment in your UPI app, then confirm.'),
            for (final e in pending) _EntryCard(e: e, owner: true),
            gapH(12),
          ],
          if (waiting.isNotEmpty) ...[
            _heading('WAITLIST', waiting.length, hint: 'These divisions are full. Confirm a team if a place opens.'),
            for (final e in waiting) _EntryCard(e: e, owner: true),
            gapH(12),
          ],
          for (final d in divisions) ...[
            Builder(builder: (_) {
              final confirmed = all.where((e) => e.status == 'APPROVED' && (d == null || e.divisionId == d.id)).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heading(d == null ? 'CONFIRMED' : d.name.toUpperCase(), confirmed.length, of: d?.maxTeams ?? t.maxTeams),
                  if (confirmed.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: SizeConfig.h(12)),
                      child: Text('No confirmed teams yet.', style: tfStyle(13, color: Colors.white.withAlpha(120))),
                    )
                  else
                    for (final e in confirmed) _EntryCard(e: e, owner: t.isOwner),
                  gapH(8),
                ],
              );
            }),
          ],
          if (closed.isNotEmpty) ...[
            _heading('NOT ACCEPTED OR WITHDRAWN', closed.length),
            for (final e in closed) _EntryCard(e: e, owner: true),
          ],
        ],
      );
    });
  }

  Widget _empty(String message) => FormCard(
        padding: EdgeInsets.all(SizeConfig.r(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.shield_outlined, color: Colors.white.withAlpha(140), size: SizeConfig.r(20)),
              SizedBox(width: SizeConfig.w(10)),
              Text('No teams yet', style: tfStyle(15, weight: FontWeight.w700)),
            ]),
            gapH(8),
            Text(message, style: tfStyle(13, color: Colors.white.withAlpha(140), height: 1.45)),
          ],
        ),
      );

  Widget _heading(String text, int count, {int? of, String? hint}) => Padding(
        padding: EdgeInsets.only(bottom: SizeConfig.h(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$text · ${of != null ? '$count/$of' : count}', style: tfStyle(12, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.6)),
            if (hint != null) Text(hint, style: tfStyle(12, color: Colors.white.withAlpha(120))),
          ],
        ),
      );
}

class _EntryCard extends GetView<TournamentController> {
  final TournamentEntry e;
  final bool owner;
  const _EntryCard({required this.e, required this.owner});

  @override
  Widget build(BuildContext context) => Obx(() => _build(controller.expanded.contains(e.id)));

  Widget _build(bool open) {
    final actionable = owner && (e.status == 'PENDING' || e.status == 'WAITLISTED');
    final payment = e.paymentMethod == null
        ? null
        : e.amount == 0 || e.paymentMethod == 'NONE'
            ? 'Free entry'
            : e.paymentMethod == 'CASH'
                ? '${rupees(e.amount)} · Cash'
                : '${rupees(e.amount)} · UPI${e.utr != null ? ' · UTR ${e.utr}' : ''}';
    return Container(
      key: ValueKey('entry-${e.teamCode}'),
      margin: EdgeInsets.only(bottom: SizeConfig.h(10)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.toggleExpanded(e.id),
            child: Padding(
              padding: EdgeInsets.all(SizeConfig.r(12)),
              child: Row(
                children: [
                  _logo(e.logoUrl, SizeConfig.r(44)),
                  SizedBox(width: SizeConfig.w(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(15, weight: FontWeight.w800)),
                        Text([if (e.division != null) e.division!, '${e.squad.length} players'].join(' · '), style: tfStyle(12, color: Colors.white.withAlpha(140))),
                      ],
                    ),
                  ),
                  if (owner && e.status != 'APPROVED') ...[_StatusPill(e.status == 'PENDING' ? 'NEW' : e.status, _statusColor(e.status)), SizedBox(width: SizeConfig.w(4))],
                  Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.white.withAlpha(110)),
                ],
              ),
            ),
          ),
          if (owner && (payment != null || e.registeredBy != null))
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(12), 0, SizeConfig.w(12), SizeConfig.h(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (payment != null) SelectableText(payment, style: tfStyle(13, weight: FontWeight.w700)),
                        if (e.registeredBy != null)
                          GestureDetector(
                            onTap: e.registeredPhone != null ? () => controller.callNumber(e.registeredPhone!) : null,
                            child: Text('By ${e.registeredBy}${e.registeredPhone != null ? ' · ${e.registeredPhone}' : ''}',
                                style: tfStyle(12, color: Colors.white.withAlpha(140))),
                          ),
                        if (e.rejectReason != null && e.status == 'REJECTED')
                          Text('Reason: ${e.rejectReason}', style: tfStyle(12, color: AppColors.negative.withAlpha(220))),
                      ],
                    ),
                  ),
                  if (e.proofUrl != null)
                    GestureDetector(
                      key: ValueKey('entry-proof-${e.teamCode}'),
                      onTap: () => _showProof(e),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(SizeConfig.r(8)),
                        child: Image.network(e.proofUrl!, width: SizeConfig.r(48), height: SizeConfig.r(48), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => SizedBox(width: SizeConfig.r(48), height: SizeConfig.r(48))),
                      ),
                    ),
                ],
              ),
            ),
          if (open) ...[
            Divider(height: 1, color: Colors.white.withAlpha(14)),
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(12), SizeConfig.h(8), SizeConfig.w(12), SizeConfig.h(8)),
              child: Column(
                children: [
                  for (final p in e.squad)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: SizeConfig.h(4)),
                      child: Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: SizeConfig.r(28),
                              height: SizeConfig.r(28),
                              child: p.photoUrl != null
                                  ? Image.network(p.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A)))
                                  : const ColoredBox(color: Color(0xFF2A2A2A)),
                            ),
                          ),
                          SizedBox(width: SizeConfig.w(10)),
                          Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(13.5, weight: FontWeight.w600))),
                          if (p.age != null) Text('Age ${p.age}', style: tfStyle(12, color: Colors.white.withAlpha(130))),
                          if (p.jerseyNumber != null) ...[
                            SizedBox(width: SizeConfig.w(10)),
                            Text('#${p.jerseyNumber}', style: tfStyle(12.5, weight: FontWeight.w800, color: AppColors.primary)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (actionable)
            Obx(() {
              final busy = controller.busyEntry.value == e.id;
              return Padding(
                padding: EdgeInsets.fromLTRB(SizeConfig.w(12), 0, SizeConfig.w(12), SizeConfig.h(12)),
                child: busy
                    ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AppColors.primary)))
                    : Row(
                        children: [
                          Expanded(
                            child: _ActionButton(key: ValueKey('entry-reject-${e.teamCode}'), label: 'Reject', onTap: () => controller.reject(e)),
                          ),
                          SizedBox(width: SizeConfig.w(10)),
                          Expanded(
                            child: _ActionButton(
                                key: ValueKey('entry-approve-${e.teamCode}'), label: 'Confirm team', filled: true, onTap: () => controller.approve(e)),
                          ),
                        ],
                      ),
              );
            }),
        ],
      ),
    );
  }

  void _showProof(TournamentEntry e) {
    Get.dialog(
      GestureDetector(
        onTap: Get.back,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: InteractiveViewer(child: Image.network(e.proofUrl!, fit: BoxFit.contain)),
        ),
      ),
      useSafeArea: false,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _ActionButton({super.key, required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(10)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(SizeConfig.r(10)),
            border: Border.all(color: filled ? AppColors.primary : Colors.white.withAlpha(45)),
          ),
          child: Text(label, style: tfStyle(13.5, weight: FontWeight.w700)),
        ),
      );
}
