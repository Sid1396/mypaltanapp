import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/manage_players_controller.dart';
import '../widgets/create_tournament_steps.dart' show fmtDate;
import '../widgets/home_widgets.dart' show SmallButton;
import '../widgets/tournament_form_widgets.dart';

/// Coach's squad for a tournament registered on mypaltan.com — the same as the coach page on the website:
/// player link for parents, children waiting for approval, and the squad.
class ManagePlayersPage extends StatelessWidget {
  const ManagePlayersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ManagePlayersController());
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Obx(() => Text(c.teamName.value.isEmpty ? 'Players' : c.teamName.value, style: tfStyle(18, weight: FontWeight.w800))),
      ),
      body: Obx(() {
        if (c.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (c.error.value != null && c.members.isEmpty && c.teamName.value.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(SizeConfig.r(24)),
              child: Text(c.error.value!, textAlign: TextAlign.center, style: tfStyle(14, color: Colors.white.withAlpha(180))),
            ),
          );
        }
        final waiting = c.waiting, squad = c.squad;
        final day = fmtDate(DateTime.tryParse(c.startDate.value));
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: c.load,
          child: ListView(
            padding: EdgeInsets.all(SizeConfig.r(16)),
            children: [
              Text('${c.tournamentName.value} · ${c.division.value}', style: tfStyle(13, color: Colors.white.withAlpha(160))),
              gapH(14),
              if (!c.approved)
                const InfoNote('MyPaltan is checking your payment. Your player link will appear here once your team is approved.',
                    icon: Icons.hourglass_top_rounded)
              else ...[
                FormCard(
                  padding: EdgeInsets.all(SizeConfig.r(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Player link for parents', style: tfStyle(14, weight: FontWeight.w800)),
                      gapH(4),
                      Text('Parents add their child here; you approve them below.', style: tfStyle(12.5, color: Colors.white.withAlpha(160))),
                      gapH(10),
                      Text(c.playerLink, style: tfStyle(12.5, color: AppColors.primary)),
                      gapH(12),
                      Row(
                        children: [
                          Expanded(child: SmallButton(key: const ValueKey('players-share'), label: 'Share on WhatsApp', onTap: c.shareWhatsApp)),
                          SizedBox(width: SizeConfig.w(10)),
                          Expanded(child: SmallButton(key: const ValueKey('players-copy'), label: 'Copy link', onTap: c.copyLink)),
                        ],
                      ),
                    ],
                  ),
                ),
                gapH(20),
                _Heading('Waiting for you (${waiting.length})', color: Colors.amber),
                if (waiting.isEmpty)
                  _Empty('No new players. Share the player link with parents.')
                else
                  for (final m in waiting)
                    _PlayerCard(
                      m: m,
                      day: day,
                      c: c,
                      actions: c.locked
                          ? null
                          : Row(
                              children: [
                                Expanded(
                                    child: _Btn(
                                        label: 'Approve', filled: true, busy: c.busy.value == m.id, onTap: () => c.act('APPROVE', m))),
                                SizedBox(width: SizeConfig.w(10)),
                                Expanded(child: _Btn(label: 'Decline', busy: false, onTap: () => c.act('REJECT', m))),
                              ],
                            ),
                    ),
                gapH(18),
                _Heading('Squad (${squad.length} of ${c.paidPlayers.value})'),
                if (squad.isEmpty)
                  _Empty('No players approved yet.')
                else
                  for (final m in squad)
                    _PlayerCard(
                      m: m,
                      day: day,
                      c: c,
                      actions: c.locked
                          ? null
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () => Get.defaultDialog(
                                  title: 'Remove ${m.name}?',
                                  middleText: '${m.name} will be taken out of the squad.',
                                  textConfirm: 'Remove',
                                  textCancel: 'Cancel',
                                  confirmTextColor: Colors.white,
                                  buttonColor: AppColors.negative,
                                  onConfirm: () {
                                    Get.back();
                                    c.act('REMOVE', m);
                                  },
                                ),
                                child: Text(c.busy.value == m.id ? 'Removing…' : 'Remove',
                                    style: tfStyle(13, weight: FontWeight.w700, color: AppColors.negative)),
                              ),
                            ),
                    ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  final Color? color;
  const _Heading(this.text, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: SizeConfig.h(8)),
        child: Text(text.toUpperCase(), style: tfStyle(11.5, weight: FontWeight.w800, color: color ?? Colors.white.withAlpha(160)).copyWith(letterSpacing: 0.6)),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: SizeConfig.h(6)),
        child: Text(text, style: tfStyle(13, color: Colors.white.withAlpha(120))),
      );
}

class _Btn extends StatelessWidget {
  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback onTap;
  const _Btn({required this.label, this.filled = false, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(11)),
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(SizeConfig.r(12)),
            border: filled ? null : Border.all(color: Colors.white.withAlpha(60)),
          ),
          child: busy
              ? SizedBox(width: SizeConfig.r(16), height: SizeConfig.r(16), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: tfStyle(13.5, weight: FontWeight.w800)),
        ),
      );
}

class _PlayerCard extends StatelessWidget {
  final SquadMember m;
  final String day;
  final ManagePlayersController c;
  final Widget? actions;
  const _PlayerCard({required this.m, required this.day, required this.c, this.actions});

  @override
  Widget build(BuildContext context) {
    final born = fmtDate(DateTime.tryParse(m.birthdate ?? ''));
    return Container(
      margin: EdgeInsets.only(bottom: SizeConfig.h(10)),
      padding: EdgeInsets.all(SizeConfig.r(12)),
      decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(SizeConfig.r(14))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: Container(
                  width: SizeConfig.r(52),
                  height: SizeConfig.r(52),
                  color: Colors.white.withAlpha(20),
                  child: m.photoUrl != null
                      ? Image.network(m.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white38))
                      : const Icon(Icons.person_rounded, color: Colors.white38),
                ),
              ),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m.name}${m.jerseyNumber != null ? '  #${m.jerseyNumber}' : ''}', style: tfStyle(15, weight: FontWeight.w800)),
                    gapH(2),
                    Text([if (m.age != null) '${m.age} on $day', if (born.isNotEmpty) 'born $born'].join(' · '),
                        style: tfStyle(12.5, color: Colors.white.withAlpha(170))),
                    if (m.parentPhone != null) ...[
                      gapH(4),
                      GestureDetector(
                        onTap: () => c.callParent(m.parentPhone!),
                        child: Text('Parent +91 ${m.parentPhone}', style: tfStyle(12.5, weight: FontWeight.w700, color: AppColors.primary)),
                      ),
                    ],
                    if (m.joined != null) ...[gapH(2), Text('Added ${m.joined}', style: tfStyle(11.5, color: Colors.white.withAlpha(110)))],
                  ],
                ),
              ),
            ],
          ),
          if (actions != null) ...[gapH(12), actions!],
        ],
      ),
    );
  }
}
