import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../data/models/match.dart';
import '../../utils/helpers/size_config.dart';
import '../pages/rankings_page.dart' show PlayerAvatar;
import 'tournament_form_widgets.dart';

/// A finished cricket match's awards, as player cards: Player of the Match, best batter, best bowler and best
/// fielder, with photo, team and their numbers in this match. Tap a card for the player's stats.
class MatchAwards extends StatelessWidget {
  final MatchDetail m;
  const MatchAwards({super.key, required this.m});

  static const _gold = AwardPlayerCard.gold, _amber = AwardPlayerCard.amber, _sky = AwardPlayerCard.sky, _green = AwardPlayerCard.green;

  @override
  Widget build(BuildContext context) {
    final live = m.live ?? const {};
    final innings = (live['innings'] as List? ?? []).whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
    final bat = <Map<String, dynamic>>[], bowl = <Map<String, dynamic>>[];
    for (final inn in innings) {
      for (final b in (inn['batting'] as List? ?? []).whereType<Map>()) {
        bat.add(Map<String, dynamic>.from(b));
      }
      for (final b in (inn['bowling'] as List? ?? []).whereType<Map>()) {
        bowl.add(Map<String, dynamic>.from(b));
      }
    }
    int n(Map<String, dynamic> x, String k) => (x[k] as num?)?.toInt() ?? 0;
    double balls(String? overs) {
      final p = (overs ?? '0').split('.');
      return (int.tryParse(p[0]) ?? 0) * 6.0 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
    }

    final cards = <Widget>[];
    final potm = live['potm'] is Map ? Map<String, dynamic>.from(live['potm'] as Map) : null;
    if (potm != null) {
      cards.add(_card('PLAYER OF THE MATCH', Icons.workspace_premium_rounded, _gold, potm['id'], potm['reason']?.toString() ?? ''));
    }
    if (bat.isNotEmpty) {
      bat.sort((a, b) => n(b, 'runs') != n(a, 'runs') ? n(b, 'runs') - n(a, 'runs') : n(a, 'balls') - n(b, 'balls'));
      final b = bat.first;
      if (n(b, 'runs') > 0) {
        cards.add(_card('BEST BATTER', Icons.sports_cricket_rounded, _amber, b['id'],
            '${b['runs']}${b['out'] == true ? '' : '*'} (${b['balls']})${n(b, 'sixes') > 0 ? ' · ${b['sixes']}×6' : ''}${n(b, 'fours') > 0 ? ' · ${b['fours']}×4' : ''}'));
      }
    }
    if (bowl.isNotEmpty) {
      bowl.sort((a, b) {
        if (n(b, 'wickets') != n(a, 'wickets')) return n(b, 'wickets') - n(a, 'wickets');
        final ea = n(a, 'runs') / (balls(a['overs']?.toString()).clamp(1, 999)), eb = n(b, 'runs') / (balls(b['overs']?.toString()).clamp(1, 999));
        return ea.compareTo(eb);
      });
      final b = bowl.first;
      cards.add(_card('BEST BOWLER', Icons.track_changes_rounded, _sky, b['id'], '${b['wickets']}/${b['runs']} (${b['overs']} ov)'));
    }
    final field = [...m.fielding]..sort((a, b) {
        final t = (n(b, 'catches') + n(b, 'run_outs')) - (n(a, 'catches') + n(a, 'run_outs'));
        return t != 0 ? t : n(b, 'catches') - n(a, 'catches');
      });
    if (field.isNotEmpty) {
      final f = field.first;
      final parts = [
        if (n(f, 'catches') > 0) '${f['catches']} catch${n(f, 'catches') == 1 ? '' : 'es'}',
        if (n(f, 'run_outs') > 0) '${f['run_outs']} run out${n(f, 'run_outs') == 1 ? '' : 's'}',
      ];
      cards.add(_card('BEST FIELDER', Icons.back_hand_rounded, _green, f['member_id'], parts.join(' · ')));
    }
    return AwardStrip(heading: 'MATCH AWARDS', cards: cards);
  }

  Widget _card(String title, IconData icon, Color color, Object? memberId, String stat) {
    final id = memberId is num ? memberId.toInt() : int.tryParse('$memberId');
    final p = m.lineups.firstWhereOrNull((x) => x.memberId == id);
    return AwardPlayerCard(
      title: title,
      icon: icon,
      color: color,
      name: p?.name ?? 'Player',
      team: p == null ? '' : (m.home?.entryId == p.entryId ? m.home?.name : m.away?.name) ?? '',
      photoUrl: p?.photoUrl,
      stat: stat,
      userId: p?.userId,
      sport: m.sport,
    );
  }
}

/// One award as a player card: title, photo with a coloured ring, name, team and their numbers. Tap for the player page.
class AwardPlayerCard extends StatelessWidget {
  final String title, name, team, stat, sport;
  final IconData icon;
  final Color color;
  final String? photoUrl;
  final int? userId;
  final String kind;
  const AwardPlayerCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.color,
      required this.name,
      required this.team,
      required this.stat,
      required this.sport,
      this.photoUrl,
      this.userId,
      this.kind = 'TOURNAMENT'});

  static const gold = Color(0xFFFFC94D), amber = Color(0xFFFFB74D), sky = Color(0xFF4FC3F7), green = Color(0xFF66BB6A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('award-$title'),
      onTap: userId == null ? null : () => Get.toNamed(AppRoutes.player, arguments: {'user_id': userId, 'sport': sport, 'kind': kind}),
      child: Container(
        width: SizeConfig.w(150),
        padding: EdgeInsets.all(SizeConfig.r(12)),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withAlpha(50), const Color(0xFF1A1A1A)]),
          borderRadius: BorderRadius.circular(SizeConfig.r(18)),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Column(children: [
          Row(children: [
            Icon(icon, size: SizeConfig.r(14), color: color),
            SizedBox(width: SizeConfig.w(4)),
            Expanded(
              child: Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(9.5, weight: FontWeight.w900, color: color).copyWith(letterSpacing: 0.5)),
            ),
          ]),
          gapH(10),
          PlayerAvatar(url: photoUrl, name: name, size: 64, ring: color),
          gapH(8),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w800)),
          Text(team, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(11, color: Colors.white.withAlpha(140))),
          const Spacer(),
          Text(stat, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: tfStyle(12.5, weight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// A row of award cards with a heading ("MATCH AWARDS", "SERIES AWARDS").
class AwardStrip extends StatelessWidget {
  final String heading;
  final List<Widget> cards;
  const AwardStrip({super.key, required this.heading, required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(heading, style: tfStyle(12, weight: FontWeight.w900, color: Colors.white.withAlpha(160)).copyWith(letterSpacing: 1)),
      gapH(10),
      SizedBox(
        height: SizeConfig.h(206),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => SizedBox(width: SizeConfig.w(10)),
          itemBuilder: (_, i) => cards[i],
        ),
      ),
    ]);
  }
}
