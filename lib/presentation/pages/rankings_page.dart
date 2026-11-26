import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/sports.dart';
import '../../data/services/api_service.dart';
import '../../data/services/session_service.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/rankings_controller.dart';
import '../widgets/tournament_form_widgets.dart';

/// My stats and the rankings, for tournaments or quick matches (never mixed), with filters.
class RankingsPage extends GetView<RankingsController> {
  const RankingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: c.load,
          child: Obx(() {
            final d = c.data.value;
            final cricket = c.sport.value == 'CRICKET';
            final me = Map<String, dynamic>.from(d?['me'] as Map? ?? {});
            final row = me['row'] is Map ? Map<String, dynamic>.from(me['row'] as Map) : null;
            final ranks = Map<String, dynamic>.from(me['ranks'] as Map? ?? {});
            final lists = Map<String, dynamic>.from(d?['lists'] as Map? ?? {});
            final rows = (lists[c.list.value] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
            final myId = row?['user_id'];
            return ListView(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(16), SizeConfig.h(8), SizeConfig.w(16), SizeConfig.h(40)),
              children: [
                Row(children: [
                  IconButton(onPressed: Get.back, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                  Expanded(child: Text(c.tab.value == 'ME' ? 'My stats' : 'Rankings', style: tfStyle(22, weight: FontWeight.w900))),
                ]),
                gapH(8),
                // My own stats and the rankings are separate tabs.
                _Segment(options: const [('ME', 'My stats'), ('RANKS', 'Rankings')], selected: c.tab.value, onSelected: (v) => c.tab.value = v),
                gapH(12),
                // Sport and tournament / quick match: separate stats.
                if (c.sports.length > 1) ...[
                  ChoiceChips(
                      options: [for (final s in c.sports) (s, Sports.byCode(s)?.label ?? s)], selected: c.sport.value, onSelected: c.setSport),
                  gapH(8),
                ],
                _Segment(
                  options: const [('TOURNAMENT', 'Tournaments'), ('QUICK', 'Quick matches')],
                  selected: c.kind.value,
                  onSelected: c.setKind,
                ),
                gapH(14),
                if (c.tab.value == 'ME') ...[
                  if (c.isLoading.value && d == null)
                    Padding(
                        padding: EdgeInsets.only(top: SizeConfig.h(40)),
                        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)))
                  else if (c.error.value != null && d == null)
                    _note(c.error.value!)
                  else
                    PlayerStatsCards(row: row, cricket: cricket, quick: c.kind.value == 'QUICK'),
                ] else ...[
                  Row(children: [
                    Expanded(child: Text('RANKINGS', style: tfStyle(12, weight: FontWeight.w800, color: Colors.white.withAlpha(140)))),
                    GestureDetector(
                      key: const ValueKey('rank-filters'),
                      onTap: () => _filters(context, d),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(7)),
                        decoration: BoxDecoration(
                          color: c.filterCount > 0 ? AppColors.primary.withAlpha(35) : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                          border: Border.all(color: c.filterCount > 0 ? AppColors.primary : Colors.white.withAlpha(25)),
                        ),
                        child: Row(children: [
                          Icon(Icons.tune_rounded, size: SizeConfig.r(16), color: AppColors.primary),
                          SizedBox(width: SizeConfig.w(6)),
                          Text(c.filterCount > 0 ? 'Filters · ${c.filterCount}' : 'Filters', style: tfStyle(12.5, weight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ]),
                  if (c.city.value.isNotEmpty) ...[
                    gapH(6),
                    Text([c.block.value, c.city.value].where((x) => x.isNotEmpty).join(', '), style: tfStyle(12.5, color: AppColors.primary)),
                  ],
                  gapH(10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ChoiceChips(options: c.lists, selected: c.list.value, onSelected: (v) => c.list.value = v),
                  ),
                  gapH(10),
                  if (c.isLoading.value && d == null)
                    Padding(
                        padding: EdgeInsets.only(top: SizeConfig.h(40)),
                        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)))
                  else if (c.error.value != null && d == null)
                    _note(c.error.value!)
                  else if (rows.isEmpty)
                    _note(c.city.value.isNotEmpty
                        ? 'No ranked players in this area yet. Players appear here once they add their pincode and play ${d?['min'] ?? 3} matches.'
                        : 'Nobody is ranked yet. Players need ${d?['min'] ?? 3} completed matches to be ranked.')
                  else ...[
                    for (final r in rows) _RankRow(r: r, list: c.list.value, cricket: cricket, mine: r['user_id'] == myId, kind: c.kind.value),
                    if (row != null && !rows.any((r) => r['user_id'] == myId) && ranks[c.list.value] != null) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: SizeConfig.h(4)),
                        child: Center(child: Text('· · ·', style: tfStyle(14, color: Colors.white.withAlpha(90)))),
                      ),
                      _RankRow(r: {...row, 'rank': ranks[c.list.value]}, list: c.list.value, cricket: cricket, mine: true, kind: c.kind.value),
                    ],
                  ],
                ],
                gapH(14),
                Text(
                  cricket
                      ? 'Overall points: runs, plus a bonus for scoring faster than the average; 4 a wicket, plus a bonus for a tighter '
                          'over than the average; 1 a catch / stumping / run out. Players need ${d?['min'] ?? 3} matches to be ranked.'
                      : 'MVP points: goal 3, assist 2, clean sheet 3, Player of the Match 3, yellow −1, red −3. '
                          'Players need ${d?['min'] ?? 3} matches to be ranked.',
                  style: tfStyle(11.5, color: Colors.white.withAlpha(120), height: 1.4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _note(String text) => FormCard(
        padding: EdgeInsets.all(SizeConfig.r(16)),
        child: Text(text, style: tfStyle(13, color: Colors.white.withAlpha(160), height: 1.45)),
      );

  void _filters(BuildContext context, Map<String, dynamic>? d) {
    final c = controller;
    final f = Map<String, dynamic>.from(d?['filters'] as Map? ?? {});
    final cities = (f['cities'] as List? ?? []).map((e) => '$e').toList();
    final blocks = (f['blocks'] as List? ?? []).map((e) => '$e').toList();
    final hasPincode = Get.find<SessionService>().user.value?.pincode != null;
    Get.bottomSheet(
      Obx(() => SheetFrame(title: 'Filters', children: [
            const FormLabel('Area'),
            if (cities.isEmpty)
              Text(
                  hasPincode
                      ? 'Areas appear once players with stats have added their pincode.'
                      : 'Add your pincode in Profile → Area & food to see where you rank in your area.',
                  style: tfStyle(12.5, color: Colors.white.withAlpha(150), height: 1.4))
            else ...[
              ChoiceChips(
                  options: [('', 'Everywhere'), for (final x in cities) (x, x)], selected: c.city.value, onSelected: (v) => c.setFilters(city: v)),
              if (c.city.value.isNotEmpty && blocks.isNotEmpty) ...[
                gapH(8),
                ChoiceChips(
                    options: [('', 'All of ${c.city.value}'), for (final x in blocks) (x, x)],
                    selected: c.block.value,
                    onSelected: (v) => c.setFilters(block: v)),
              ],
            ],
            gapH(14),
            const FormLabel('Time'),
            ChoiceChips(
                options: const [('ALL', 'All time'), ('YEAR', 'This year'), ('90D', 'Last 90 days')],
                selected: c.period.value,
                onSelected: (v) => c.setFilters(period: v)),
            gapH(14),
            const FormLabel('Age'),
            ChoiceChips(
                options: const [('ALL', 'All'), ('U16', 'Under 16'), ('U19', 'Under 19'), ('19_35', '19–35'), ('35P', '35+')],
                selected: c.age.value,
                onSelected: (v) => c.setFilters(age: v)),
            gapH(14),
            const FormLabel('Gender'),
            ChoiceChips(
                options: const [('ALL', 'All'), ('MALE', 'Men'), ('FEMALE', 'Women')],
                selected: c.gender.value,
                onSelected: (v) => c.setFilters(gender: v)),
            if (c.sport.value == 'CRICKET') ...[
              gapH(14),
              const FormLabel('Ball'),
              ChoiceChips(
                  options: const [('ALL', 'All'), ('TENNIS', 'Tennis'), ('LEATHER', 'Leather')],
                  selected: c.ball.value,
                  onSelected: (v) => c.setFilters(ball: v)),
            ],
            if (c.filterCount > 0) ...[
              gapH(12),
              Center(
                  child: TextButton(
                      onPressed: c.clearFilters,
                      child: Text('Clear filters', style: tfStyle(13.5, weight: FontWeight.w700, color: AppColors.primary)))),
            ],
          ])),
      isScrollControlled: true,
    );
  }
}

class _Segment extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const _Segment({required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(SizeConfig.r(4)),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(14))),
        child: Row(children: [
          for (final (v, l) in options)
            Expanded(
              child: GestureDetector(
                key: ValueKey('rank-kind-$v'),
                onTap: () => onSelected(v),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: SizeConfig.h(10)),
                  decoration: BoxDecoration(
                    color: v == selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(SizeConfig.r(11)),
                  ),
                  child: Center(child: Text(l, style: tfStyle(13.5, weight: FontWeight.w800))),
                ),
              ),
            ),
        ]),
      );
}

/// A player's numbers for one sport and kind (My stats, and a player's page): highlight tiles, then batting / bowling /
/// fielding (or football) sections with icons, and an optional rank pill per section.
class PlayerStatsCards extends StatelessWidget {
  final Map<String, dynamic>? row;
  final bool cricket, quick;
  final Map<String, dynamic> ranks;
  const PlayerStatsCards({super.key, required this.row, required this.cricket, required this.quick, this.ranks = const {}});

  static const _gold = Color(0xFFFFC94D), _sky = Color(0xFF4FC3F7), _green = Color(0xFF66BB6A), _violet = Color(0xFFB388FF);

  @override
  Widget build(BuildContext context) {
    final r = row;
    if (r == null) {
      return Container(
        padding: EdgeInsets.all(SizeConfig.r(20)),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(18))),
        child: Column(children: [
          Icon(Icons.sports_rounded, color: Colors.white.withAlpha(90), size: SizeConfig.r(36)),
          gapH(8),
          Text('No completed ${quick ? 'quick matches' : 'tournament matches'} yet.',
              textAlign: TextAlign.center, style: tfStyle(14, weight: FontWeight.w700)),
          gapH(4),
          Text('Stats appear here after the first scored match.',
              textAlign: TextAlign.center, style: tfStyle(12.5, color: Colors.white.withAlpha(140))),
        ]),
      );
    }
    String v(Object? x) => x == null ? '—' : '$x';
    String? rank(String k) => ranks[k] != null ? '#${ranks[k]}' : null;
    if (!cricket) {
      return Column(children: [
        Row(children: [
          _HighlightTile(icon: Icons.sports_soccer_rounded, label: 'Goals', value: v(r['goals']), color: _gold),
          _HighlightTile(icon: Icons.assistant_navigation, label: 'Assists', value: v(r['assists']), color: _sky),
          _HighlightTile(icon: Icons.workspace_premium_rounded, label: 'Player of Match', value: v(r['potm']), color: _violet),
        ]),
        gapH(12),
        _StatSection(icon: Icons.bolt_rounded, title: 'Overall', color: AppColors.primary, rank: rank('overall'), stats: [
          ('Matches', v(r['matches'])),
          ('MVP points', v(r['points'])),
        ]),
        _StatSection(icon: Icons.shield_rounded, title: 'Defence', color: _green, rank: rank('clean_sheets'), stats: [
          ('Clean sheets', v(r['clean_sheets'])),
        ]),
        _StatSection(icon: Icons.style_rounded, title: 'Discipline', color: _gold, stats: [('Yellow', v(r['yellow'])), ('Red', v(r['red']))]),
      ]);
    }
    return Column(children: [
      Row(children: [
        _HighlightTile(icon: Icons.sports_cricket_rounded, label: 'Runs', value: v(r['runs']), color: _gold),
        _HighlightTile(icon: Icons.track_changes_rounded, label: 'Wickets', value: v(r['wickets']), color: _sky),
        _HighlightTile(icon: Icons.workspace_premium_rounded, label: 'Player of Match', value: v(r['potm']), color: _violet),
      ]),
      gapH(12),
      _StatSection(icon: Icons.sports_cricket_rounded, title: 'Batting', color: _gold, rank: rank('batting'), stats: [
        ('Innings', v(r['innings'])),
        ('Highest', v(r['highest'])),
        ('Average', v(r['average'])),
        ('Strike rate', v(r['strike_rate'])),
        ('Balls', v(r['balls'])),
        ('Fours', v(r['fours'])),
        ('Sixes', v(r['sixes'])),
        ('Fifties', v(r['fifties'])),
      ]),
      _StatSection(icon: Icons.track_changes_rounded, title: 'Bowling', color: _sky, rank: rank('bowling'), stats: [
        ('Overs', v(r['overs'])),
        ('Runs given', v(r['runs_conceded'])),
        ('Economy', v(r['economy'])),
        ('Best', v(r['best'])),
      ]),
      _StatSection(icon: Icons.back_hand_rounded, title: 'Fielding', color: _green, rank: rank('fielding'), stats: [
        ('Catches', v(r['catches'])),
        ('Run outs', v(r['run_outs'])),
        ('Matches', v(r['matches'])),
      ]),
    ]);
  }
}

class _HighlightTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _HighlightTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: SizeConfig.w(4)),
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(14), horizontal: SizeConfig.w(6)),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withAlpha(70), color.withAlpha(12)]),
            borderRadius: BorderRadius.circular(SizeConfig.r(18)),
            border: Border.all(color: color.withAlpha(110)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: SizeConfig.r(22)),
            gapH(6),
            FittedBox(child: Text(value, style: tfStyle(26, weight: FontWeight.w900))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(11, color: Colors.white.withAlpha(170))),
          ]),
        ),
      );
}

class _StatSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? rank;
  final List<(String, String)> stats;
  const _StatSection({required this.icon, required this.title, required this.color, required this.stats, this.rank});

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(bottom: SizeConfig.h(10)),
        padding: EdgeInsets.all(SizeConfig.r(14)),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(SizeConfig.r(18)),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: EdgeInsets.all(SizeConfig.r(6)),
              decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(SizeConfig.r(10))),
              child: Icon(icon, color: color, size: SizeConfig.r(16)),
            ),
            SizedBox(width: SizeConfig.w(8)),
            Expanded(child: Text(title.toUpperCase(), style: tfStyle(12.5, weight: FontWeight.w900).copyWith(letterSpacing: 1))),
            if (rank != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(3)),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                child: Text('$rank in ${title.toLowerCase()}', style: tfStyle(11, weight: FontWeight.w900, color: Colors.black)),
              ),
          ]),
          gapH(12),
          LayoutBuilder(builder: (_, box) {
            final w = (box.maxWidth - SizeConfig.w(8) * 3) / 4;
            return Wrap(spacing: SizeConfig.w(8), runSpacing: SizeConfig.h(12), children: [
              for (final (label, value) in stats)
                SizedBox(
                  width: w,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FittedBox(
                        fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: tfStyle(18, weight: FontWeight.w900))),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(10.5, color: Colors.white.withAlpha(140))),
                  ]),
                ),
            ]);
          }),
        ]),
      );
}

class _RankRow extends StatelessWidget {
  final Map<String, dynamic> r;
  final String list;
  final bool cricket, mine;
  final String kind;
  const _RankRow({required this.r, required this.list, required this.cricket, required this.mine, required this.kind});

  (String, String) get _value => switch (list) {
        'batting' => ('${r['runs']}', '${r['innings']} inns · SR ${r['strike_rate'] ?? '-'} · HS ${r['highest'] ?? '-'}'),
        'bowling' => ('${r['wickets']}', '${r['overs']} ov · Econ ${r['economy'] ?? '-'} · Best ${r['best'] ?? '-'}'),
        'fielding' => ('${(r['catches'] ?? 0) + (r['run_outs'] ?? 0)}', '${r['catches']} catches · ${r['run_outs']} run outs'),
        'goals' => ('${r['goals']}', '${r['assists']} assists · ${r['matches']} matches'),
        'assists' => ('${r['assists']}', '${r['goals']} goals · ${r['matches']} matches'),
        'clean_sheets' => ('${r['clean_sheets']}', '${r['matches']} matches'),
        _ => cricket
            ? ('${r['points']}', '${r['runs']} runs · ${r['wickets']} wkts · ${r['matches']} matches')
            : ('${r['points']}', '${r['goals']} G · ${r['assists']} A · ${r['potm']} POTM'),
      };

  @override
  Widget build(BuildContext context) {
    final (value, detail) = _value;
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    final medal = switch (rank) { 1 => const Color(0xFFFFC94D), 2 => const Color(0xFFCFD6DE), 3 => const Color(0xFFD9935B), _ => null };
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.player, arguments: {'user_id': r['user_id'], 'sport': cricket ? 'CRICKET' : 'FOOTBALL', 'kind': kind}),
      child: Container(
        key: ValueKey('rank-${r['user_id']}'),
        margin: EdgeInsets.only(bottom: SizeConfig.h(6)),
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(10)),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary.withAlpha(35) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(SizeConfig.r(12)),
          border: Border.all(color: mine ? AppColors.primary : Colors.transparent),
        ),
        child: Row(children: [
          SizedBox(
            width: SizeConfig.w(30),
            child: Text('$rank', style: tfStyle(15, weight: FontWeight.w900, color: medal ?? Colors.white.withAlpha(170))),
          ),
          Padding(
            padding: EdgeInsets.only(right: SizeConfig.w(10)),
            child: PlayerAvatar(url: r['photo_url'] as String?, name: '${r['name'] ?? ''}', size: 36, ring: medal ?? Colors.white.withAlpha(40), ringWidth: 1.5),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mine ? '${r['name']} (you)' : '${r['name']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w800)),
              Text([if (r['area'] != null) r['area'], detail].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(11.5, color: Colors.white.withAlpha(140))),
            ]),
          ),
          Text(value, style: tfStyle(18, weight: FontWeight.w900, color: AppColors.primary)),
        ]),
      ),
    );
  }
}

/// One player's stats as a player card: hero with photo and jersey number, role, overall rank and points, how their
/// points split between batting, bowling and fielding, then every number. Tournaments or quick matches (never mixed).
/// Arguments: {'user_id': 12, 'sport': 'CRICKET', 'kind': 'TOURNAMENT'}.
class PlayerStatsPage extends StatefulWidget {
  const PlayerStatsPage({super.key});

  @override
  State<PlayerStatsPage> createState() => _PlayerStatsPageState();
}

class _PlayerStatsPageState extends State<PlayerStatsPage> {
  late final int userId;
  late String sport, kind;
  Map<String, dynamic>? player;
  double par = 2;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    final a = Get.arguments is Map ? Get.arguments as Map : const {};
    userId = (a['user_id'] as num?)?.toInt() ?? 0;
    sport = a['sport'] as String? ?? 'CRICKET';
    kind = a['kind'] as String? ?? 'TOURNAMENT';
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await Get.find<ApiService>().getPlayerStats({'sport': sport, 'kind': kind, 'player': '$userId', 'brief': '1'});
      if (!mounted) return;
      setState(() {
        player = res['player'] is Map ? Map<String, dynamic>.from(res['player'] as Map) : null;
        par = (res['par'] as num?)?.toDouble() ?? 2;
        error = res['success'] == true ? (player == null ? 'Player not found.' : null) : (res['message']?.toString() ?? 'Could not load.');
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = player;
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.only(bottom: SizeConfig.h(40)),
          children: [
            if (p == null)
              SafeArea(
                child: Column(children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(onPressed: Get.back, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white))),
                  Padding(
                    padding: EdgeInsets.only(top: SizeConfig.h(60)),
                    child: loading ? const CircularProgressIndicator(color: AppColors.primary) : Text(error ?? 'Could not load.', style: tfStyle(14)),
                  ),
                ]),
              )
            else ...[
              _hero(p),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  gapH(16),
                  _Segment(
                    options: const [('TOURNAMENT', 'Tournaments'), ('QUICK', 'Quick matches')],
                    selected: kind,
                    onSelected: (v) {
                      if (v == kind) return;
                      setState(() => kind = v);
                      _load();
                    },
                  ),
                  gapH(14),
                  if (sport == 'CRICKET' && p['row'] is Map) ...[_split(Map<String, dynamic>.from(p['row'] as Map)), gapH(12)],
                  PlayerStatsCards(
                    row: p['row'] is Map ? Map<String, dynamic>.from(p['row'] as Map) : null,
                    cricket: sport == 'CRICKET',
                    quick: kind == 'QUICK',
                    ranks: p['ranked'] == true ? Map<String, dynamic>.from(p['ranks'] as Map? ?? {}) : const {},
                  ),
                  _played((p['tournaments'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Gradient hero: the jersey number large behind, the photo in a glowing ring, name, area, role, rank and points.
  Widget _hero(Map<String, dynamic> p) {
    final name = '${p['name'] ?? ''}';
    final row = p['row'] is Map ? Map<String, dynamic>.from(p['row'] as Map) : null;
    final ranks = Map<String, dynamic>.from(p['ranks'] as Map? ?? {});
    final overall = p['ranked'] == true ? (ranks['overall'] as num?)?.toInt() : null;
    final medal =
        switch (overall) { 1 => const Color(0xFFFFC94D), 2 => const Color(0xFFCFD6DE), 3 => const Color(0xFFD9935B), _ => AppColors.primary };
    final sportInfo = Sports.byCode(sport);
    final role = [
      if (p['role'] != null && sportInfo != null) Sports.labelOf(sportInfo.roles, p['role'] as String),
      if (sport == 'CRICKET' && p['batting_hand'] != null) Sports.labelOf(Sports.battingHands, p['batting_hand'] as String),
      if (sport == 'CRICKET' && p['bowling_style'] != null && p['bowling_style'] != 'NONE')
        Sports.labelOf(Sports.bowlingStyles, p['bowling_style'] as String),
    ];
    Widget chip(IconData icon, String text) => Container(
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(5)),
          decoration: BoxDecoration(color: Colors.black.withAlpha(70), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: SizeConfig.r(13), color: Colors.white.withAlpha(200)),
            SizedBox(width: SizeConfig.w(5)),
            Text(text, style: tfStyle(11.5, weight: FontWeight.w700)),
          ]),
        );
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [medal.withAlpha(150), AppColors.secondary]),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          // The jersey number, big and faint, behind the photo.
          if (p['jersey_number'] != null)
            Positioned(
              right: -SizeConfig.w(10),
              top: SizeConfig.h(10),
              child: Text('${p['jersey_number']}',
                  style: tfStyle(170, weight: FontWeight.w900, color: Colors.white.withAlpha(22)).copyWith(height: 1, letterSpacing: -8)),
            ),
          Column(children: [
            Align(
                alignment: Alignment.centerLeft,
                child: IconButton(onPressed: Get.back, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white))),
            Container(
              padding: EdgeInsets.all(SizeConfig.r(4)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [medal, Colors.white, medal]),
                boxShadow: [BoxShadow(color: medal.withAlpha(140), blurRadius: 30, spreadRadius: 2)],
              ),
              child: PlayerAvatar(url: p['photo_url'] as String?, name: name, size: 118, enlarge: true),
            ),
            gapH(14),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
              child: Text(name.toUpperCase(),
                  textAlign: TextAlign.center, style: tfStyle(26, weight: FontWeight.w900).copyWith(letterSpacing: 1.2, height: 1.1)),
            ),
            if (p['area'] != null) ...[
              gapH(4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.location_on_rounded, size: SizeConfig.r(14), color: Colors.white.withAlpha(170)),
                SizedBox(width: SizeConfig.w(3)),
                Text('${p['area']}', style: tfStyle(13, color: Colors.white.withAlpha(190))),
              ]),
            ],
            gapH(10),
            Wrap(alignment: WrapAlignment.center, spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
              if (p['jersey_number'] != null)
                chip(Icons.checkroom_rounded, '#${p['jersey_number']}${p['jersey_name'] != null ? ' · ${p['jersey_name']}' : ''}'),
              for (final x in role) chip(Icons.sports_rounded, x),
            ]),
            gapH(16),
            // Rank and points: the player-card numbers.
            Container(
              margin: EdgeInsets.symmetric(horizontal: SizeConfig.w(16)),
              padding: EdgeInsets.symmetric(vertical: SizeConfig.h(14)),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(90),
                borderRadius: BorderRadius.circular(SizeConfig.r(20)),
                border: Border.all(color: medal.withAlpha(140)),
              ),
              child: Row(children: [
                _heroNumber(overall != null ? '#$overall' : '—', overall != null ? 'Overall rank' : 'Not ranked yet', medal),
                Container(width: 1, height: SizeConfig.h(40), color: Colors.white.withAlpha(30)),
                _heroNumber('${row?['points'] ?? 0}', sport == 'CRICKET' ? 'Points' : 'MVP points', Colors.white),
                Container(width: 1, height: SizeConfig.h(40), color: Colors.white.withAlpha(30)),
                _heroNumber('${row?['matches'] ?? 0}', 'Matches', Colors.white),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  /// The tournaments (or quick-match sessions) they played, latest first; tap to open it.
  Widget _played(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    final quick = kind == 'QUICK', cricket = sport == 'CRICKET';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String when(String? d) {
      final t = DateTime.tryParse(d ?? '');
      return t == null ? '' : '${months[t.month - 1]} ${t.year}';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      gapH(8),
      Text(quick ? 'QUICK MATCHES PLAYED (${list.length})' : 'TOURNAMENTS PLAYED (${list.length})',
          style: tfStyle(12, weight: FontWeight.w900, color: Colors.white.withAlpha(160)).copyWith(letterSpacing: 1)),
      gapH(10),
      for (final t in list)
        GestureDetector(
          key: ValueKey('played-${t['code']}'),
          onTap: () => Get.toNamed(quick ? AppRoutes.quickMatch : AppRoutes.tournament, arguments: {'code': t['code']}),
          child: Container(
            margin: EdgeInsets.only(bottom: SizeConfig.h(8)),
            padding: EdgeInsets.all(SizeConfig.r(14)),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(16))),
            child: Row(children: [
              Container(
                width: SizeConfig.r(42),
                height: SizeConfig.r(42),
                decoration: BoxDecoration(
                    color: (quick ? AppColors.primary : const Color(0xFFFFC94D)).withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
                child: Icon(quick ? Icons.bolt_rounded : Icons.emoji_events_rounded,
                    color: quick ? AppColors.primary : const Color(0xFFFFC94D), size: SizeConfig.r(22)),
              ),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14.5, weight: FontWeight.w800)),
                  gapH(2),
                  Text([if (t['team'] != null) t['team'], when(t['last'] as String? ?? t['start'] as String?)].where((x) => '$x'.isNotEmpty).join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(12, color: Colors.white.withAlpha(150))),
                  gapH(6),
                  Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(4), children: [
                    _pill('${t['matches']} ${t['matches'] == 1 ? 'match' : 'matches'}'),
                    if (cricket) ...[
                      _pill('${t['runs']} runs'),
                      _pill('${t['wickets']} wkts'),
                    ] else ...[
                      _pill('${t['goals']} goals'),
                      _pill('${t['assists']} assists'),
                    ],
                    if ((t['potm'] as num? ?? 0) > 0) _pill('🏅 ${t['potm']} POTM'),
                  ]),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(110)),
            ]),
          ),
        ),
    ]);
  }

  Widget _pill(String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(8), vertical: SizeConfig.h(3)),
        decoration: BoxDecoration(color: Colors.white.withAlpha(14), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
        child: Text(text, style: tfStyle(11, weight: FontWeight.w700)),
      );

  Widget _heroNumber(String value, String label, Color color) => Expanded(
        child: Column(children: [
          Text(value, style: tfStyle(26, weight: FontWeight.w900, color: color)),
          Text(label, style: tfStyle(11, color: Colors.white.withAlpha(150))),
        ]),
      );

  /// Where the points come from (formula E parts): batting, bowling, fielding.
  Widget _split(Map<String, dynamic> r) {
    double n(String k) => (r[k] as num?)?.toDouble() ?? 0;
    final bat = (n('innings') > 0 ? n('runs') + 0.25 * (n('runs') - n('balls') * par) : 0.0).clamp(0, double.infinity).toDouble();
    final bowl =
        (4 * n('wickets') + (n('legal_balls') > 0 ? 0.75 * (n('legal_balls') * par - n('runs_conceded')) : 0)).clamp(0, double.infinity).toDouble();
    final field = n('catches') + n('run_outs');
    final total = bat + bowl + field;
    if (total <= 0) return const SizedBox.shrink();
    const colors = [Color(0xFFFFC94D), Color(0xFF4FC3F7), Color(0xFF66BB6A)];
    final parts = [('Batting', bat), ('Bowling', bowl), ('Fielding', field)];
    return Container(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WHERE THE POINTS COME FROM', style: tfStyle(11.5, weight: FontWeight.w900).copyWith(letterSpacing: 1)),
        gapH(10),
        ClipRRect(
          borderRadius: BorderRadius.circular(SizeConfig.r(100)),
          child: SizedBox(
            height: SizeConfig.h(12),
            child: Row(children: [
              for (var i = 0; i < parts.length; i++)
                if (parts[i].$2 > 0) Expanded(flex: (parts[i].$2 * 100 / total).round().clamp(1, 100), child: Container(color: colors[i])),
            ]),
          ),
        ),
        gapH(10),
        Row(children: [
          for (var i = 0; i < parts.length; i++)
            Expanded(
              child: Row(children: [
                Container(width: SizeConfig.r(8), height: SizeConfig.r(8), decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
                SizedBox(width: SizeConfig.w(5)),
                Text('${parts[i].$1} ${(parts[i].$2 * 100 / total).round()}%', style: tfStyle(11.5, color: Colors.white.withAlpha(190))),
              ]),
            ),
        ]),
      ]),
    );
  }
}


/// A player's photo, always cut to a circle (ClipOval), with an optional ring; initials when there is no photo.
class PlayerAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final Color? ring;
  final double ringWidth;
  final bool enlarge; // tap opens the photo full screen
  const PlayerAvatar({super.key, required this.url, required this.name, required this.size, this.ring, this.ringWidth = 2, this.enlarge = false});

  @override
  Widget build(BuildContext context) {
    final d = SizeConfig.r(size);
    final initials = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).take(2).map((x) => x[0].toUpperCase()).join();
    final fallback = Container(
      color: const Color(0xFF2A2A2A),
      alignment: Alignment.center,
      child: Text(initials, style: tfStyle(size * 0.32, weight: FontWeight.w900)),
    );
    final photo = ClipOval(
      child: SizedBox(
        width: d,
        height: d,
        child: url == null ? fallback : Image.network(url!, width: d, height: d, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
      ),
    );
    final avatar = ring == null
        ? photo
        : Container(padding: EdgeInsets.all(ringWidth), decoration: BoxDecoration(shape: BoxShape.circle, color: ring), child: photo);
    if (!enlarge || url == null) return avatar;
    return GestureDetector(onTap: () => _open(context), child: Hero(tag: 'player-photo-$url', child: avatar));
  }

  /// Full-screen photo: pinch to zoom, tap or swipe down to close.
  void _open(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (ctx, _, __) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(ctx).pop();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            Center(
              child: Hero(
                tag: 'player-photo-$url',
                child: InteractiveViewer(minScale: 1, maxScale: 4, child: Image.network(url!, fit: BoxFit.contain)),
              ),
            ),
            SafeArea(
              child: Row(children: [
                IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(16, weight: FontWeight.w800))),
              ]),
            ),
          ]),
        ),
      ),
    ));
  }
}
