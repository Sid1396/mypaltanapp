import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../scoring/cricket_engine.dart';
import '../../scoring/football_engine.dart';
import '../../scoring/racket_engine.dart';
import '../widgets/scoring_other_sports.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/match_controller.dart';
import '../controllers/scoring_controller.dart';
import '../widgets/cricket_scorecard.dart';
import '../widgets/home_widgets.dart';
import '../widgets/tournament_form_widgets.dart';
import '../widgets/tournament_media_editors.dart' show SmallButtonLarge;

const _amber = Color(0xFFFFB74D);

class ScoringPage extends GetView<ScoringController> {
  const ScoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Obx(() {
          final m = c.match.value;
          final s = c.state.value;
          if (c.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          if (m == null || s == null) {
            return Center(child: EmptyCard(icon: Icons.sports_cricket, title: 'Scoring', message: c.error.value ?? 'Set the toss and Playing XI first.'));
          }
          final top = [
            _TopBar(title: '${m.home?.short ?? ''} vs ${m.away?.short ?? ''}'),
            if (c.lockedBy.value != null) _LockBanner(name: c.lockedBy.value!),
          ];
          if (s is FootballState) return Column(children: [...top, Expanded(child: FootballScoring(s: s))]);
          if (s is RacketState) return Column(children: [...top, Expanded(child: RacketScoring(s: s))]);
          final cs = s as CricketState;
          final live = cs.toJson();
          return Column(
            children: [
              ...top,
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(SizeConfig.w(16), SizeConfig.h(4), SizeConfig.w(16), SizeConfig.h(16)),
                  children: [
                    LiveScoreHeader(live: live, teamName: c.teamName, fill: c.fill),
                    if (live['current'] is Map) ...[gapH(10), CurrentPlayers(current: Map<String, dynamic>.from(live['current'] as Map))],
                    gapH(12),
                    _ActionPanel(s: cs),
                  ],
                ),
              ),
              if (cs.status == 'IN_PROGRESS' && cs.pending == null) _ScorePad(s: cs),
            ],
          );
        }),
      ),
    );
  }
}

class _TopBar extends GetView<ScoringController> {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(4), SizeConfig.h(4), SizeConfig.w(16), 0),
      child: Row(children: [
        IconButton(key: const ValueKey('score-back'), onPressed: Get.back, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
        Expanded(child: Text(title, style: tfStyle(16, weight: FontWeight.w800))),
        Obx(() {
          final waiting = controller.pending.length;
          final (IconData icon, String text, Color color) = controller.offline.value
              ? (Icons.cloud_off_rounded, '$waiting waiting', _amber)
              : waiting > 0 || controller.syncing.value
                  ? (Icons.cloud_upload_rounded, 'Saving…', Colors.white70)
                  : (Icons.cloud_done_rounded, 'Saved', AppColors.positive);
          return Row(key: const ValueKey('score-sync'), children: [
            Icon(icon, size: SizeConfig.r(16), color: color),
            SizedBox(width: SizeConfig.w(4)),
            Text(text, style: tfStyle(12, weight: FontWeight.w700, color: color)),
          ]);
        }),
      ]),
    );
  }
}

class _LockBanner extends GetView<ScoringController> {
  final String name;
  const _LockBanner({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.fromLTRB(SizeConfig.w(16), SizeConfig.h(6), SizeConfig.w(16), 0),
        padding: EdgeInsets.all(SizeConfig.r(12)),
        decoration:
            BoxDecoration(color: _amber.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(12)), border: Border.all(color: _amber.withAlpha(90))),
        child: Row(children: [
          Expanded(child: Text('$name is scoring this match on another phone.', style: tfStyle(13, weight: FontWeight.w600))),
          TextButton(
            key: const ValueKey('score-take-over'),
            onPressed: controller.takeOver,
            child: Text('Take over', style: tfStyle(13, weight: FontWeight.w800, color: AppColors.primary)),
          ),
        ]),
      );
}

// ─── What the scorer must do next ───────────────────────────────

class _ActionPanel extends GetView<ScoringController> {
  final CricketState s;
  const _ActionPanel({required this.s});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    switch (s.status) {
      case 'NOT_STARTED':
      case 'INNINGS_BREAK':
        if (s.innings.length >= 2) return const SizedBox.shrink();
        return _StartInnings(s: s);
      case 'TIE_DECISION':
        final m = c.match.value!;
        return FormCard(
          padding: EdgeInsets.all(SizeConfig.r(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Scores are level', style: tfStyle(16, weight: FontWeight.w800)),
            gapH(4),
            Text('Play a super over on the field, then record who won.', style: tfStyle(13, color: Colors.white.withAlpha(170))),
            gapH(12),
            for (final t in [m.home!, m.away!]) ...[
              SizedBox(
                width: double.infinity,
                child: SmallButtonLarge(
                  key: ValueKey('tie-winner-${t.entryId}'),
                  label: '${t.name} won the super over',
                  onTap: () => c.endMatch(winner: t.entryId, text: '{${t.entryId}} won the super over'),
                ),
              ),
              gapH(8),
            ],
          ]),
        );
      case 'COMPLETED':
        return FormCard(
          padding: EdgeInsets.all(SizeConfig.r(16)),
          child: Column(children: [
            Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: SizeConfig.r(36)),
            gapH(6),
            Text(c.fill(s.result), textAlign: TextAlign.center, style: tfStyle(17, weight: FontWeight.w900)),
            gapH(12),
            SizedBox(
                width: double.infinity, child: SmallButtonLarge(key: const ValueKey('score-done'), label: 'Done', onTap: () => Navigator.of(context).pop())),
            TextButton(onPressed: c.undo, child: Text('Undo last ball', style: tfStyle(13, color: Colors.white.withAlpha(160)))),
          ]),
        );
    }
    if (s.pending == 'NEW_BATTER') {
      return _PickPlayer(
        title: 'New batter',
        players: s.availableBatters(),
        onPick: (id) => _newBatter(id),
        batter: true,
        labelOf: (p) => s.current!.batters[p.id]?.retiredHurt == true ? '${p.name} · retired hurt' : p.name,
      );
    }
    if (s.pending == 'NEW_BOWLER') return _PickPlayer(title: 'Bowler for the next over', players: s.availableBowlers(), onPick: c.newBowler);
    return const SizedBox.shrink();
  }

  void _newBatter(int id) {
    final c = controller;
    final i = s.current!;
    // Fill whichever end is empty; the scorer can swap strike afterwards.
    c.newBatter(id, i.striker == null ? 'STRIKER' : 'NON_STRIKER');
  }
}

class _StartInnings extends GetView<ScoringController> {
  final CricketState s;
  const _StartInnings({required this.s});

  @override
  Widget build(BuildContext context) {
    final striker = controller.startStriker, nonStriker = controller.startNonStriker, bowler = controller.startBowler;
    final batting = s.innings.isEmpty ? s.setup.firstBatting : s.setup.other(s.innings.first.batting);
    final bowling = s.setup.other(batting);
    Widget chips(String label, List<PlayerRef> players, Rx<int?> v, {Rx<int?>? not}) => Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormLabel(label),
            Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
              for (final p in players.where((p) => not == null || p.id != not.value))
                _Chip(key: ValueKey('start-$label-${p.id}'), label: p.name, selected: v.value == p.id, onTap: () => v.value = p.id),
            ]),
            gapH(12),
          ],
        ));
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.innings.isEmpty ? '${controller.teamName(batting)} bat first' : '${controller.teamName(batting)} need ${s.innings.first.runs + 1} to win',
            style: tfStyle(16, weight: FontWeight.w800)),
        gapH(12),
        chips('Striker', s.playersOf(batting), striker, not: nonStriker),
        chips('Non-striker', s.playersOf(batting), nonStriker, not: striker),
        chips('Opening bowler', s.playersOf(bowling), bowler),
        // Overs for this match: the tournament's by default, more or fewer on the day. Fixed once the match starts.
        // At most what the bowlers can bowl between them (players × overs per bowler).
        if (s.innings.isEmpty)
          Obx(() => Column(children: [
                NumberStepper(
                  key: const ValueKey('start-overs'),
                  label: 'Overs in this match',
                  hint: 'Change it if the organiser says so. Both teams get the same overs.',
                  value: controller.startOvers.value ?? s.rules.overs,
                  min: 1,
                  max: (s.rules.playersPerSide * s.rules.oversPerBowler).clamp(s.rules.overs, 50),
                  onChanged: (n) => controller.startOvers.value = n,
                ),
                gapH(12),
              ]))
        else ...[
          Text('${s.rules.overs} overs', style: tfStyle(13, color: Colors.white.withAlpha(170))),
          gapH(12),
        ],
        SizedBox(
          width: double.infinity,
          child: SmallButtonLarge(
            key: const ValueKey('start-innings'),
            label: s.innings.isEmpty ? 'Start match' : 'Start second innings',
            onTap: () {
              if (striker.value == null || nonStriker.value == null || bowler.value == null) return;
              final overs = controller.startOvers.value;
              controller.startInnings(striker.value!, nonStriker.value!, bowler.value!,
                  overs: s.innings.isEmpty && overs != null && overs != s.rules.overs ? overs : null);
            },
          ),
        ),
        // Wrong toss from the umpire, or a change in the XI: still possible until the first ball.
        if (s.innings.isEmpty && Get.isRegistered<MatchController>())
          Center(
            child: TextButton(
              key: const ValueKey('start-change-setup'),
              onPressed: () {
                Navigator.of(context).pop();
                Get.find<MatchController>().changeSetup();
              },
              child: Text('Wrong toss? Change toss & Playing XI', style: tfStyle(13.5, weight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
        if (s.innings.isNotEmpty) ...[
          gapH(14),
          Text('Someone from ${controller.teamName(batting)} can score their innings.',
              style: tfStyle(13, color: Colors.white.withAlpha(170), height: 1.4)),
          gapH(6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey('hand-over-scoring'),
              onPressed: controller.handOver,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary.withAlpha(120)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14))),
                padding: EdgeInsets.symmetric(vertical: SizeConfig.h(13)),
              ),
              child: Text('Hand over scoring', style: tfStyle(14.5, weight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _PickPlayer extends StatelessWidget {
  final String title;
  final List<PlayerRef> players;
  final ValueChanged<int> onPick;
  final bool batter;
  final String Function(PlayerRef)? labelOf;
  const _PickPlayer({required this.title, required this.players, required this.onPick, this.batter = false, this.labelOf});

  @override
  Widget build(BuildContext context) => FormCard(
        padding: EdgeInsets.all(SizeConfig.r(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: tfStyle(16, weight: FontWeight.w800)),
          gapH(10),
          if (players.isEmpty)
            Text(batter ? 'No batters left.' : 'No bowler can bowl this over.', style: tfStyle(13, color: _amber))
          else
            Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
              for (final p in players) _Chip(key: ValueKey('pick-${p.id}'), label: labelOf?.call(p) ?? p.name, selected: false, onTap: () => onPick(p.id)),
            ]),
        ]),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(10)),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFF242424),
            borderRadius: BorderRadius.circular(SizeConfig.r(10)),
            border: Border.all(color: selected ? AppColors.primary : Colors.white.withAlpha(20)),
          ),
          child: Text(label, style: tfStyle(14, weight: FontWeight.w700)),
        ),
      );
}

// ─── The scoring pad ────────────────────────────────────────────

class _ScorePad extends GetView<ScoringController> {
  final CricketState s;
  const _ScorePad({required this.s});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget key(String label, VoidCallback onTap, {Color? color, String? id}) => Expanded(
          child: Padding(
            padding: EdgeInsets.all(SizeConfig.r(3)),
            child: Material(
              color: color ?? const Color(0xFF242424),
              borderRadius: BorderRadius.circular(SizeConfig.r(12)),
              child: InkWell(
                key: ValueKey('pad-${id ?? label}'),
                borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                onTap: onTap,
                child: SizedBox(height: SizeConfig.h(54), child: Center(child: Text(label, style: tfStyle(18, weight: FontWeight.w800)))),
              ),
            ),
          ),
        );
    return Container(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(10), SizeConfig.h(8), SizeConfig.w(10), SizeConfig.h(10)),
      decoration: BoxDecoration(color: const Color(0xFF151515), border: Border(top: BorderSide(color: Colors.white.withAlpha(14)))),
      child: Column(children: [
        Row(children: [key('0', () => c.runs(0)), key('1', () => c.runs(1)), key('2', () => c.runs(2)), key('3', () => c.runs(3))]),
        Row(children: [
          key('4', () => c.runs(4, boundary: true), color: AppColors.positive.withAlpha(90)),
          key('6', () => c.runs(6), color: AppColors.positive.withAlpha(170)),
          key('Wd', () => _runsSheet('Wide', 'WIDE', from: 0, to: 4, hint: 'Extra runs taken or a boundary off the wide'), color: _amber.withAlpha(60)),
          key('Nb', () => _runsSheet('No ball', 'NO_BALL', from: 0, to: 6, hint: 'Runs off the bat (or byes)', nb: true), color: _amber.withAlpha(60)),
        ]),
        Row(children: [
          key('Bye', () => _runsSheet('Byes', 'BYE', from: 1, to: 4)),
          key('LB', () => _runsSheet('Leg byes', 'LEG_BYE', from: 1, to: 4), id: 'LB'),
          key('W', () => _wicketSheet(), color: AppColors.negative.withAlpha(150), id: 'W'),
          key('Undo', c.undo),
        ]),
        Row(children: [key('1D', () => c.declared(1), id: '1D'), key('Overs', _oversSheet, id: 'Overs'), key('More', _moreSheet, id: 'More')]),
      ]),
    );
  }

  void _runsSheet(String title, String extra, {required int from, required int to, String? hint, bool nb = false}) {
    final c = controller;
    final byes = false.obs;
    Get.bottomSheet(
      Builder(
          builder: (sheet) => Obx(() {
                final areByes = byes.value; // read every time: Obx needs a value to watch, even for wides
                return SheetFrame(title: title, children: [
                  if (hint != null) Text(hint, style: tfStyle(13, color: Colors.white.withAlpha(160))),
                  if (nb) ...[
                    gapH(8),
                    SwitchRow(label: 'They were byes, not off the bat', value: areByes, onChanged: (v) => byes.value = v),
                  ],
                  gapH(12),
                  Wrap(spacing: SizeConfig.w(8), runSpacing: SizeConfig.h(8), children: [
                    for (var r = from; r <= to; r++)
                      _Chip(
                        key: ValueKey('runs-$extra-$r'),
                        label: '$r',
                        selected: false,
                        onTap: () {
                          Navigator.of(sheet).pop();
                          c.extra(extra, r, nbByes: nb && areByes, boundary: r == 4);
                        },
                      ),
                    // A declared run off the bat on a no-ball: 1 to the batter, the batters stay at their ends.
                    if (nb && !areByes)
                      _Chip(
                        key: const ValueKey('runs-NO_BALL-1D'),
                        label: '1D',
                        selected: false,
                        onTap: () {
                          Navigator.of(sheet).pop();
                          c.extra('NO_BALL', 1, declared: true);
                        },
                      ),
                    // A wicket off this wide / no-ball.
                    if (extra == 'WIDE' || extra == 'NO_BALL')
                      _Chip(
                        key: ValueKey('wicket-on-$extra'),
                        label: 'W',
                        selected: false,
                        onTap: () {
                          Navigator.of(sheet).pop();
                          _wicketSheet(onBall: extra);
                        },
                      ),
                  ]),
                ]);
              })),
      isScrollControlled: true,
    );
  }

  /// The wicket sheet. With [onBall] (WIDE / NO_BALL, from the Wd / Nb sheet) only the wickets that can fall off that
  /// ball are offered: run out or stumped off a wide; run out, stumped or box out off a no-ball.
  ///
  /// Built to stop the slips seen at real matches: nothing is picked until the scorer chooses how; "Who is out?" is
  /// always asked, with who is on strike, and picking the other batter for a bowled / caught / lbw moves the strike to
  /// him first so the ball counts for the right man; Box out sits apart from the usual wickets; a catch and a run out
  /// need the fielder; and the Out button reads the dismissal back before it is saved.
  void _wicketSheet({String? onBall}) {
    final c = controller;
    final i = s.current!;
    final fielders = s.playersOf(i.bowling);
    final usual = [
      ('BOWLED', 'Bowled'),
      ('CAUGHT', 'Caught'),
      ('RUN_OUT', 'Run out'),
      ('LBW', 'LBW'),
      ('STUMPED', 'Stumped'),
      ('HIT_WICKET', 'Hit wicket'),
    ];
    bool fits(String h) => switch (onBall) {
          'WIDE' => const {'STUMPED', 'RUN_OUT'}.contains(h),
          'NO_BALL' => const {'RUN_OUT', 'STUMPED', 'BOX_OUT'}.contains(h),
          _ => true,
        };
    final hows = usual.where((h) => fits(h.$1)).toList();
    final boxOut = s.rules.boxOut && fits('BOX_OUT');
    final batters = [i.striker, i.nonStriker].whereType<int>().toList();
    final how = Rx<String?>(null), out = Rx<int?>(i.striker), fielder = Rx<int?>(null), runs = 0.obs, ballType = (onBall ?? 'NONE').obs;
    Get.bottomSheet(
      Builder(
          builder: (sheet) => Obx(() {
                final h = how.value;
                final needsFielder = const {'CAUGHT', 'RUN_OUT', 'STUMPED'}.contains(h);
                final fielderRequired = h == 'CAUGHT' || h == 'RUN_OUT';
                // Wickets that can fall off a wide or no-ball: run out (either), stumped (either), box out (no-ball).
                final ballTypes = [
                  if (const {'RUN_OUT', 'STUMPED'}.contains(h)) ('WIDE', 'Wide'),
                  if (const {'RUN_OUT', 'STUMPED', 'BOX_OUT'}.contains(h)) ('NO_BALL', 'No ball'),
                ];
                final ballOn = ballTypes.any((t) => t.$1 == ballType.value) ? ballType.value : 'NONE';
                final outId = out.value ?? i.striker!;
                // Anything but a run out falls to the batter facing: the other batter means the strike was wrong.
                final swap = h != null && h != 'RUN_OUT' && outId != i.striker;
                final missing = h == null
                    ? 'Choose how he is out'
                    : (fielderRequired && fielder.value == null ? (h == 'CAUGHT' ? 'Choose who took the catch' : 'Choose the fielder') : null);
                return SheetFrame(title: switch (onBall) { 'WIDE' => 'Wide + wicket', 'NO_BALL' => 'No ball + wicket', _ => 'Wicket' }, children: [
                  const FormLabel('Who is out?'),
                  Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
                    for (final id in batters)
                      _Chip(
                        key: ValueKey('out-$id'),
                        label: id == i.striker ? '${s.nameOf(id)} · on strike' : s.nameOf(id),
                        selected: outId == id,
                        onTap: () => out.value = id,
                      ),
                  ]),
                  gapH(14),
                  const FormLabel('How?'),
                  Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
                    for (final (v, l) in hows) _Chip(key: ValueKey('how-$v'), label: l, selected: h == v, onTap: () => how.value = v),
                  ]),
                  if (boxOut) ...[
                    gapH(10),
                    Text('Box cricket rule: only if the ball hit the roof or net', style: tfStyle(12, color: Colors.white.withAlpha(140))),
                    gapH(6),
                    _Chip(key: const ValueKey('how-BOX_OUT'), label: 'Box out', selected: h == 'BOX_OUT', onTap: () => how.value = 'BOX_OUT'),
                  ],
                  // Leaving hurt is not a wicket and not a ball; offered here because the scorer reaches for W when a
                  // batter walks off. He can come back in later from the new-batter list.
                  if (onBall == null) ...[
                    gapH(14),
                    Text('Not out, left the field', style: tfStyle(12, color: Colors.white.withAlpha(140))),
                    gapH(6),
                    _Chip(
                      key: ValueKey('retired-hurt-$outId'),
                      label: '${s.nameOf(outId)} retired hurt',
                      selected: false,
                      onTap: () {
                        Navigator.of(sheet).pop();
                        c.retire(outId, out: false);
                      },
                    ),
                  ],
                  if (swap) ...[
                    gapH(10),
                    Text('${s.nameOf(outId)} was facing, so the strike moves to him before the wicket.',
                        style: tfStyle(12.5, color: _amber)),
                  ],
                  if (h == 'RUN_OUT') ...[
                    gapH(14),
                    const FormLabel('Runs completed before the run out'),
                    Wrap(spacing: SizeConfig.w(6), children: [
                      for (var r = 0; r <= 3; r++) _Chip(label: '$r', selected: runs.value == r, onTap: () => runs.value = r),
                    ]),
                  ],
                  if (onBall == null && ballTypes.isNotEmpty) ...[
                    gapH(14),
                    const FormLabel('On which ball?'),
                    Wrap(spacing: SizeConfig.w(6), children: [
                      _Chip(label: 'Normal', selected: ballOn == 'NONE', onTap: () => ballType.value = 'NONE'),
                      for (final (v, l) in ballTypes) _Chip(key: ValueKey('ball-$v'), label: l, selected: ballOn == v, onTap: () => ballType.value = v),
                    ]),
                  ],
                  if (needsFielder) ...[
                    gapH(14),
                    FormLabel(h == 'CAUGHT' ? 'Caught by' : (h == 'STUMPED' ? 'Wicket-keeper' : 'Fielder'), optional: !fielderRequired),
                    Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
                      for (final p in fielders)
                        _Chip(
                          key: ValueKey('fielder-${p.id}'),
                          label: p.id == i.bowler ? '${p.name} · bowler' : p.name,
                          selected: fielder.value == p.id,
                          onTap: () => fielder.value = p.id,
                        ),
                    ]),
                  ],
                  gapH(18),
                  if (missing != null) ...[
                    Text(missing, textAlign: TextAlign.center, style: tfStyle(12.5, color: Colors.white.withAlpha(150))),
                    gapH(8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: SmallButtonLarge(
                      key: const ValueKey('wicket-save'),
                      label: missing != null ? 'Out' : 'Out: ${s.nameOf(outId)} · ${_dismissal(h!, fielder.value, i.bowler)}',
                      onTap: missing != null
                          ? null
                          : () {
                              final f = needsFielder ? fielder.value : null, w = h!;
                              final ok = swap
                                  ? c.wicketAfterSwap(w, outId, fielder: f)
                                  : c.wicket(w, outId, fielder: f, runs: w == 'RUN_OUT' ? runs.value : 0, extraType: ballOn);
                              if (ok && sheet.mounted) Navigator.of(sheet).pop();
                            },
                    ),
                  ),
                ]);
              })),
      isScrollControlled: true,
    );
  }

  /// How the scorecard will read, for the Out button: "c Anil b Chetan", "run out (Deepak)", "b Vishal".
  String _dismissal(String how, int? fielder, int? bowler) {
    final b = bowler == null ? '' : s.nameOf(bowler);
    final f = fielder == null ? null : s.nameOf(fielder);
    return switch (how) {
      'BOWLED' => 'b $b',
      'CAUGHT' => f == null || fielder == bowler ? 'c & b $b' : 'c $f b $b',
      'LBW' => 'lbw b $b',
      'STUMPED' => 'st ${f ?? 'keeper'} b $b',
      'HIT_WICKET' => 'hit wicket b $b',
      'BOX_OUT' => 'box out b $b',
      _ => 'run out${f == null ? '' : ' ($f)'}',
    };
  }

  /// Over by over for every innings so far (latest first), with each bowler's figures.
  void _oversSheet() {
    final c = controller;
    Get.bottomSheet(
      SheetFrame(title: 'Overs', children: [
        for (final inn in s.innings.reversed) ...[
          Text('${c.teamName(inn.batting)} · ${s.scoreOf(inn)} (${inn.overs})', style: tfStyle(15, weight: FontWeight.w800, color: AppColors.primary)),
          gapH(8),
          if (inn.overLog.isEmpty) Text('No balls yet.', style: tfStyle(13, color: Colors.white.withAlpha(150))),
          for (final o in inn.overLog.reversed)
            Padding(
              padding: EdgeInsets.only(bottom: SizeConfig.h(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: SizeConfig.w(54), child: Text('Over ${o['over']}', style: tfStyle(12.5, weight: FontWeight.w800))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${o['bowler']}', style: tfStyle(12.5, color: Colors.white.withAlpha(170))),
                    gapH(2),
                    Text((o['balls'] as List).join('  '), style: tfStyle(14, weight: FontWeight.w700)),
                  ]),
                ),
                Text('${o['runs']} run${o['runs'] == 1 ? '' : 's'}${(o['wickets'] as int) > 0 ? ' · ${o['wickets']}W' : ''}',
                    style: tfStyle(12.5, weight: FontWeight.w700)),
              ]),
            ),
          gapH(4),
          Text('BOWLING  O-M-R-W', style: tfStyle(11.5, weight: FontWeight.w800, color: Colors.white.withAlpha(140))),
          gapH(4),
          for (final b in inn.bowlers.values)
            Padding(
              padding: EdgeInsets.only(bottom: SizeConfig.h(4)),
              child: Row(children: [
                Expanded(child: Text(b.name, style: tfStyle(13.5))),
                Text('${b.overs}-${b.maidens}-${b.runs}-${b.wickets}', style: tfStyle(13.5, weight: FontWeight.w700)),
              ]),
            ),
          gapH(16),
        ],
      ]),
      isScrollControlled: true,
    );
  }

  void _moreSheet() {
    final c = controller;
    final i = s.current!;
    final m = c.match.value!;
    Get.bottomSheet(
      Builder(builder: (sheet) {
        void close() => Navigator.of(sheet).pop();
        Widget row(String label, IconData icon, VoidCallback onTap, {Color? color}) => ListTile(
              key: ValueKey('more-$label'),
              leading: Icon(icon, color: color ?? Colors.white),
              title: Text(label, style: tfStyle(15, weight: FontWeight.w700, color: color ?? Colors.white)),
              onTap: () {
                close();
                onTap();
              },
            );
        return SheetFrame(title: 'More', children: [
          row('Swap strike', Icons.swap_vert_rounded, c.swapStrike),
          for (final id in [i.striker, i.nonStriker].whereType<int>()) ...[
            row('${s.nameOf(id)} retired hurt', Icons.healing_rounded, () => c.retire(id, out: false)),
            row('${s.nameOf(id)} retired out', Icons.directions_walk_rounded, () => c.retire(id, out: true)),
          ],
          row('End this innings', Icons.stop_circle_outlined, () => c.endInnings('Innings closed'), color: _amber),
          row('Abandon match (no result)', Icons.cancel_outlined, () => c.endMatch(text: 'No result'), color: AppColors.negative),
          if (m.isOwner)
            for (final t in [m.home!, m.away!])
              row('Award match to ${t.name}', Icons.flag_rounded, () => c.endMatch(winner: t.entryId, text: '{${t.entryId}} won (awarded)'),
                  color: AppColors.negative),
        ]);
      }),
      isScrollControlled: true,
    );
  }
}
