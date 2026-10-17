import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import 'tournament_form_widgets.dart';

/// Pieces that show a cricket match from its live JSON (made by the scoring engine).

List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

/// Colour for a ball in "this over": wicket red, boundary orange, extras amber.
Color ballColor(String s) {
  if (s.contains('W') && !s.contains('Wd')) return AppColors.negative;
  if (s == '4' || s == '6') return AppColors.primary;
  if (s.contains('Wd') || s.contains('Nb') || s.contains('B') || s.contains('Lb')) return const Color(0xFFFFB74D);
  return Colors.white.withAlpha(40);
}

class BallChip extends StatelessWidget {
  final String symbol;
  final double size;
  const BallChip(this.symbol, {super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final c = ballColor(symbol);
    final strong = c != Colors.white.withAlpha(40);
    return Container(
      width: SizeConfig.r(size),
      height: SizeConfig.r(size),
      margin: EdgeInsets.only(right: SizeConfig.w(6)),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: strong ? c : c, shape: BoxShape.circle),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Text(symbol, style: tfStyle(12, weight: FontWeight.w800, color: strong && c != const Color(0xFFFFB74D) ? Colors.white : Colors.black)),
        ),
      ),
    );
  }
}

/// Big score at the top: team, runs/wickets, overs, target and run rates.
class LiveScoreHeader extends StatelessWidget {
  final Map<String, dynamic> live;
  final String Function(int?) teamName;
  final String Function(String?) fill;
  const LiveScoreHeader({super.key, required this.live, required this.teamName, required this.fill});

  @override
  Widget build(BuildContext context) {
    final innings = _maps(live['innings']);
    final current = live['current'] is Map ? Map<String, dynamic>.from(live['current'] as Map) : null;
    final status = live['status']?.toString() ?? 'NOT_STARTED';
    final shown = innings.isEmpty ? null : innings.last;
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in innings)
            Padding(
              padding: EdgeInsets.only(bottom: SizeConfig.h(4)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(teamName(i['batting_entry_id'] as int?),
                        style: tfStyle(i == shown && status != 'COMPLETED' ? 15 : 13.5, weight: FontWeight.w700, color: i == shown ? Colors.white : Colors.white.withAlpha(160))),
                  ),
                  Text('${i['runs']}/${i['wickets']}',
                      style: tfStyle(i == shown && status != 'COMPLETED' ? 30 : 18, weight: FontWeight.w900, color: i == shown ? Colors.white : Colors.white.withAlpha(170))),
                  SizedBox(width: SizeConfig.w(6)),
                  Padding(
                    padding: EdgeInsets.only(bottom: SizeConfig.h(4)),
                    child: Text('(${i['overs']})', style: tfStyle(12.5, color: Colors.white.withAlpha(150))),
                  ),
                ],
              ),
            ),
          if (innings.isEmpty) Text('Match not started', style: tfStyle(16, weight: FontWeight.w700)),
          gapH(6),
          if (status == 'COMPLETED' || status == 'TIE_DECISION')
            Text(fill(live['result']?.toString()), style: tfStyle(14, weight: FontWeight.w800, color: AppColors.primary))
          else if (status == 'INNINGS_BREAK')
            Text('Innings break · ${teamName(innings.isNotEmpty ? innings.last['bowling_entry_id'] as int? : null)} need ${(innings.last['runs'] as int) + 1} to win',
                style: tfStyle(13.5, weight: FontWeight.w700, color: AppColors.primary))
          else if (current != null) ...[
            Text(
              [
                'CRR ${shown?['run_rate'] ?? 0}',
                if (current['need'] != null) 'Need ${current['need']} from ${current['balls_left']} balls',
                if (current['required_rate'] != null) 'RRR ${current['required_rate']}',
              ].join('  ·  '),
              style: tfStyle(12.5, color: Colors.white.withAlpha(170)),
            ),
            if (current['free_hit'] == true) ...[
              gapH(4),
              Text('FREE HIT', style: tfStyle(12, weight: FontWeight.w900, color: AppColors.primary)),
            ],
          ],
        ],
      ),
    );
  }
}

/// Batters at the crease, the bowler and this over.
class CurrentPlayers extends StatelessWidget {
  final Map<String, dynamic> current;
  const CurrentPlayers({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    Widget batter(dynamic b, bool onStrike) {
      if (b is! Map) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.symmetric(vertical: SizeConfig.h(3)),
        child: Row(children: [
          SizedBox(width: SizeConfig.w(14), child: onStrike ? Icon(Icons.sports_cricket, size: SizeConfig.r(13), color: AppColors.primary) : null),
          Expanded(child: Text('${b['name']}', style: tfStyle(14, weight: onStrike ? FontWeight.w800 : FontWeight.w600))),
          Text('${b['runs']}', style: tfStyle(15, weight: FontWeight.w900)),
          Text(' (${b['balls']})', style: tfStyle(12, color: Colors.white.withAlpha(140))),
          SizedBox(width: SizeConfig.w(10)),
          SizedBox(width: SizeConfig.w(56), child: Text('${b['fours']}×4 ${b['sixes']}×6', textAlign: TextAlign.right, style: tfStyle(11, color: Colors.white.withAlpha(120)))),
        ]),
      );
    }

    final bowler = current['bowler'];
    final over = (current['this_over'] as List? ?? []).map((e) => '$e').toList();
    final p = current['partnership'] is Map ? current['partnership'] as Map : const {};
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          batter(current['striker'], true),
          batter(current['non_striker'], false),
          Text('Partnership ${p['runs'] ?? 0} (${p['balls'] ?? 0})', style: tfStyle(11.5, color: Colors.white.withAlpha(110))),
          Divider(height: SizeConfig.h(16), color: Colors.white.withAlpha(14)),
          if (bowler is Map)
            Row(children: [
              Icon(Icons.sports_baseball_rounded, size: SizeConfig.r(14), color: Colors.white.withAlpha(150)),
              SizedBox(width: SizeConfig.w(8)),
              Expanded(child: Text('${bowler['name']}', style: tfStyle(14, weight: FontWeight.w700))),
              Text('${bowler['wickets']}-${bowler['runs']}', style: tfStyle(15, weight: FontWeight.w900)),
              Text(' (${bowler['overs']})', style: tfStyle(12, color: Colors.white.withAlpha(140))),
            ])
          else
            Text('New over: pick the bowler', style: tfStyle(13, color: AppColors.primary)),
          gapH(10),
          SizedBox(
            height: SizeConfig.r(30),
            child: over.isEmpty
                ? Text('This over: no balls yet', style: tfStyle(12, color: Colors.white.withAlpha(120)))
                : ListView(scrollDirection: Axis.horizontal, children: [for (final b in over) BallChip(b)]),
          ),
        ],
      ),
    );
  }
}

/// Full scorecard for every innings: batting, extras, bowling, fall of wickets.
class Scorecard extends StatelessWidget {
  final Map<String, dynamic> live;
  final String Function(int?) teamName;
  const Scorecard({super.key, required this.live, required this.teamName});

  @override
  Widget build(BuildContext context) {
    final innings = _maps(live['innings']);
    if (innings.isEmpty) return Text('The scorecard appears when the match starts.', style: tfStyle(13, color: Colors.white.withAlpha(140)));
    TextStyle head = tfStyle(11, weight: FontWeight.w800, color: Colors.white.withAlpha(120));
    Widget cells(List<String> v, {TextStyle? style, bool bold = false}) => Row(children: [
          Expanded(child: Text(v[0], style: style ?? tfStyle(13, weight: bold ? FontWeight.w700 : FontWeight.w500))),
          for (final x in v.skip(1))
            SizedBox(width: SizeConfig.w(38), child: Text(x, textAlign: TextAlign.right, style: style ?? tfStyle(13, weight: bold ? FontWeight.w800 : FontWeight.w500))),
        ]);
    return Column(
      children: [
        for (final i in innings) ...[
          FormCard(
            padding: EdgeInsets.all(SizeConfig.r(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(teamName(i['batting_entry_id'] as int?), style: tfStyle(15, weight: FontWeight.w800))),
                  Text('${i['runs']}/${i['wickets']} (${i['overs']})', style: tfStyle(15, weight: FontWeight.w900, color: AppColors.primary)),
                ]),
                gapH(10),
                cells(['BATTING', 'R', 'B', '4s', '6s', 'SR'], style: head),
                for (final b in _maps(i['batting'])) ...[
                  gapH(6),
                  cells(['${b['name']}', '${b['runs']}', '${b['balls']}', '${b['fours']}', '${b['sixes']}', '${b['strike_rate']}'], bold: b['out'] != true),
                  Text('${b['how_out']}', style: tfStyle(11, color: Colors.white.withAlpha(120))),
                ],
                gapH(8),
                Builder(builder: (_) {
                  final e = Map<String, dynamic>.from(i['extras'] as Map? ?? {});
                  return Text('Extras ${e['total'] ?? 0} (w ${e['wides'] ?? 0}, nb ${e['no_balls'] ?? 0}, b ${e['byes'] ?? 0}, lb ${e['leg_byes'] ?? 0})',
                      style: tfStyle(12, color: Colors.white.withAlpha(150)));
                }),
                if ((i['yet_to_bat'] as List? ?? []).isNotEmpty) ...[
                  gapH(4),
                  Text('Yet to bat: ${(i['yet_to_bat'] as List).join(', ')}', style: tfStyle(12, color: Colors.white.withAlpha(120))),
                ],
                Divider(height: SizeConfig.h(22), color: Colors.white.withAlpha(14)),
                cells(['BOWLING', 'O', 'M', 'R', 'W', 'Eco'], style: head),
                for (final b in _maps(i['bowling'])) ...[
                  gapH(6),
                  cells(['${b['name']}', '${b['overs']}', '${b['maidens']}', '${b['runs']}', '${b['wickets']}', '${b['economy']}']),
                ],
                if (_maps(i['fall_of_wickets']).isNotEmpty) ...[
                  gapH(12),
                  Text('FALL OF WICKETS', style: head),
                  gapH(4),
                  Text(_maps(i['fall_of_wickets']).map((f) => '${f['score']}-${f['wicket']} (${f['name']}, ${f['over']})').join(' · '),
                      style: tfStyle(12, color: Colors.white.withAlpha(170), height: 1.4)),
                ],
              ],
            ),
          ),
          gapH(12),
        ],
      ],
    );
  }
}

/// Latest balls first.
class Commentary extends StatelessWidget {
  final Map<String, dynamic> live;
  const Commentary({super.key, required this.live});

  @override
  Widget build(BuildContext context) {
    final items = _maps(live['commentary']);
    if (items.isEmpty) return Text('Ball-by-ball commentary appears here.', style: tfStyle(13, color: Colors.white.withAlpha(140)));
    return Column(
      children: [
        for (final c in items)
          Padding(
            padding: EdgeInsets.symmetric(vertical: SizeConfig.h(6)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: SizeConfig.w(38), child: Text('${c['over']}', style: tfStyle(12.5, weight: FontWeight.w700, color: Colors.white.withAlpha(150)))),
              BallChip('${c['symbol']}', size: 26),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${c['bowler']} to ${c['batter']}', style: tfStyle(12, color: Colors.white.withAlpha(140))),
                  Text('${c['text']}', style: tfStyle(13.5, weight: FontWeight.w700)),
                ]),
              ),
              Text('${c['score']}', style: tfStyle(12, color: Colors.white.withAlpha(130))),
            ]),
          ),
      ],
    );
  }
}
