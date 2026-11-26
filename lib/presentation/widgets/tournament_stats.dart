import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../data/models/tournament.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/tournament_controller.dart';
import 'match_awards.dart' show AwardPlayerCard, AwardStrip;
import 'tournament_form_widgets.dart';

List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

/// Leaderboard categories: key in the server response, title, the value shown, and an optional detail.
final _boards = <(String, String, String Function(Map<String, dynamic>), String Function(Map<String, dynamic>)?)>[
  ('series_points', 'Player of the Series race', (p) => '${p['points']}', (p) => '${p['reason'] ?? ''}'),
  ('most_runs', 'Most runs', (p) => '${p['runs']}', (p) => '${p['innings']} inns · SR ${p['strike_rate'] ?? '-'}'),
  ('most_wickets', 'Most wickets', (p) => '${p['wickets']}', (p) => '${p['overs']} ov · Econ ${p['economy'] ?? '-'}'),
  ('highest_score', 'Highest score', (p) => '${p['highest']}', null),
  ('best_bowling', 'Best bowling', (p) => '${p['best']}', null),
  ('most_sixes', 'Most sixes', (p) => '${p['sixes']}', null),
  ('best_strike_rate', 'Best strike rate', (p) => '${p['strike_rate']}', (p) => '${p['runs']} off ${p['balls']}'),
  ('best_economy', 'Best economy', (p) => '${p['economy']}', (p) => '${p['overs']} overs'),
  ('best_fielding', 'Best fielding', (p) => '${(p['catches'] as num? ?? 0) + (p['run_outs'] as num? ?? 0)}', (p) => _fieldingLine(p)),
];

String _fieldingLine(Map<String, dynamic> p) {
  final c = (p['catches'] as num? ?? 0).toInt(), r = (p['run_outs'] as num? ?? 0).toInt();
  return [if (c > 0) '$c catch${c == 1 ? '' : 'es'}', if (r > 0) '$r run out${r == 1 ? '' : 's'}'].join(' · ');
}

final _footballBoards = <(String, String, String Function(Map<String, dynamic>), String Function(Map<String, dynamic>)?)>[
  ('mvp', 'MVP points', (p) => '${p['points']}', (p) => '${p['goals']} G · ${p['assists']} A · ${p['potm']} POTM'),
  ('top_scorers', 'Top scorers', (p) => '${p['goals']}', (p) => '${p['assists']} assists'),
  ('most_assists', 'Most assists', (p) => '${p['assists']}', null),
  ('clean_sheets', 'Clean sheets', (p) => '${p['clean_sheets']}', null),
  ('player_of_match', 'Player of the Match awards', (p) => '${p['potm']}', null),
  ('yellow_cards', 'Yellow cards', (p) => '${p['yellow']}', null),
  ('red_cards', 'Red cards', (p) => '${p['red']}', null),
];

class StatsTabBody extends GetView<TournamentController> {
  final Tournament t;
  const StatsTabBody({super.key, required this.t});

  // Opening the tab loads the stats (TournamentController watches the tab).
  @override
  Widget build(BuildContext context) => Obx(() => PlayerStatsView(
        stats: controller.stats.value,
        loading: controller.statsLoading.value,
        sport: t.sport,
        division: controller.statsDivision.value,
        onDivision: (id) => controller.statsDivision.value = id,
      ));
}

/// Player stats for a tournament or a quick match session (the same server stats): Player of the Series / Tournament,
/// then the leaderboards. [session] names the award for a quick match session.
class PlayerStatsView extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final bool loading;
  final String sport;
  final int? division;
  final ValueChanged<int>? onDivision;
  final bool session;
  const PlayerStatsView(
      {super.key, required this.stats, required this.loading, required this.sport, this.division, this.onDivision, this.session = false});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (loading || s == null) {
      return Padding(padding: EdgeInsets.only(top: SizeConfig.h(30)), child: const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (sport != 'CRICKET' && sport != 'FOOTBALL') return _note('Player stats for ${sport.toLowerCase()} are coming soon.');
    final football = sport == 'FOOTBALL';
    final divisions = _maps(s['divisions']);
    if (divisions.isEmpty || divisions.every((d) => (d['matches'] as num? ?? 0) == 0)) {
      return _note('Stats appear here once the first match is scored: top run-scorers, wicket-takers and more.');
    }
    final teams = {for (final x in _maps(s['teams'])) x['entry_id'] as int: x};
    final mine = {...(s['my_entry_ids'] as List? ?? []).map((v) => v as int)};
    final selected = divisions.firstWhereOrNull((d) => d['id'] == division) ?? divisions.first;
    final leaders = Map<String, dynamic>.from(selected['leaders'] as Map? ?? {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (divisions.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final d in divisions)
                Padding(
                  padding: EdgeInsets.only(right: SizeConfig.w(8)),
                  child: GestureDetector(
                    onTap: () => onDivision?.call(d['id'] as int),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(7)),
                      decoration: BoxDecoration(
                        color: d == selected ? AppColors.primary.withAlpha(40) : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                        border: Border.all(color: d == selected ? AppColors.primary : Colors.white.withAlpha(20)),
                      ),
                      child: Text('${d['name']}', style: tfStyle(12.5, weight: FontWeight.w700)),
                    ),
                  ),
                ),
            ]),
          ),
          gapH(14),
        ],
        if (_awards(selected, leaders, teams, Map<String, dynamic>.from(s['people'] as Map? ?? {}), football, session: session).isNotEmpty) ...[
          AwardStrip(
              heading: session ? 'SESSION AWARDS' : 'SERIES AWARDS',
              cards: _awards(selected, leaders, teams, Map<String, dynamic>.from(s['people'] as Map? ?? {}), football, session: session)),
          gapH(16),
        ],
        for (final (key, title, value, detail) in football ? _footballBoards : _boards)
          if (_maps(leaders[key]).isNotEmpty) ...[
            _Board(
              key: ValueKey('stats-$key'),
              title: session && key == 'series_points' ? 'Player of the Session race' : title,
              rows: _maps(leaders[key]),
              value: value,
              detail: detail,
              teams: teams,
              mine: mine,
            ),
            gapH(12),
          ],
        Text(
          football
              ? 'MVP points: goal 3, assist 2, clean sheet 3, Player of the Match 3, yellow −1, red −3.'
              : 'Points: runs, plus a bonus for scoring faster than the average; 4 a wicket, plus a bonus for a tighter over than '
                  'the average; 1 a catch / stumping / run out. Strike rate needs 10 balls faced; economy needs 2 overs bowled.',
          style: tfStyle(11.5, color: Colors.white.withAlpha(120), height: 1.4),
        ),
      ],
    );
  }

  Widget _note(String text) => FormCard(
        padding: EdgeInsets.all(SizeConfig.r(16)),
        child: Row(children: [
          Icon(Icons.leaderboard_rounded, color: Colors.white.withAlpha(140), size: SizeConfig.r(20)),
          SizedBox(width: SizeConfig.w(10)),
          Expanded(child: Text(text, style: tfStyle(13, color: Colors.white.withAlpha(160), height: 1.45))),
        ]),
      );
}

/// The series' award cards: Player of the Series (or the race leader until every match is played), best batter,
/// bowler and fielder (football: top scorer, most assists, best keeper). Each opens the player's page.
List<Widget> _awards(Map<String, dynamic> division, Map<String, dynamic> leaders, Map<int, Map<String, dynamic>> teams,
    Map<String, dynamic> people, bool football, {bool session = false}) {
  Map<String, dynamic>? top(String key) => _maps(leaders[key]).firstOrNull;
  Widget card(String title, IconData icon, Color color, Map<String, dynamic> p, String stat) {
    final who = people['${p['member_id']}'] as Map?;
    return AwardPlayerCard(
      title: title,
      icon: icon,
      color: color,
      name: p['name']?.toString() ?? 'Player',
      team: teams[p['entry_id']]?['name']?.toString() ?? '',
      photoUrl: who?['photo_url']?.toString(),
      userId: (who?['user_id'] as num?)?.toInt(),
      stat: stat,
      sport: football ? 'FOOTBALL' : 'CRICKET',
      kind: session ? 'QUICK' : 'TOURNAMENT',
    );
  }

  final pot = division['player_of_tournament'] is Map ? Map<String, dynamic>.from(division['player_of_tournament'] as Map) : null;
  final potTitle = pot?['final'] != true
      ? 'LEADING THE RACE'
      : session
          ? 'PLAYER OF THE SESSION'
          : football
              ? 'PLAYER OF THE TOURNAMENT'
              : 'PLAYER OF THE SERIES';
  if (football) {
    final scorer = top('top_scorers'), assists = top('most_assists'), keeper = top('clean_sheets');
    return [
      if (pot != null) card(potTitle, Icons.workspace_premium_rounded, AwardPlayerCard.gold, pot, '${pot['points']} MVP points'),
      if (scorer != null) card('TOP SCORER', Icons.sports_soccer_rounded, AwardPlayerCard.amber, scorer, '${scorer['goals']} goals'),
      if (assists != null) card('MOST ASSISTS', Icons.handshake_rounded, AwardPlayerCard.sky, assists, '${assists['assists']} assists'),
      if (keeper != null) card('BEST KEEPER', Icons.back_hand_rounded, AwardPlayerCard.green, keeper, '${keeper['clean_sheets']} clean sheets'),
    ];
  }
  final bat = top('most_runs'), bowl = top('most_wickets'), field = top('best_fielding');
  return [
    if (pot != null) card(potTitle, Icons.workspace_premium_rounded, AwardPlayerCard.gold, pot, '${pot['reason'] ?? ''}\n${pot['points']} points'),
    if (bat != null) card('BEST BATTER', Icons.sports_cricket_rounded, AwardPlayerCard.amber, bat, '${bat['runs']} runs · SR ${bat['strike_rate'] ?? '-'}'),
    if (bowl != null && (bowl['wickets'] as num? ?? 0) > 0)
      card('BEST BOWLER', Icons.track_changes_rounded, AwardPlayerCard.sky, bowl, '${bowl['wickets']} wickets · Econ ${bowl['economy'] ?? '-'}'),
    if (field != null) card('BEST FIELDER', Icons.back_hand_rounded, AwardPlayerCard.green, field, _fieldingLine(field)),
  ];
}

class _Board extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) value;
  final String Function(Map<String, dynamic>)? detail;
  final Map<int, Map<String, dynamic>> teams;
  final Set<int> mine;
  const _Board({super.key, required this.title, required this.rows, required this.value, this.detail, required this.teams, required this.mine});

  @override
  Widget build(BuildContext context) {
    final top = rows.first;
    return GestureDetector(
      onTap: () => _showAll(),
      child: FormCard(
        padding: EdgeInsets.all(SizeConfig.r(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title.toUpperCase(), style: tfStyle(11, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.6))),
            if (rows.length > 1) Text('Top ${rows.length} ›', style: tfStyle(11.5, color: Colors.white.withAlpha(140))),
          ]),
          gapH(8),
          Row(children: [
            _Logo(url: teams[top['entry_id']]?['logo_url'] as String?, size: 40),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${top['name']}', style: tfStyle(15, weight: FontWeight.w800, color: mine.contains(top['entry_id']) ? AppColors.primary : Colors.white)),
                Text(
                  [teams[top['entry_id']]?['name'] ?? '', if (detail != null) detail!(top)].where((x) => '$x'.isNotEmpty).join(' · '),
                  style: tfStyle(12, color: Colors.white.withAlpha(140)),
                ),
              ]),
            ),
            Text(value(top), style: tfStyle(26, weight: FontWeight.w900)),
          ]),
          for (final (i, p) in rows.skip(1).take(2).indexed) ...[
            gapH(8),
            Row(children: [
              SizedBox(width: SizeConfig.w(20), child: Text('${i + 2}', style: tfStyle(12, color: Colors.white.withAlpha(120)))),
              Expanded(
                child: Text('${p['name']} · ${teams[p['entry_id']]?['short'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tfStyle(13, weight: FontWeight.w600, color: mine.contains(p['entry_id']) ? AppColors.primary : Colors.white)),
              ),
              Text(value(p), style: tfStyle(14, weight: FontWeight.w800)),
            ]),
          ],
        ]),
      ),
    );
  }

  void _showAll() {
    Get.bottomSheet(
      SheetFrame(title: title, children: [
        for (final (i, p) in rows.indexed)
          Padding(
            padding: EdgeInsets.symmetric(vertical: SizeConfig.h(7)),
            child: Row(children: [
              SizedBox(width: SizeConfig.w(24), child: Text('${i + 1}', style: tfStyle(13, color: Colors.white.withAlpha(130)))),
              _Logo(url: teams[p['entry_id']]?['logo_url'] as String?, size: 28),
              SizedBox(width: SizeConfig.w(10)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['name']}', style: tfStyle(14, weight: FontWeight.w700, color: mine.contains(p['entry_id']) ? AppColors.primary : Colors.white)),
                  Text([teams[p['entry_id']]?['name'] ?? '', if (detail != null) detail!(p)].where((x) => '$x'.isNotEmpty).join(' · '),
                      style: tfStyle(11.5, color: Colors.white.withAlpha(130))),
                ]),
              ),
              Text(value(p), style: tfStyle(17, weight: FontWeight.w900)),
            ]),
          ),
      ]),
      isScrollControlled: true,
    );
  }
}

class _Logo extends StatelessWidget {
  final String? url;
  final double size;
  const _Logo({required this.url, required this.size});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(SizeConfig.r(8)),
        child: SizedBox(
          width: SizeConfig.r(size),
          height: SizeConfig.r(size),
          child: url != null
              ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A)))
              : const ColoredBox(color: Color(0xFF2A2A2A)),
        ),
      );
}
