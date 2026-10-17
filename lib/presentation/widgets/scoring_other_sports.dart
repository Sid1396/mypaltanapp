import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../scoring/cricket_engine.dart' show PlayerRef;
import '../../scoring/football_engine.dart';
import '../../scoring/racket_engine.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/scoring_controller.dart';
import 'tournament_form_widgets.dart';
import 'tournament_media_editors.dart' show SmallButtonLarge;

const _amber = Color(0xFFFFB74D);
List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

// ─── Match clock ────────────────────────────────────────────────

/// Running football clock from the live JSON ("23'"), ticking every second.
class MatchClock extends StatefulWidget {
  final Map<String, dynamic> live;
  final TextStyle? style;
  const MatchClock({super.key, required this.live, this.style});

  @override
  State<MatchClock> createState() => _MatchClockState();
}

class _MatchClockState extends State<MatchClock> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.live;
    final phase = l['phase']?.toString() ?? '';
    final label = switch (phase) {
      'NOT_STARTED' => 'Not started',
      'HALF_TIME' => 'Half-time',
      'ET_BREAK' => 'Before extra time',
      'ET_HALF' => 'Extra time break',
      'PENALTIES' => 'Penalties',
      'COMPLETED' => 'Full time',
      'TIE_DECISION' => 'Full time',
      _ => null,
    };
    if (label != null) return Text(label, style: widget.style ?? tfStyle(13, weight: FontWeight.w800, color: AppColors.primary));
    final started = l['period_started_at'] as int?;
    final offset = (l['period_offset'] as int?) ?? 0, length = (l['period_minutes'] as int?) ?? 0;
    if (started == null) return const SizedBox.shrink();
    final secs = (DateTime.now().millisecondsSinceEpoch - started) ~/ 1000;
    final min = secs ~/ 60;
    final text = min >= length ? "${offset + length}+${min - length + 1}'" : "${offset + min}:${(secs % 60).toString().padLeft(2, '0')}";
    return Text(text, style: widget.style ?? tfStyle(13, weight: FontWeight.w800, color: AppColors.primary));
  }
}

// ─── Football scoreboard and timeline (shared by scorer and viewers) ──

class FootballBoard extends StatelessWidget {
  final Map<String, dynamic> live;
  final String Function(int?) teamName;
  final String Function(String?) fill;
  const FootballBoard({super.key, required this.live, required this.teamName, required this.fill});

  @override
  Widget build(BuildContext context) {
    final score = Map<String, dynamic>.from(live['score'] as Map? ?? {});
    final home = live['home_entry_id'] as int?, away = live['away_entry_id'] as int?;
    final so = live['shootout'] is Map ? Map<String, dynamic>.from(live['shootout'] as Map) : null;
    Widget kicks(List k) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (final x in k)
            Container(
              width: SizeConfig.r(12),
              height: SizeConfig.r(12),
              margin: EdgeInsets.symmetric(horizontal: SizeConfig.w(2)),
              decoration: BoxDecoration(shape: BoxShape.circle, color: x == true ? AppColors.positive : AppColors.negative),
            ),
        ]);
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(16)),
      child: Column(children: [
        MatchClock(live: live),
        gapH(8),
        Row(children: [
          Expanded(child: Text(teamName(home), textAlign: TextAlign.center, style: tfStyle(14.5, weight: FontWeight.w800))),
          Text('${score['home'] ?? 0} - ${score['away'] ?? 0}', key: const ValueKey('football-score'), style: tfStyle(34, weight: FontWeight.w900)),
          Expanded(child: Text(teamName(away), textAlign: TextAlign.center, style: tfStyle(14.5, weight: FontWeight.w800))),
        ]),
        if (so != null) ...[
          gapH(8),
          Row(children: [
            Expanded(child: Center(child: kicks(so['home'] as List? ?? []))),
            Text('Pens', style: tfStyle(11, color: Colors.white.withAlpha(130))),
            Expanded(child: Center(child: kicks(so['away'] as List? ?? []))),
          ]),
        ],
        if (live['result'] != null) ...[
          gapH(8),
          Text(fill(live['result']?.toString()), textAlign: TextAlign.center, style: tfStyle(14, weight: FontWeight.w800, color: AppColors.primary)),
        ],
      ]),
    );
  }
}

class FootballTimeline extends StatelessWidget {
  final Map<String, dynamic> live;
  const FootballTimeline({super.key, required this.live});

  @override
  Widget build(BuildContext context) {
    final items = _maps(live['timeline']);
    final home = live['home_entry_id'];
    if (items.isEmpty) return Text('Goals and cards appear here.', style: tfStyle(13, color: Colors.white.withAlpha(140)));
    return Column(children: [
      for (final e in items)
        Padding(
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(6)),
          child: Row(children: [
            SizedBox(
                width: SizeConfig.w(40),
                child: Text(e['minute'] == null ? '' : "${e['minute']}'", style: tfStyle(12.5, weight: FontWeight.w700, color: Colors.white.withAlpha(150)))),
            Icon(
              switch (e['type']) {
                'GOAL' => Icons.sports_soccer_rounded,
                'CARD' => Icons.style_rounded,
                'SHOOTOUT' => e['scored'] == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                _ => Icons.flag_rounded,
              },
              size: SizeConfig.r(18),
              color: switch (e['type']) {
                'CARD' => e['color'] == 'RED' ? AppColors.negative : _amber,
                'GOAL' => AppColors.primary,
                _ => Colors.white.withAlpha(150),
              },
            ),
            SizedBox(width: SizeConfig.w(10)),
            Expanded(
              child: Text(
                [e['text'], if (e['type'] == 'CARD' && e['player'] != null) e['player'], if (e['assist'] != null) 'assist ${e['assist']}'].join(' · '),
                textAlign: e['team'] == null || e['team'] == home ? TextAlign.left : TextAlign.right,
                style: tfStyle(13.5, weight: e['type'] == 'GOAL' ? FontWeight.w800 : FontWeight.w600),
              ),
            ),
            if (e['score'] != null) ...[SizedBox(width: SizeConfig.w(8)), Text('${e['score']}', style: tfStyle(12, color: Colors.white.withAlpha(130)))],
          ]),
        ),
    ]);
  }
}

// ─── Football scoring ───────────────────────────────────────────

class FootballScoring extends GetView<ScoringController> {
  final FootballState s;
  const FootballScoring({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final live = s.toJson();
    final home = s.setup.homeEntry, away = s.setup.awayEntry;
    Widget big(String key, String label, VoidCallback onTap, {Color? color}) => Padding(
          padding: EdgeInsets.only(bottom: SizeConfig.h(8)),
          child: SizedBox(
            width: double.infinity,
            child: Material(
              color: color ?? const Color(0xFF242424),
              borderRadius: BorderRadius.circular(SizeConfig.r(12)),
              child: InkWell(
                key: ValueKey(key),
                borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                onTap: onTap,
                child: SizedBox(height: SizeConfig.h(52), child: Center(child: Text(label, style: tfStyle(16, weight: FontWeight.w800)))),
              ),
            ),
          ),
        );
    final actions = <Widget>[];
    switch (s.phase) {
      case 'NOT_STARTED':
        actions.add(big('fb-kickoff', 'Kick off', c.kickOff, color: AppColors.primary));
      case 'HALF_TIME':
      case 'ET_BREAK':
      case 'ET_HALF':
        actions.add(big('fb-start-period', s.phase == 'HALF_TIME' ? 'Start second half' : 'Start extra time', c.startPeriod, color: AppColors.primary));
      case 'PENALTIES':
        final next = s.nextKicker;
        if (s.shootoutFirst == null) {
          actions.add(Text('Who takes the first penalty?', style: tfStyle(14, weight: FontWeight.w700)));
          actions.add(gapH(8));
          for (final t in [home, away]) {
            actions.add(big('fb-pen-first-$t', c.teamName(t), () => _kick(t)));
          }
        } else {
          actions.add(Text('${c.teamName(next)} to take a penalty', style: tfStyle(14, weight: FontWeight.w700)));
          actions.add(gapH(8));
          actions.add(Row(children: [
            Expanded(child: big('fb-pen-scored', 'Scored', () => c.shootoutKick(next!, scored: true), color: AppColors.positive.withAlpha(150))),
            SizedBox(width: SizeConfig.w(8)),
            Expanded(child: big('fb-pen-missed', 'Missed', () => c.shootoutKick(next!, scored: false), color: AppColors.negative.withAlpha(150))),
          ]));
        }
      case 'TIE_DECISION':
        for (final t in [home, away]) {
          actions.add(big('fb-winner-$t', '${c.teamName(t)} won', () => c.endMatch(winner: t, text: '{$t} won')));
        }
      case 'COMPLETED':
        actions.add(SizedBox(
            width: double.infinity, child: SmallButtonLarge(key: const ValueKey('score-done'), label: 'Done', onTap: () => Navigator.of(context).pop())));
      default: // ball in play
        actions.add(Row(children: [
          for (final t in [home, away]) ...[
            Expanded(child: big('fb-goal-$t', 'Goal ${c.match.value?.team(t)?.short ?? ''}', () => _goalSheet(t), color: AppColors.primary.withAlpha(120))),
            if (t == home) SizedBox(width: SizeConfig.w(8)),
          ],
        ]));
        actions.add(Row(children: [
          for (final t in [home, away]) ...[
            Expanded(child: big('fb-card-$t', 'Card ${c.match.value?.team(t)?.short ?? ''}', () => _cardSheet(t), color: _amber.withAlpha(60))),
            if (t == home) SizedBox(width: SizeConfig.w(8)),
          ],
        ]));
        actions.add(big(
          'fb-period-end',
          switch (s.phase) { 'FIRST_HALF' => 'Half-time', 'SECOND_HALF' => 'Full time', 'ET_FIRST' => 'Extra time half-time', _ => 'End extra time' },
          c.periodEnd,
        ));
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(16), SizeConfig.h(4), SizeConfig.w(16), SizeConfig.h(16)),
      children: [
        FootballBoard(live: live, teamName: c.teamName, fill: c.fill),
        gapH(14),
        ...actions,
        if (s.phase != 'NOT_STARTED' && s.phase != 'COMPLETED')
          Center(
              child: TextButton(
                  key: const ValueKey('fb-undo'), onPressed: c.undo, child: Text('Undo last', style: tfStyle(13.5, color: Colors.white.withAlpha(170))))),
        gapH(10),
        FootballTimeline(live: live),
      ],
    );
  }

  void _kick(int firstTeam) {
    final c = controller;
    Get.bottomSheet(
      Builder(
          builder: (sheet) => SheetFrame(title: '${c.teamName(firstTeam)} penalty', children: [
                Row(children: [
                  Expanded(
                    child: SmallButtonLarge(
                        label: 'Scored',
                        onTap: () {
                          Navigator.of(sheet).pop();
                          c.shootoutKick(firstTeam, scored: true);
                        }),
                  ),
                  SizedBox(width: SizeConfig.w(8)),
                  Expanded(
                    child: SmallButtonLarge(
                        label: 'Missed',
                        onTap: () {
                          Navigator.of(sheet).pop();
                          c.shootoutKick(firstTeam, scored: false);
                        }),
                  ),
                ]),
              ])),
      isScrollControlled: true,
    );
  }

  void _goalSheet(int team) {
    final c = controller;
    final own = false.obs, penalty = false.obs, scorer = Rx<int?>(null), assist = Rx<int?>(null);
    Get.bottomSheet(
      Builder(
          builder: (sheet) => Obx(() {
                // An own goal is scored by a player of the other team.
                final from = own.value ? s.other(team) : team;
                final players = s.playersOf(from).where((p) => !s.sentOff.contains(p.id)).toList();
                return SheetFrame(title: 'Goal for ${c.teamName(team)}', children: [
                  Wrap(spacing: SizeConfig.w(6), children: [
                    _Pill(
                        label: 'Own goal',
                        on: own.value,
                        onTap: () {
                          own.value = !own.value;
                          scorer.value = null;
                          assist.value = null;
                        }),
                    _Pill(label: 'Penalty', on: penalty.value, onTap: () => penalty.value = !penalty.value),
                  ]),
                  gapH(12),
                  FormLabel(own.value ? 'Who put it in their own net?' : 'Scorer', optional: true),
                  _PlayerChips(players: players, selected: scorer.value, onTap: (id) => scorer.value = scorer.value == id ? null : id, prefix: 'scorer'),
                  if (!own.value && !penalty.value) ...[
                    gapH(12),
                    const FormLabel('Assist', optional: true),
                    _PlayerChips(
                        players: players.where((p) => p.id != scorer.value).toList(),
                        selected: assist.value,
                        onTap: (id) => assist.value = assist.value == id ? null : id,
                        prefix: 'assist'),
                  ],
                  gapH(16),
                  SizedBox(
                    width: double.infinity,
                    child: SmallButtonLarge(
                      key: const ValueKey('fb-goal-save'),
                      label: 'Goal',
                      onTap: () {
                        Navigator.of(sheet).pop();
                        c.goal(team, scorer: scorer.value, assist: own.value ? null : assist.value, ownGoal: own.value, penalty: penalty.value);
                      },
                    ),
                  ),
                ]);
              })),
      isScrollControlled: true,
    );
  }

  void _cardSheet(int team) {
    final c = controller;
    final color = 'YELLOW'.obs, player = Rx<int?>(null);
    Get.bottomSheet(
      Builder(
          builder: (sheet) => Obx(() => SheetFrame(title: 'Card for ${c.teamName(team)}', children: [
                Wrap(spacing: SizeConfig.w(6), children: [
                  _Pill(key: const ValueKey('card-yellow'), label: 'Yellow', on: color.value == 'YELLOW', onTap: () => color.value = 'YELLOW'),
                  _Pill(key: const ValueKey('card-red'), label: 'Red', on: color.value == 'RED', onTap: () => color.value = 'RED'),
                ]),
                gapH(12),
                const FormLabel('Player'),
                _PlayerChips(
                    players: s.playersOf(team).where((p) => !s.sentOff.contains(p.id)).toList(),
                    selected: player.value,
                    onTap: (id) => player.value = id,
                    prefix: 'card-player'),
                gapH(16),
                SizedBox(
                  width: double.infinity,
                  child: SmallButtonLarge(
                    key: const ValueKey('fb-card-save'),
                    label: 'Give card',
                    onTap: player.value == null
                        ? null
                        : () {
                            Navigator.of(sheet).pop();
                            c.card(team, player.value!, color.value);
                          },
                  ),
                ),
              ]))),
      isScrollControlled: true,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Pill({super.key, required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(8)),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : const Color(0xFF242424),
            borderRadius: BorderRadius.circular(SizeConfig.r(100)),
          ),
          child: Text(label, style: tfStyle(13, weight: FontWeight.w700)),
        ),
      );
}

class _PlayerChips extends StatelessWidget {
  final List<PlayerRef> players;
  final int? selected;
  final ValueChanged<int> onTap;
  final String prefix;
  const _PlayerChips({required this.players, required this.selected, required this.onTap, required this.prefix});

  @override
  Widget build(BuildContext context) => Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
        for (final p in players)
          GestureDetector(
            key: ValueKey('$prefix-${p.id}'),
            onTap: () => onTap(p.id),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(9)),
              decoration: BoxDecoration(
                color: selected == p.id ? AppColors.primary : const Color(0xFF242424),
                borderRadius: BorderRadius.circular(SizeConfig.r(10)),
              ),
              child: Text(p.name, style: tfStyle(13.5, weight: FontWeight.w700)),
            ),
          ),
      ]);
}

// ─── Badminton / pickleball ─────────────────────────────────────

class RacketBoard extends StatelessWidget {
  final Map<String, dynamic> live;
  final String Function(int?) teamName;
  final String Function(String?) fill;
  const RacketBoard({super.key, required this.live, required this.teamName, required this.fill});

  @override
  Widget build(BuildContext context) {
    final games = _maps(live['games']);
    final cur = live['current'] is Map ? Map<String, dynamic>.from(live['current'] as Map) : null;
    final home = live['home_entry_id'] as int?, away = live['away_entry_id'] as int?;
    Widget row(int? entry, String side) => Padding(
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(4)),
          child: Row(children: [
            SizedBox(
              width: SizeConfig.w(16),
              child: cur?['server'] == entry ? Icon(Icons.sports_tennis_rounded, size: SizeConfig.r(13), color: AppColors.primary) : null,
            ),
            Expanded(child: Text(teamName(entry), style: tfStyle(14.5, weight: FontWeight.w800))),
            for (final g in games)
              SizedBox(
                width: SizeConfig.w(30),
                child: Text('${g[side]}',
                    textAlign: TextAlign.center,
                    style: tfStyle(14, weight: (g[side] as int) > (g[side == 'home' ? 'away' : 'home'] as int) ? FontWeight.w900 : FontWeight.w500)),
              ),
            if (cur != null)
              Container(
                width: SizeConfig.w(40),
                margin: EdgeInsets.only(left: SizeConfig.w(4)),
                padding: EdgeInsets.symmetric(vertical: SizeConfig.h(4)),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(40), borderRadius: BorderRadius.circular(SizeConfig.r(6))),
                child: Text('${cur[side]}', textAlign: TextAlign.center, style: tfStyle(18, weight: FontWeight.w900)),
              ),
          ]),
        );
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cur == null ? 'Final' : 'Game ${cur['game']} · best of ${live['best_of']}', style: tfStyle(12, weight: FontWeight.w800, color: AppColors.primary)),
        gapH(6),
        row(home, 'home'),
        row(away, 'away'),
        if (cur?['call'] != null) ...[
          gapH(6),
          Text('Score call: ${cur!['call']}', key: const ValueKey('racket-call'), style: tfStyle(13, weight: FontWeight.w700))
        ],
        if (live['result'] != null) ...[
          gapH(8),
          Text(fill(live['result']?.toString()), style: tfStyle(14, weight: FontWeight.w800, color: AppColors.primary)),
        ],
      ]),
    );
  }
}

class RacketScoring extends GetView<ScoringController> {
  final RacketState s;
  const RacketScoring({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final live = s.toJson();
    final home = s.setup.homeEntry, away = s.setup.awayEntry;
    Widget half(int team) => Expanded(
          child: Material(
            color: s.server == team ? AppColors.primary.withAlpha(110) : const Color(0xFF242424),
            borderRadius: BorderRadius.circular(SizeConfig.r(16)),
            child: InkWell(
              key: ValueKey('rk-point-$team'),
              borderRadius: BorderRadius.circular(SizeConfig.r(16)),
              onTap: () => c.point(team),
              child: SizedBox(
                height: SizeConfig.h(170),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(c.teamName(team), textAlign: TextAlign.center, maxLines: 2, style: tfStyle(14, weight: FontWeight.w800)),
                  gapH(6),
                  Text('${team == home ? s.home : s.away}', style: tfStyle(46, weight: FontWeight.w900)),
                  Text(s.server == team ? 'Serving · tap if they won the rally' : 'Tap if they won the rally',
                      style: tfStyle(11.5, color: Colors.white.withAlpha(170))),
                ]),
              ),
            ),
          ),
        );
    return ListView(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(16), SizeConfig.h(4), SizeConfig.w(16), SizeConfig.h(16)),
      children: [
        RacketBoard(live: live, teamName: c.teamName, fill: c.fill),
        gapH(14),
        if (s.status == 'NOT_STARTED') ...[
          Text('Who serves first?', style: tfStyle(15, weight: FontWeight.w800)),
          gapH(8),
          for (final t in [home, away]) ...[
            SizedBox(width: double.infinity, child: SmallButtonLarge(key: ValueKey('rk-serve-$t'), label: c.teamName(t), onTap: () => c.startRacket(t))),
            gapH(8),
          ],
        ] else if (s.status == 'COMPLETED')
          SizedBox(width: double.infinity, child: SmallButtonLarge(key: const ValueKey('score-done'), label: 'Done', onTap: () => Navigator.of(context).pop()))
        else ...[
          Row(children: [half(home), SizedBox(width: SizeConfig.w(10)), half(away)]),
          gapH(10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton(
                key: const ValueKey('rk-undo'), onPressed: c.undo, child: Text('Undo last point', style: tfStyle(13.5, color: Colors.white.withAlpha(170)))),
            TextButton(
              key: const ValueKey('rk-retire'),
              onPressed: () => _retire(context),
              child: Text('Retired / walkover', style: tfStyle(13.5, color: AppColors.negative)),
            ),
          ]),
        ],
      ],
    );
  }

  void _retire(BuildContext context) {
    final c = controller;
    Get.bottomSheet(
      Builder(
          builder: (sheet) => SheetFrame(title: 'End the match', children: [
                Text('Who wins? The other side retired or did not play.', style: tfStyle(13.5, color: Colors.white.withAlpha(170))),
                gapH(12),
                for (final t in [s.setup.homeEntry, s.setup.awayEntry]) ...[
                  SizedBox(
                    width: double.infinity,
                    child: SmallButtonLarge(
                        label: '${c.teamName(t)} win',
                        onTap: () {
                          Navigator.of(sheet).pop();
                          c.endMatch(winner: t, text: '{$t} won (retired)');
                        }),
                  ),
                  gapH(8),
                ],
              ])),
      isScrollControlled: true,
    );
  }
}
