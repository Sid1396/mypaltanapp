import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../data/models/match.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/match_controller.dart';
import '../widgets/cricket_scorecard.dart';
import '../widgets/form_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/tournament_fixtures.dart' show fmtFixtureDay, fmtFixtureTime;
import '../widgets/tournament_form_widgets.dart';

class MatchPage extends GetView<MatchController> {
  const MatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Obx(() {
          final m = c.match.value;
          if (c.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          if (m == null) {
            return Center(
              child: EmptyCard(icon: Icons.sports_cricket, title: 'Match', message: c.error.value ?? 'Could not load the match.', actions: [
                SmallButton(label: 'Try again', onTap: c.load),
              ]),
            );
          }
          final live = m.live;
          final showScore = live != null && (live['innings'] as List? ?? []).isNotEmpty;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(SizeConfig.w(12), SizeConfig.h(6), SizeConfig.w(20), 0),
                child: Row(children: [
                  IconButton(key: const ValueKey('match-back'), onPressed: Get.back, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                  Expanded(
                    child: Text('${m.tournamentName} · ${m.division}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(13, color: Colors.white.withAlpha(160))),
                  ),
                  if (m.status == 'LIVE')
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(8), vertical: SizeConfig.h(3)),
                      decoration: BoxDecoration(color: AppColors.negative, borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                      child: Text('LIVE', style: tfStyle(10.5, weight: FontWeight.w900)),
                    ),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: c.load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(8), SizeConfig.w(20), SizeConfig.h(24)),
                    children: [
                      _Teams(m: m),
                      gapH(14),
                      if (showScore) ...[
                        LiveScoreHeader(live: live, teamName: m.teamName, fill: m.fill),
                        gapH(14),
                        Row(children: [
                          for (final l in const [(0, 'Live'), (1, 'Scorecard'), (2, 'Commentary')])
                            Padding(
                              padding: EdgeInsets.only(right: SizeConfig.w(8)),
                              child: GestureDetector(
                                key: ValueKey('match-tab-${l.$1}'),
                                onTap: () => c.tab.value = l.$1,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(8)),
                                  decoration: BoxDecoration(
                                    color: c.tab.value == l.$1 ? AppColors.primary : const Color(0xFF1A1A1A),
                                    borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                                  ),
                                  child: Text(l.$2, style: tfStyle(13, weight: FontWeight.w700)),
                                ),
                              ),
                            ),
                        ]),
                        gapH(14),
                        switch (c.tab.value) {
                          0 => live['current'] is Map
                              ? CurrentPlayers(current: Map<String, dynamic>.from(live['current'] as Map))
                              : Commentary(live: live),
                          1 => Scorecard(live: live, teamName: m.teamName),
                          _ => Commentary(live: live),
                        },
                      ] else
                        FormCard(
                          padding: EdgeInsets.all(SizeConfig.r(16)),
                          child: Text(
                            m.tossWinner != null
                                ? '${m.teamName(m.tossWinner)} won the toss and chose to ${m.tossDecision == 'BAT' ? 'bat' : 'bowl'}.'
                                : 'The match has not started yet.',
                            style: tfStyle(14, color: Colors.white.withAlpha(190)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (m.sport == 'CRICKET' && m.status != 'COMPLETED')
                StepBottomButton(
                  key: const ValueKey('match-score'),
                  label: !m.canScore ? 'Score this match' : (m.hasSetup ? (m.status == 'LIVE' ? 'Continue scoring' : 'Start scoring') : 'Toss & Playing XI'),
                  onPressed: c.score,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _Teams extends StatelessWidget {
  final MatchDetail m;
  const _Teams({required this.m});

  @override
  Widget build(BuildContext context) {
    Widget team(MatchTeam? t) => Expanded(
          child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(SizeConfig.r(14)),
              child: SizedBox(
                width: SizeConfig.r(56),
                height: SizeConfig.r(56),
                child: t?.logoUrl != null
                    ? Image.network(t!.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A)))
                    : const ColoredBox(color: Color(0xFF2A2A2A)),
              ),
            ),
            gapH(6),
            Text(t?.name ?? 'To be decided', textAlign: TextAlign.center, maxLines: 2, style: tfStyle(14, weight: FontWeight.w800)),
          ]),
        );
    final at = m.scheduledAt;
    return Column(children: [
      Text(
        [m.isKnockout ? (m.label ?? 'Knockout') : 'Round ${m.roundNo}', if (at != null) '${fmtFixtureDay(at)} · ${fmtFixtureTime(at)}', 'Pitch ${m.pitch}'].join(' · '),
        style: tfStyle(12, color: Colors.white.withAlpha(150)),
      ),
      gapH(12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        team(m.home),
        Padding(padding: EdgeInsets.only(top: SizeConfig.h(18)), child: Text('vs', style: tfStyle(14, weight: FontWeight.w800, color: Colors.white.withAlpha(120)))),
        team(m.away),
      ]),
    ]);
  }
}
