import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
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
                  ChoiceChips(options: [for (final s in c.sports) (s, Sports.byCode(s)?.label ?? s)], selected: c.sport.value, onSelected: c.setSport),
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
                    Padding(padding: EdgeInsets.only(top: SizeConfig.h(40)), child: const Center(child: CircularProgressIndicator(color: AppColors.primary)))
                  else if (c.error.value != null && d == null)
                    _note(c.error.value!)
                  else
                    _MyStats(row: row, cricket: cricket, quick: c.kind.value == 'QUICK'),
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
                  Padding(padding: EdgeInsets.only(top: SizeConfig.h(40)), child: const Center(child: CircularProgressIndicator(color: AppColors.primary)))
                else if (c.error.value != null && d == null)
                  _note(c.error.value!)
                else if (rows.isEmpty)
                  _note(c.city.value.isNotEmpty
                      ? 'No ranked players in this area yet. Players appear here once they add their pincode and play ${d?['min'] ?? 3} matches.'
                      : 'Nobody is ranked yet. Players need ${d?['min'] ?? 3} completed matches to be ranked.')
                else ...[
                  for (final r in rows) _RankRow(r: r, list: c.list.value, cricket: cricket, mine: r['user_id'] == myId),
                  if (row != null && !rows.any((r) => r['user_id'] == myId) && ranks[c.list.value] != null) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: SizeConfig.h(4)),
                      child: Center(child: Text('· · ·', style: tfStyle(14, color: Colors.white.withAlpha(90)))),
                    ),
                    _RankRow(r: {...row, 'rank': ranks[c.list.value]}, list: c.list.value, cricket: cricket, mine: true),
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
              ChoiceChips(options: [('', 'Everywhere'), for (final x in cities) (x, x)], selected: c.city.value, onSelected: (v) => c.setFilters(city: v)),
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
                options: const [('ALL', 'All'), ('MALE', 'Men'), ('FEMALE', 'Women')], selected: c.gender.value, onSelected: (v) => c.setFilters(gender: v)),
            if (c.sport.value == 'CRICKET') ...[
              gapH(14),
              const FormLabel('Ball'),
              ChoiceChips(
                  options: const [('ALL', 'All'), ('TENNIS', 'Tennis'), ('LEATHER', 'Leather')], selected: c.ball.value, onSelected: (v) => c.setFilters(ball: v)),
            ],
            if (c.filterCount > 0) ...[
              gapH(12),
              Center(child: TextButton(onPressed: c.clearFilters, child: Text('Clear filters', style: tfStyle(13.5, weight: FontWeight.w700, color: AppColors.primary)))),
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

/// The player's own numbers for the selected sport and kind. Personal only: no ranks here.
class _MyStats extends StatelessWidget {
  final Map<String, dynamic>? row;
  final bool cricket, quick;
  const _MyStats({required this.row, required this.cricket, required this.quick});

  @override
  Widget build(BuildContext context) {
    final r = row;
    if (r == null) {
      return FormCard(
        padding: EdgeInsets.all(SizeConfig.r(16)),
        child: Text('No completed ${quick ? 'quick matches' : 'tournament matches'} yet. Your stats appear here after your first scored match.',
            style: tfStyle(13, color: Colors.white.withAlpha(170), height: 1.4)),
      );
    }
    Widget metric(String label, Object? value) => Expanded(
          child: Column(children: [
            Text('${value ?? '—'}', style: tfStyle(20, weight: FontWeight.w900)),
            gapH(2),
            Text(label, style: tfStyle(11, color: Colors.white.withAlpha(140))),
          ]),
        );
    Widget card(String title, List<Widget> metrics) => Container(
          margin: EdgeInsets.only(bottom: SizeConfig.h(10)),
          padding: EdgeInsets.all(SizeConfig.r(14)),
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(14))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: tfStyle(11, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.6)),
            gapH(10),
            Row(children: metrics),
          ]),
        );
    if (!cricket) {
      return Column(children: [
        card('OVERALL', [metric('Matches', r['matches']), metric('MVP points', r['points']), metric('POTM', r['potm'])]),
        card('ATTACK', [metric('Goals', r['goals']), metric('Assists', r['assists'])]),
        card('DEFENCE & DISCIPLINE', [metric('Clean sheets', r['clean_sheets']), metric('Yellow', r['yellow']), metric('Red', r['red'])]),
      ]);
    }
    return Column(children: [
      card('OVERALL', [metric('Matches', r['matches']), metric('Points', r['points']), metric('POTM', r['potm'])]),
      card('BATTING', [
        metric('Runs', r['runs']),
        metric('Highest', r['highest']),
        metric('Average', r['average']),
        metric('Strike rate', r['strike_rate']),
      ]),
      card('', [metric('Innings', r['innings']), metric('Balls', r['balls']), metric('4s', r['fours']), metric('6s', r['sixes'])]),
      card('BOWLING', [metric('Wickets', r['wickets']), metric('Overs', r['overs']), metric('Economy', r['economy']), metric('Best', r['best'])]),
      card('FIELDING', [metric('Catches', r['catches']), metric('Run outs', r['run_outs'])]),
    ]);
  }
}

class _RankRow extends StatelessWidget {
  final Map<String, dynamic> r;
  final String list;
  final bool cricket, mine;
  const _RankRow({required this.r, required this.list, required this.cricket, required this.mine});

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

  Widget _initials() => Center(
        child: Text(
          '${r['name'] ?? ''}'.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join(),
          style: tfStyle(12.5, weight: FontWeight.w800),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final (value, detail) = _value;
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    final medal = switch (rank) { 1 => const Color(0xFFFFC94D), 2 => const Color(0xFFCFD6DE), 3 => const Color(0xFFD9935B), _ => null };
    return Container(
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
        Container(
          width: SizeConfig.r(36),
          height: SizeConfig.r(36),
          margin: EdgeInsets.only(right: SizeConfig.w(10)),
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2A2A2A), border: Border.all(color: medal ?? Colors.white.withAlpha(30))),
          clipBehavior: Clip.antiAlias,
          child: r['photo_url'] != null
              ? Image.network(r['photo_url'] as String, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials())
              : _initials(),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mine ? '${r['name']} (you)' : '${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w800)),
            Text([if (r['area'] != null) r['area'], detail].join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(11.5, color: Colors.white.withAlpha(140))),
          ]),
        ),
        Text(value, style: tfStyle(18, weight: FontWeight.w900, color: AppColors.primary)),
      ]),
    );
  }
}
