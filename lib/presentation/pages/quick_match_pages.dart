import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../data/models/quick_match.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/quick_match_controller.dart';
import '../widgets/form_widgets.dart';
import '../widgets/onboarding_widgets.dart';
import '../widgets/tournament_form_widgets.dart';
import '../widgets/tournament_media_editors.dart' show SmallButtonLarge;
import '../widgets/tournament_stats.dart' show PlayerStatsView;

Widget _topButton(IconData icon, VoidCallback onTap, {Key? key}) => GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: SizeConfig.r(40),
        height: SizeConfig.r(40),
        decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
        child: Icon(icon, size: SizeConfig.r(18), color: Colors.white),
      ),
    );

// ─── Create ─────────────────────────────────────────────────────

class CreateQuickMatchPage extends GetView<CreateQuickMatchController> {
  const CreateQuickMatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), 0),
              child: Row(children: [_topButton(Icons.close_rounded, Get.back, key: const ValueKey('quick-create-close'))]),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(24)),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const StepIntro(
                    title: 'Quick match',
                    subtitle: 'Make the match, share the link in your group, pick two captains. Players join their team and you score it live.',
                  ),
                  gapH(24),
                  const FormLabel('Sport'),
                  Obx(() => ChoiceChips(
                        key: const ValueKey('quick-sport'),
                        options: [for (final s in Sports.all) (s.code, s.label)],
                        selected: c.sport.value,
                        onSelected: c.selectSport,
                      )),
                  gapH(20),
                  const FormLabel('Teams'),
                  Row(children: [
                    Expanded(
                        child: FieldTextInput(
                            key: const ValueKey('quick-home'),
                            controller: c.homeCtrl,
                            hint: 'Team A',
                            maxLength: 30,
                            textCapitalization: TextCapitalization.words)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10)),
                      child: Text('v', style: tfStyle(15, weight: FontWeight.w800, color: Colors.white.withAlpha(150))),
                    ),
                    Expanded(
                        child: FieldTextInput(
                            key: const ValueKey('quick-away'),
                            controller: c.awayCtrl,
                            hint: 'Team B',
                            maxLength: 30,
                            textCapitalization: TextCapitalization.words)),
                  ]),
                  gapH(20),
                  const FormLabel('Rules'),
                  FormCard(child: Obx(() => Column(children: _rules(c)))),
                  gapH(20),
                  const FormLabel('When'),
                  Obx(() => FieldPicker(
                        key: const ValueKey('quick-when'),
                        label: c.whenText,
                        filled: true,
                        icon: Icons.schedule_rounded,
                        onTap: () => c.pickWhen(context),
                      )),
                  gapH(20),
                  const FormLabel('Ground', optional: true),
                  FieldTextInput(
                    key: const ValueKey('quick-ground'),
                    controller: c.groundCtrl,
                    hint: 'e.g. St. Mary Turf, Charkop',
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                  ),
                  gapH(20),
                  const FormLabel('Are you playing?', hint: "If you play, you're the captain of your team. You can change captains later."),
                  Obx(() => ChoiceChips(
                        key: const ValueKey('quick-my-side'),
                        options: [
                          ('HOME', c.homeCtrl.text.trim().isEmpty ? 'Team A' : c.homeCtrl.text.trim()),
                          ('AWAY', c.awayCtrl.text.trim().isEmpty ? 'Team B' : c.awayCtrl.text.trim()),
                          ('', "I'm not playing"),
                        ],
                        selected: c.mySide.value,
                        onSelected: (v) => c.mySide.value = v,
                      )),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(8), SizeConfig.w(20), SizeConfig.h(16)),
              child: Obx(() => SizedBox(
                    width: double.infinity,
                    child: SmallButtonLarge(
                      key: const ValueKey('quick-create'),
                      label: c.saving.value ? 'Creating…' : 'Create match',
                      onTap: c.saving.value ? null : c.create,
                    ),
                  )),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rules(CreateQuickMatchController c) {
    switch (c.sport.value) {
      case 'CRICKET':
        return [
          NumberStepper(label: 'Overs per innings', value: c.overs.value, min: 1, max: 50, onChanged: c.setOvers),
          NumberStepper(label: 'Overs per bowler', value: c.oversPerBowler.value, min: 1, max: c.overs.value, onChanged: c.setOversPerBowler),
          SwitchRow(
            label: 'Last man stands',
            hint: 'The last batter can bat on alone',
            value: c.lastManStands.value,
            onChanged: (v) => c.lastManStands.value = v,
          ),
          SwitchRow(
            label: 'Free hit after a no-ball',
            value: c.freeHit.value,
            onChanged: (v) => c.freeHit.value = v,
          ),
          SwitchRow(
            label: 'Box out',
            hint: 'Out if the ball hits the roof',
            value: c.boxOut.value,
            onChanged: (v) => c.boxOut.value = v,
          ),
        ];
      case 'FOOTBALL':
        return [
          NumberStepper(label: 'Each half', hint: 'Minutes', value: c.halfMinutes.value, min: 1, max: 45, onChanged: (v) => c.halfMinutes.value = v),
        ];
      default:
        return [
          Padding(
            padding: EdgeInsets.symmetric(vertical: SizeConfig.h(8)),
            child: ChoiceChips(
              options: const [('SINGLES', 'Singles'), ('DOUBLES', 'Doubles')],
              selected: c.racketEvent.value,
              onSelected: (v) => c.racketEvent.value = v,
            ),
          ),
          NumberStepper(label: 'Points per game', value: c.pointsPerGame.value, min: 5, max: 30, onChanged: (v) => c.pointsPerGame.value = v),
          NumberStepper(
            label: 'Games',
            hint: 'Best of',
            value: c.games.value,
            min: 1,
            max: 5,
            step: 2,
            onChanged: (v) => c.games.value = v,
          ),
        ];
    }
  }
}

// ─── Match page ─────────────────────────────────────────────────

class QuickMatchPage extends GetView<QuickMatchController> {
  const QuickMatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Obx(() {
          final m = c.match.value;
          return Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(4)),
              child: Row(children: [
                _topButton(Icons.arrow_back_rounded, Get.back, key: const ValueKey('quick-back')),
                const Spacer(),
                if (m != null && !m.isCancelled) _topButton(Icons.ios_share_rounded, c.shareMatch, key: const ValueKey('quick-share')),
              ]),
            ),
            Expanded(
              child: m == null
                  ? Center(
                      child: c.isLoading.value
                          ? const CircularProgressIndicator(color: AppColors.primary)
                          : Padding(
                              padding: EdgeInsets.all(SizeConfig.w(24)),
                              child: Text(c.error.value ?? 'Could not load this match.',
                                  textAlign: TextAlign.center, style: tfStyle(14, color: Colors.white.withAlpha(170))),
                            ))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: c.load,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(8), SizeConfig.w(20), SizeConfig.h(32)),
                        children: _body(c, m),
                      ),
                    ),
            ),
          ]);
        }),
      ),
    );
  }

  List<Widget> _body(QuickMatchController c, QuickMatch m) {
    final sport = Sports.byCode(m.sport);
    final at = parseQuickTime(m.scheduledAt);
    final home = m.home, away = m.away;
    return [
      // Header: sport, teams, rules, time and place
      FormCard(
        padding: EdgeInsets.all(SizeConfig.r(16)),
        child: Column(children: [
          Row(children: [
            if (sport != null) Image.asset(sport.asset, height: SizeConfig.r(22)),
            SizedBox(width: SizeConfig.w(8)),
            Text('${m.games.length > 1 ? 'MATCH ${m.matchNo}' : 'QUICK MATCH'} · ${sport?.label.toUpperCase() ?? ''}',
                style: tfStyle(11.5, weight: FontWeight.w800, color: AppColors.primary)),
            const Spacer(),
            _StatusPill(m: m),
          ]),
          gapH(14),
          Row(children: [
            Expanded(child: Text(home?.name ?? 'Team A', textAlign: TextAlign.center, style: tfStyle(16, weight: FontWeight.w800))),
            if (m.started || m.isCompleted)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(8)),
                child: Text('${home == null ? '' : m.scoreOf(home)}  –  ${away == null ? '' : m.scoreOf(away)}', style: tfStyle(17, weight: FontWeight.w900)),
              )
            else
              Text('v', style: tfStyle(14, weight: FontWeight.w800, color: Colors.white.withAlpha(140))),
            Expanded(child: Text(away?.name ?? 'Team B', textAlign: TextAlign.center, style: tfStyle(16, weight: FontWeight.w800))),
          ]),
          if (m.resultText != null) ...[
            gapH(10),
            Text(m.fill(m.resultText), textAlign: TextAlign.center, style: tfStyle(14, weight: FontWeight.w800, color: AppColors.primary)),
          ],
          gapH(12),
          Text(
            [m.rulesText, if (at != null) fmtQuickTime(at), if (m.ground.isNotEmpty && m.ground != 'Quick match') m.ground].join('  ·  '),
            textAlign: TextAlign.center,
            style: tfStyle(12.5, color: Colors.white.withAlpha(160), height: 1.4),
          ),
          gapH(4),
          Text('Made by ${m.isCreator ? 'you' : m.creatorName}', style: tfStyle(12, color: Colors.white.withAlpha(110))),
        ]),
      ),
      gapH(16),

      // Main action
      if (m.isCancelled)
        const InfoNote('This match was cancelled.')
      else if (m.sessionEnded)
        const InfoNote('This session has ended. Well played!')
      else if (m.betweenMatches) ...[
        if (m.isCreator)
          SizedBox(
            width: double.infinity,
            child: SmallButtonLarge(key: const ValueKey('quick-next'), label: 'Next match', onTap: c.busy.value ? null : c.nextMatch),
          )
        else if (!m.inList && m.mySide == null)
          SizedBox(
            width: double.infinity,
            child: SmallButtonLarge(key: const ValueKey('quick-im-in'), label: c.busy.value ? 'Saving…' : "I'm in", onTap: c.busy.value ? null : c.join),
          )
        else
          InfoNote('Match ${m.matchNo} is over. ${m.creatorName} will set up the next one.'),
      ] else if (m.started || m.isCompleted)
        SizedBox(
          width: double.infinity,
          child: SmallButtonLarge(
            key: const ValueKey('quick-open-match'),
            label: m.isCompleted ? 'Scorecard' : (m.matchStatus == 'LIVE' ? 'Live score · Score this match' : 'Open match'),
            onTap: c.openMatch,
          ),
        )
      else ...[
        if (!m.inList && m.mySide == null && !m.isCreator)
          SizedBox(
            width: double.infinity,
            child: SmallButtonLarge(key: const ValueKey('quick-im-in'), label: c.busy.value ? 'Saving…' : "I'm in", onTap: c.busy.value ? null : c.join),
          )
        else if (m.isLead)
          SizedBox(
            width: double.infinity,
            child: SmallButtonLarge(
              key: const ValueKey('quick-start'),
              label: 'Start match',
              onTap: m.canStart ? c.openMatch : null,
            ),
          )
        else
          InfoNote(m.mySide != null
              ? "You're in ${m.sideOf(m.mySide!)?.name}. The captains start the match when everyone is here."
              : "You're in! ${m.creatorName} will make the teams."),
        if (m.isLead && !m.canStart) ...[
          gapH(8),
          Text('Each team needs at least ${m.minPlayers} player${m.minPlayers == 1 ? '' : 's'} to start.',
              textAlign: TextAlign.center, style: tfStyle(12, color: Colors.white.withAlpha(130))),
        ],
      ],

      // Scoring PIN (creator and captains)
      if (m.scoringPin != null && m.sessionOpen && !m.isCancelled) ...[
        gapH(16),
        FormCard(
          padding: EdgeInsets.all(SizeConfig.r(14)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Scoring PIN', style: tfStyle(12, weight: FontWeight.w700, color: Colors.white.withAlpha(150))),
                Text(m.scoringPin!, key: const ValueKey('quick-pin'), style: tfStyle(22, weight: FontWeight.w900)),
                Text(
                  m.sport == 'CRICKET'
                      ? 'Someone from the batting team scores. At the innings break, hand over to the other team.'
                      : 'Give it to whoever will score. Only one phone scores at a time.',
                  style: tfStyle(12, color: Colors.white.withAlpha(130), height: 1.35),
                ),
              ]),
            ),
            IconButton(onPressed: c.copyPin, icon: Icon(Icons.copy_rounded, color: AppColors.primary, size: SizeConfig.r(20))),
          ]),
        ),
      ],

      // Teams
      gapH(20),
      for (final s in m.sides) ...[
        _TeamCard(c: c, m: m, s: s),
        gapH(12),
      ],

      // Every match of the session; tap for its scorecard.
      if (m.anyPlayed) ...[
        gapH(8),
        Text('MATCHES', style: tfStyle(12, weight: FontWeight.w800, color: Colors.white.withAlpha(140))),
        gapH(8),
        if (m.table.any((t) => t.played > 0)) ...[
          _SessionTable(m: m),
          gapH(8),
        ],
        for (final g in m.games.reversed)
          if (g.started)
            Padding(
              padding: EdgeInsets.only(bottom: SizeConfig.h(8)),
              child: GestureDetector(
                key: ValueKey('quick-game-${g.matchNo}'),
                onTap: () => c.openGame(g.matchId),
                child: FormCard(
                  padding: EdgeInsets.all(SizeConfig.r(12)),
                  child: Row(children: [
                    Text('Match ${g.matchNo}', style: tfStyle(13, weight: FontWeight.w800, color: AppColors.primary)),
                    SizedBox(width: SizeConfig.w(10)),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          g.status == 'COMPLETED'
                              ? (g.resultText ?? 'Finished')
                              : 'LIVE · ${[for (final s in m.sides) '${s.short} ${g.summary['${s.entryId}'] ?? ''}'].join('  ')}',
                          style: tfStyle(13, weight: FontWeight.w600, color: g.status == 'COMPLETED' ? Colors.white : AppColors.negative),
                        ),
                        if (g.potmName != null) ...[
                          gapH(3),
                          Text('★ ${g.potmName}${g.potmReason == null ? '' : ' · ${g.potmReason}'}',
                              style: tfStyle(12, color: AppColors.primary.withAlpha(230))),
                        ],
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(120)),
                  ]),
                ),
              ),
            ),
        // Player stats for the whole session, the same as a tournament's: Player of the Session and the leaderboards.
        if (m.sport == 'CRICKET' || m.sport == 'FOOTBALL') ...[
          gapH(12),
          Text('STATS', style: tfStyle(12, weight: FontWeight.w800, color: Colors.white.withAlpha(140))),
          gapH(8),
          Obx(() => PlayerStatsView(stats: c.stats.value, loading: c.statsLoading.value, sport: m.sport, session: true)),
        ],
      ],

      // "I'm in" list: the creator puts each person in a team (or shuffles); everyone else sees who's where.
      if (m.isCreator && m.isOpen && m.people.isNotEmpty) ...[
        gapH(8),
        _MakeTeams(c: c, m: m),
      ] else if ((!m.started || m.betweenMatches) && !m.isCancelled && m.people.isNotEmpty) ...[
        gapH(8),
        Text("WHO'S IN (${m.people.length})", style: tfStyle(12, weight: FontWeight.w800, color: Colors.white.withAlpha(140))),
        gapH(8),
        Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
          for (final p in m.people)
            Container(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(8)),
              decoration: BoxDecoration(
                color: p.side == null ? const Color(0xFF242424) : AppColors.primary.withAlpha(35),
                borderRadius: BorderRadius.circular(SizeConfig.r(100)),
              ),
              child: Text(
                p.side == null ? p.name : '${p.name} · ${m.sideOf(p.side!)?.short ?? ''}',
                style: tfStyle(12.5, weight: FontWeight.w600),
              ),
            ),
        ]),
      ],

      // Creator / player options
      if (m.sessionOpen && !m.isCancelled && (m.isOpen || m.betweenMatches)) ...[
        gapH(24),
        if (m.isCreator && !m.anyPlayed)
          Center(
            child: TextButton(
              key: const ValueKey('quick-cancel'),
              onPressed: c.confirmCancel,
              child: Text('Cancel match', style: tfStyle(13.5, color: AppColors.negative)),
            ),
          )
        else if (m.isCreator)
          Center(
            child: TextButton(
              key: const ValueKey('quick-end'),
              onPressed: c.confirmEndSession,
              child: Text('End session', style: tfStyle(13.5, color: AppColors.negative)),
            ),
          )
        else if (m.inList && m.mySide == null && m.captainOf == null)
          Center(
            child: TextButton(
              key: const ValueKey('quick-leave'),
              onPressed: c.leave,
              child: Text("I can't make it", style: tfStyle(13.5, color: Colors.white.withAlpha(150))),
            ),
          ),
      ],
    ];
  }
}

class _StatusPill extends StatelessWidget {
  final QuickMatch m;
  const _StatusPill({required this.m});

  @override
  Widget build(BuildContext context) {
    final (label, color) = m.isCancelled
        ? ('Cancelled', AppColors.negative)
        : m.sessionEnded
            ? ('Finished', Colors.white.withAlpha(150))
            : m.betweenMatches
                ? ('Match ${m.matchNo} done', Colors.white.withAlpha(170))
                : m.started
                    ? ('LIVE', AppColors.negative)
                    : ('Open', AppColors.positive);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(4)),
      decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
      child: Text(label, style: tfStyle(11, weight: FontWeight.w800, color: color)),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final QuickMatchController c;
  final QuickMatch m;
  final QuickSide s;
  const _TeamCard({required this.c, required this.m, required this.s});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s.name, style: tfStyle(16, weight: FontWeight.w800))),
          Text(m.countText(s), style: tfStyle(13, weight: FontWeight.w800, color: AppColors.primary)),
        ]),
        gapH(4),
        Row(children: [
          Icon(Icons.star_rounded, size: SizeConfig.r(15), color: s.captainId == null ? Colors.white.withAlpha(90) : AppColors.primary),
          SizedBox(width: SizeConfig.w(4)),
          Expanded(
            child: Text(
              s.captainId == null ? 'No captain yet' : 'Captain: ${s.captainId == m.myUserId ? 'you' : s.captainName ?? ''}',
              style: tfStyle(13, color: Colors.white.withAlpha(170)),
            ),
          ),
          if (m.isCreator && m.isOpen)
            GestureDetector(
              key: ValueKey('quick-captain-${s.side}'),
              onTap: () => c.pickCaptain(s.side),
              child: Text(s.captainId == null ? 'Pick captain' : 'Change', style: tfStyle(13, weight: FontWeight.w700, color: AppColors.primary)),
            ),
        ]),
        if (s.players.isNotEmpty) ...[
          gapH(10),
          Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
            for (final p in s.players)
              Container(
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(6)),
                decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(SizeConfig.r(8))),
                child: Text(p.userId == m.myUserId ? '${p.name} (you)' : p.name, style: tfStyle(12.5, weight: FontWeight.w600)),
              ),
          ]),
        ],
      ]),
    );
  }
}

/// Played / won / lost per team across the session, with net run rate for cricket.
class _SessionTable extends StatelessWidget {
  final QuickMatch m;
  const _SessionTable({required this.m});

  @override
  Widget build(BuildContext context) {
    final cricket = m.sport == 'CRICKET';
    Widget cell(String t, {bool head = false, double w = 34}) => SizedBox(
          width: SizeConfig.w(w),
          child: Text(t,
              textAlign: TextAlign.center,
              style: tfStyle(head ? 11.5 : 13, weight: head ? FontWeight.w700 : FontWeight.w800, color: head ? Colors.white.withAlpha(130) : Colors.white)),
        );
    return FormCard(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(10)),
      child: Column(children: [
        Row(children: [
          const Expanded(child: SizedBox()),
          cell('P', head: true),
          cell('W', head: true),
          cell('L', head: true),
          if (m.table.any((t) => t.tied > 0)) cell('T', head: true),
          if (cricket) cell('NRR', head: true, w: 64),
        ]),
        for (final t in m.table)
          Padding(
            padding: EdgeInsets.only(top: SizeConfig.h(6)),
            child: Row(children: [
              Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w700))),
              cell('${t.played}'),
              cell('${t.won}'),
              cell('${t.lost}'),
              if (m.table.any((x) => x.tied > 0)) cell('${t.tied}'),
              if (cricket) cell(t.nrrText, w: 64),
            ]),
          ),
      ]),
    );
  }
}

/// Creator: the "I'm in" list with a team button per person, and Shuffle. Captains stay on their team.
class _MakeTeams extends StatelessWidget {
  final QuickMatchController c;
  final QuickMatch m;
  const _MakeTeams({required this.c, required this.m});

  @override
  Widget build(BuildContext context) {
    final captains = {
      for (final s in m.sides)
        if (s.captainId != null) s.captainId!: s
    };
    Widget pill(QuickPerson p, QuickSide s) {
      final on = p.side == s.side;
      return GestureDetector(
        key: ValueKey('quick-assign-${p.userId}-${s.side}'),
        onTap: c.busy.value ? null : () => c.assign(p, on ? null : s.side),
        child: Container(
          margin: EdgeInsets.only(left: SizeConfig.w(6)),
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(7)),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : const Color(0xFF242424),
            borderRadius: BorderRadius.circular(SizeConfig.r(100)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: SizeConfig.w(84)),
            child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(12, weight: FontWeight.w800)),
          ),
        ),
      );
    }

    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text("WHO'S IN (${m.people.length})", style: tfStyle(12, weight: FontWeight.w800, color: Colors.white.withAlpha(140)))),
          GestureDetector(
            key: const ValueKey('quick-shuffle'),
            onTap: c.busy.value ? null : c.confirmShuffle,
            child: Row(children: [
              Icon(Icons.shuffle_rounded, size: SizeConfig.r(16), color: AppColors.primary),
              SizedBox(width: SizeConfig.w(4)),
              Text('Shuffle teams', style: tfStyle(13, weight: FontWeight.w700, color: AppColors.primary)),
            ]),
          ),
        ]),
        gapH(4),
        Text('Tap a team to put someone in it. Tap again to take them out.', style: tfStyle(12, color: Colors.white.withAlpha(120))),
        gapH(8),
        for (final p in m.people)
          Padding(
            padding: EdgeInsets.symmetric(vertical: SizeConfig.h(5)),
            child: Row(children: [
              Expanded(
                child: Text(p.userId == m.myUserId ? '${p.name} (you)' : p.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w600)),
              ),
              if (captains[p.userId] != null)
                Text('Captain · ${captains[p.userId]!.name}', style: tfStyle(12, weight: FontWeight.w700, color: AppColors.primary))
              else
                for (final s in m.sides) pill(p, s),
            ]),
          ),
      ]),
    );
  }
}

/// Tournaments → Quick matches row.
class QuickMatchRow extends StatelessWidget {
  final MyQuickMatch q;
  final VoidCallback onTap;
  const QuickMatchRow({super.key, required this.q, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sport = Sports.byCode(q.sport);
    final at = parseQuickTime(q.scheduledAt);
    final cancelled = q.status == 'CANCELLED' || q.matchStatus == 'CANCELLED';
    final many = q.matchCount > 1;
    final status = cancelled
        ? 'Cancelled'
        : q.status == 'COMPLETED'
            ? (many ? 'Finished · ${q.matchCount} matches' : (q.resultText ?? 'Finished'))
            : q.matchStatus == 'LIVE'
                ? (many ? 'LIVE · match ${q.matchCount}' : 'LIVE')
                : q.matchStatus == 'COMPLETED'
                    ? (many ? 'Match ${q.matchCount}: ${q.resultText ?? 'finished'}' : (q.resultText ?? 'Finished'))
                    : (many ? 'Match ${q.matchCount} next' : (at != null ? fmtQuickTime(at) : 'Open'));
    return GestureDetector(
      onTap: onTap,
      child: FormCard(
        padding: EdgeInsets.all(SizeConfig.r(14)),
        child: Row(children: [
          if (sport != null) Image.asset(sport.asset, height: SizeConfig.r(30)),
          SizedBox(width: SizeConfig.w(12)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                q.homeScore != null || q.awayScore != null
                    ? '${q.homeName} ${q.homeScore ?? ''}  v  ${q.awayName} ${q.awayScore ?? ''}'
                    : '${q.homeName} v ${q.awayName}',
                maxLines: 2,
                style: tfStyle(14.5, weight: FontWeight.w800),
              ),
              gapH(3),
              Text(status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tfStyle(12, weight: FontWeight.w600, color: q.matchStatus == 'LIVE' ? AppColors.negative : Colors.white.withAlpha(150))),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(120)),
        ]),
      ),
    );
  }
}
