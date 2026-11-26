import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/sports.dart';
import '../../data/models/app_user.dart';
import '../../data/services/session_service.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_nav_controller.dart';
import '../widgets/home_widgets.dart';
import '../../data/models/team.dart';
import '../widgets/create_tournament_steps.dart' show fmtDateTime;
import 'my_teams_page.dart' show showJoinTeamWithCode, TeamListCard;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeController>();
    final session = Get.find<SessionService>();
    final nav = Get.find<MainNavController>();

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: c.load,
          child: Obx(() {
            final user = session.user.value;
            return ListView(
              padding: EdgeInsets.only(bottom: SizeConfig.h(120)),
              children: [
                _Header(user: user, unread: c.unreadNotifications.value, onAvatar: () => nav.go(MainNavController.profile)),
                if (c.isLoading.value && c.banners.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: SizeConfig.h(80)),
                    child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else ...[
                  if (c.errorMessage.value.isNotEmpty) _ErrorBanner(message: c.errorMessage.value, onRetry: c.load),
                  if (c.banners.isNotEmpty) ...[
                    SizedBox(height: SizeConfig.h(8)),
                    BannerCarousel(banners: c.banners.toList(), onTap: c.openBanner, onSeen: c.bannerSeen),
                  ],

                  // Live now
                  SectionHeader(
                    title: 'Live now',
                    leading: Container(
                      width: SizeConfig.r(8),
                      height: SizeConfig.r(8),
                      decoration: BoxDecoration(color: c.liveMatches.isEmpty ? Colors.white.withAlpha(60) : AppColors.negative, shape: BoxShape.circle),
                    ),
                  ),
                  if (c.liveMatches.isEmpty)
                    const EmptyCard(
                      icon: Icons.sensors_rounded,
                      title: 'No live matches right now',
                      message: 'When a match from your teams or tournaments is being scored, the live score shows up here.',
                    )
                  else
                    for (final m in c.liveMatches) _HomeMatchCard(m: m),

                  // Next match
                  const SectionHeader(title: 'My next match'),
                  if (c.nextMatch.value != null)
                    _HomeMatchCard(m: c.nextMatch.value!)
                  else
                    EmptyCard(
                      icon: Icons.event_rounded,
                      title: 'No upcoming matches',
                      message: 'Join a team or register for a tournament and your fixtures will appear here.',
                      actions: [SmallButton(label: 'Find tournaments', onTap: () => nav.go(MainNavController.tournaments))],
                    ),

                  // Quick actions
                  const SectionHeader(title: 'Quick actions'),
                  const _QuickActions(),

                  // Upcoming tournaments
                  SectionHeader(
                    title: 'Upcoming in Mumbai',
                    actionLabel: c.tournaments.isEmpty ? null : 'See all',
                    onAction: () => nav.go(MainNavController.tournaments),
                  ),
                  if (c.tournaments.isEmpty)
                    const EmptyCard(icon: Icons.emoji_events_rounded, title: 'No tournaments yet', message: 'New tournaments in your city will be listed here.')
                  else
                    SizedBox(
                      height: SizeConfig.h(310),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
                        itemCount: c.tournaments.length,
                        separatorBuilder: (_, __) => SizedBox(width: SizeConfig.w(12)),
                        itemBuilder: (_, i) => TournamentCard(t: c.tournaments[i], compact: true),
                      ),
                    ),

                  // MyPaltan leaderboard: top players with photos and their numbers.
                  if (c.leaders.isNotEmpty) ...[
                    SectionHeader(
                      title: c.leadersCity.value.isNotEmpty ? 'Top players in ${c.leadersCity.value}' : 'MyPaltan Leaderboard',
                      actionLabel: 'See all',
                      onAction: () => Get.toNamed(AppRoutes.rankings, arguments: {'tab': 'RANKS', 'sport': c.leadersSport.value}),
                    ),
                    SizedBox(
                      height: SizeConfig.h(214),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
                        itemCount: c.leaders.length,
                        separatorBuilder: (_, __) => SizedBox(width: SizeConfig.w(10)),
                        itemBuilder: (_, i) => _LeaderCard(r: c.leaders[i], cricket: c.leadersSport.value == 'CRICKET', sport: c.leadersSport.value),
                      ),
                    ),
                  ],

                  // My teams
                  SectionHeader(title: 'My teams', actionLabel: 'See all', onAction: () => nav.go(MainNavController.myTeams)),
                  if (c.myTeams.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
                      child: Column(
                        children: [
                          for (final t in c.myTeams.take(3).map(MyTeam.fromJson)) ...[
                            TeamListCard(t: t, onTap: () => Get.toNamed(AppRoutes.team, arguments: {'code': t.code})),
                            SizedBox(height: SizeConfig.h(10)),
                          ],
                        ],
                      ),
                    )
                  else
                    EmptyCard(
                      icon: Icons.shield_rounded,
                      title: "You're not in a team yet",
                      message: 'Ask your captain for the team link, or create your own team and invite players.',
                      actions: [
                        SmallButton(label: 'Join a team', filled: false, onTap: showJoinTeamWithCode),
                        SmallButton(label: 'Create team', onTap: () => Get.toNamed(AppRoutes.teamForm)),
                      ],
                    ),

                  // Stats snapshot
                  SectionHeader(
                    title: 'My stats',
                    actionLabel: 'Rankings',
                    onAction: () => Get.toNamed(AppRoutes.rankings, arguments: {'tab': 'RANKS'}),
                  ),
                  _StatsSnapshot(user: user),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppUser? user;
  final int unread;
  final VoidCallback onAvatar;
  const _Header({required this.user, required this.unread, required this.onAvatar});

  @override
  Widget build(BuildContext context) {
    final size = SizeConfig.r(44);
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${user?.firstName.isNotEmpty == true ? user!.firstName : 'Player'} 👋',
                  style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(22), color: Colors.white),
                ),
                Text(
                  'Ready for your next match?',
                  style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(13), color: Colors.white.withAlpha(140)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.notifications),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(14))),
                  child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: SizeConfig.r(22)),
                ),
                if (unread > 0)
                  Positioned(
                    right: -SizeConfig.r(3),
                    top: -SizeConfig.r(3),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(5), vertical: SizeConfig.h(1)),
                      constraints: BoxConstraints(minWidth: SizeConfig.r(18)),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(SizeConfig.r(9))),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(10), color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: SizeConfig.w(10)),
          GestureDetector(
            onTap: onAvatar,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withAlpha(30)),
              // Ring drawn over the photo so it stays an even circle (under the photo it only peeked out at the edges).
              foregroundDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 1.5)),
              clipBehavior: Clip.antiAlias,
              child: user?.photoUrl != null ? Image.network(user!.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials()) : _initials(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() => Center(
        child: Text(
          user?.initials ?? '?',
          style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(15), color: Colors.white),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.emoji_events_rounded, 'Create tournament', () => Get.toNamed(AppRoutes.createTournament)),
      (Icons.shield_rounded, 'Create team', () => Get.toNamed(AppRoutes.teamForm)),
      (Icons.qr_code_rounded, 'Join with code', showJoinTeamWithCode),
      (Icons.sports_score_rounded, 'Score a match', startScoring),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
      child: Column(children: [
        // Quick match: the fastest way to play and score with friends.
        GestureDetector(
          key: const ValueKey('home-quick-match'),
          onTap: () => Get.toNamed(AppRoutes.createQuickMatch),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(14)),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(SizeConfig.r(16)),
              border: Border.all(color: AppColors.primary.withAlpha(90)),
            ),
            child: Row(children: [
              Container(
                width: SizeConfig.r(36),
                height: SizeConfig.r(36),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(SizeConfig.r(10))),
                child: Icon(Icons.bolt_rounded, color: Colors.white, size: SizeConfig.r(20)),
              ),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Quick match', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(15), color: Colors.white)),
                  Text('Play with friends: share a link, score it live',
                      style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(12), color: Colors.white.withAlpha(160))),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(140)),
            ]),
          ),
        ),
        SizedBox(height: SizeConfig.h(10)),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          // Without this, the grid inherits the safe-area/bottom-bar padding and leaves a gap below it.
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: SizeConfig.h(10),
          crossAxisSpacing: SizeConfig.w(10),
          childAspectRatio: 2.3,
          children: actions.map((a) {
            final (icon, label, onTap) = a;
            return GestureDetector(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12)),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(SizeConfig.r(16)),
                  border: Border.all(color: Colors.white.withAlpha(12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: SizeConfig.r(36),
                      height: SizeConfig.r(36),
                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(10))),
                      child: Icon(icon, color: AppColors.primary, size: SizeConfig.r(19)),
                    ),
                    SizedBox(width: SizeConfig.w(10)),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(13), color: Colors.white, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _StatsSnapshot extends StatelessWidget {
  final AppUser? user;
  const _StatsSnapshot({required this.user});

  @override
  Widget build(BuildContext context) {
    final sports = user?.sports ?? const [];
    final home = Get.find<HomeController>();
    return Obx(() => Column(
          children: [
            for (final s in sports)
              if (Sports.byCode(s.sport) case final sport?)
                GestureDetector(
                  key: ValueKey('my-stats-${s.sport}'),
                  onTap: s.sport == 'CRICKET' || s.sport == 'FOOTBALL' ? () => Get.toNamed(AppRoutes.rankings, arguments: {'sport': s.sport}) : null,
                  child: Container(
                    margin: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), SizeConfig.h(10)),
                    padding: EdgeInsets.all(SizeConfig.r(14)),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(16))),
                    child: _sportStats(sport, s, home.myStats['${s.sport}:TOURNAMENT'], home.myStats['${s.sport}:QUICK']),
                  ),
                ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
              child: Text(
                'Tournament and quick match stats are kept separately. Tap a sport for your full stats.',
                style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(12), color: Colors.white.withAlpha(110)),
              ),
            ),
          ],
        ));
  }

  Widget _sportStats(SportOption sport, SportRole s, Map<String, dynamic>? tour, Map<String, dynamic>? quick) {
    Map<String, dynamic>? rowOf(Map<String, dynamic>? x) => x?['row'] is Map ? Map<String, dynamic>.from(x!['row'] as Map) : null;
    final t = rowOf(tour), q = rowOf(quick);
    final cricket = s.sport == 'CRICKET';
    final style = TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(12), color: Colors.white.withAlpha(130));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        children: [
          Image.asset(sport.asset, width: SizeConfig.r(34), height: SizeConfig.r(34)),
          SizedBox(width: SizeConfig.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sport.label, style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(15), color: Colors.white)),
                Text(Sports.labelOf(sport.roles, s.role), style: style),
              ],
            ),
          ),
          _Metric(label: 'Matches', value: '${t?['matches'] ?? 0}'),
          if (cricket) ...[
            _Metric(label: 'Runs', value: '${t?['runs'] ?? 0}'),
            _Metric(label: 'Wickets', value: '${t?['wickets'] ?? 0}'),
          ] else if (s.sport == 'FOOTBALL') ...[
            _Metric(label: 'Goals', value: '${t?['goals'] ?? 0}'),
            _Metric(label: 'Assists', value: '${t?['assists'] ?? 0}'),
          ],
        ],
      ),
      if (cricket || s.sport == 'FOOTBALL') ...[
        SizedBox(height: SizeConfig.h(8)),
        Text(
          q == null
              ? 'Tournaments above · no quick matches yet'
              : 'Tournaments above · Quick matches: ${q['matches']} played, '
                  '${cricket ? '${q['runs']} runs, ${q['wickets']} wkts' : '${q['goals']} goals, ${q['assists']} assists'}',
          style: style,
        ),
      ],
    ]);
  }
}

/// One player on the Home leaderboard: rank, photo, name, area and their numbers. Tap for the full rankings.
class _LeaderCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final bool cricket;
  final String sport;
  const _LeaderCard({required this.r, required this.cricket, required this.sport});

  @override
  Widget build(BuildContext context) {
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    final medal = switch (rank) { 1 => const Color(0xFFFFC94D), 2 => const Color(0xFFCFD6DE), 3 => const Color(0xFFD9935B), _ => AppColors.primary };
    final name = '${r['name'] ?? 'Player'}';
    final initials = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    final photo = r['photo_url'] as String?;
    final style = TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(11.5), color: Colors.white.withAlpha(140));
    return GestureDetector(
      key: ValueKey('leader-${r['user_id']}'),
      onTap: () => Get.toNamed(AppRoutes.rankings, arguments: {'tab': 'RANKS', 'sport': sport}),
      child: Container(
        width: SizeConfig.w(150),
        padding: EdgeInsets.all(SizeConfig.r(12)),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [medal.withAlpha(45), const Color(0xFF1A1A1A)]),
          borderRadius: BorderRadius.circular(SizeConfig.r(18)),
          border: Border.all(color: medal.withAlpha(90)),
        ),
        child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(8), vertical: SizeConfig.h(2)),
              decoration: BoxDecoration(color: medal, borderRadius: BorderRadius.circular(SizeConfig.r(100))),
              child: Text('#$rank', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w900, fontSize: SizeConfig.sp(12), color: Colors.black)),
            ),
          ),
          SizedBox(height: SizeConfig.h(6)),
          Container(
            width: SizeConfig.r(64),
            height: SizeConfig.r(64),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: medal, width: 2), color: const Color(0xFF2A2A2A)),
            clipBehavior: Clip.antiAlias,
            child: photo != null
                ? Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(initials, style: style)))
                : Center(
                    child: Text(initials,
                        style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(20), color: Colors.white))),
          ),
          SizedBox(height: SizeConfig.h(8)),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(14), color: Colors.white)),
          Text(r['area'] as String? ?? '${r['matches']} matches', maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          const Spacer(),
          Text('${r['points']}', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w900, fontSize: SizeConfig.sp(22), color: medal)),
          Text(
            cricket ? '${r['runs']} runs · ${r['wickets']} wkts' : '${r['goals']} goals · ${r['assists']} ast',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: SizeConfig.w(12)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(17), color: Colors.white)),
          Text(label, style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(10), color: Colors.white.withAlpha(120))),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(8), SizeConfig.w(20), 0),
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(10)),
      decoration: BoxDecoration(color: AppColors.negative.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
      child: Row(
        children: [
          Expanded(child: Text(message, style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(13), color: Colors.white))),
          GestureDetector(
            onTap: onRetry,
            child: Text('Retry', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(13), color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

/// A match on the home screen (next match or live): tournament, teams, time or live score. Opens the match.
class _HomeMatchCard extends StatelessWidget {
  final Map<String, dynamic> m;
  const _HomeMatchCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final live = m['status'] == 'LIVE';
    final when = fmtDateTime(DateTime.tryParse('${m['scheduled_at'] ?? ''}'.replaceFirst(' ', 'T')));
    final pitch = m['pitch'] != null ? ' · Pitch ${m['pitch']}' : '';
    Widget side(String name, String? logo, Object? score) => Expanded(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(SizeConfig.r(10)),
                child: SizedBox(
                  width: SizeConfig.r(44),
                  height: SizeConfig.r(44),
                  child: logo != null
                      ? Image.network(logo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A)))
                      : const ColoredBox(color: Color(0xFF2A2A2A)),
                ),
              ),
              SizedBox(height: SizeConfig.h(6)),
              Text(name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(13), color: Colors.white)),
              if (live && score != null)
                Text('$score', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w900, fontSize: SizeConfig.sp(22), color: Colors.white)),
            ],
          ),
        );
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.match, arguments: {'id': m['id']}),
      child: Container(
        margin: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), SizeConfig.h(10)),
        padding: EdgeInsets.all(SizeConfig.r(14)),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(SizeConfig.r(18)),
          border: Border.all(color: live ? AppColors.negative.withAlpha(120) : Colors.white.withAlpha(12)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (live) ...[
                  Text('LIVE', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(11), color: AppColors.negative)),
                  SizedBox(width: SizeConfig.w(8)),
                ],
                Expanded(
                  child: Text('${m['tournament'] ?? ''}${m['division'] != null ? ' · ${m['division']}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(12), color: Colors.white.withAlpha(150))),
                ),
              ],
            ),
            SizedBox(height: SizeConfig.h(12)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                side('${m['home'] ?? 'TBC'}', m['home_logo'] as String?, m['home_score']),
                Padding(
                  padding: EdgeInsets.only(top: SizeConfig.h(12)),
                  child: Text('vs',
                      style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(13), color: Colors.white.withAlpha(120))),
                ),
                side('${m['away'] ?? 'TBC'}', m['away_logo'] as String?, m['away_score']),
              ],
            ),
            if (!live && when.isNotEmpty) ...[
              SizedBox(height: SizeConfig.h(10)),
              Text('$when$pitch', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w600, fontSize: SizeConfig.sp(12.5), color: AppColors.primary)),
            ],
          ],
        ),
      ),
    );
  }
}
