import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/sports.dart';
import '../../data/models/app_user.dart';
import '../../data/models/home_models.dart';
import '../../data/services/session_service.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_nav_controller.dart';
import '../widgets/home_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openBanner(HomeBanner b) {
    if (b.linkType == 'TOURNAMENT') {
      final t = Get.find<HomeController>().tournamentBySlug(b.linkValue);
      if (t != null) Get.toNamed(AppRoutes.tournamentDetail, arguments: t);
    }
  }

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
                    BannerCarousel(banners: c.banners.toList(), onTap: _openBanner),
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
                  const EmptyCard(
                    icon: Icons.sensors_rounded,
                    title: 'No live matches right now',
                    message: 'When a match from your teams or tournaments is being scored, the live score shows up here.',
                  ),

                  // Next match
                  const SectionHeader(title: 'My next match'),
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

                  // My teams
                  SectionHeader(title: 'My teams', actionLabel: 'See all', onAction: () => nav.go(MainNavController.myTeams)),
                  EmptyCard(
                    icon: Icons.shield_rounded,
                    title: "You're not in a team yet",
                    message: 'Ask your captain for the team link, or create your own team and invite players.',
                    actions: [
                      SmallButton(label: 'Join a team', filled: false, onTap: () => showComingSoon('Joining teams')),
                      SmallButton(label: 'Create team', onTap: () => showComingSoon('Creating teams')),
                    ],
                  ),

                  // Stats snapshot
                  const SectionHeader(title: 'My stats'),
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withAlpha(30), border: Border.all(color: AppColors.primary, width: 1.5)),
              clipBehavior: Clip.antiAlias,
              child: user?.photoUrl != null
                  ? Image.network(user!.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials())
                  : _initials(),
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
      (Icons.emoji_events_rounded, 'Create tournament', () => showComingSoon('Creating tournaments')),
      (Icons.shield_rounded, 'Create team', () => showComingSoon('Creating teams')),
      (Icons.qr_code_rounded, 'Join with code', () => showComingSoon('Joining with a code')),
      (Icons.sports_score_rounded, 'Score a match', () => showComingSoon('Live scoring')),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
      child: GridView.count(
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
    );
  }
}

class _StatsSnapshot extends StatelessWidget {
  final AppUser? user;
  const _StatsSnapshot({required this.user});

  static const _metrics = {
    'CRICKET': [('Runs', '0'), ('Wickets', '0')],
    'FOOTBALL': [('Goals', '0'), ('Assists', '0')],
    'BADMINTON': [('Wins', '0'), ('Win %', '—')],
    'PICKLEBALL': [('Wins', '0'), ('Win %', '—')],
  };

  @override
  Widget build(BuildContext context) {
    final sports = user?.sports ?? const [];
    return Column(
      children: [
        for (final s in sports)
          if (Sports.byCode(s.sport) case final sport?)
            Container(
              margin: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), SizeConfig.h(10)),
              padding: EdgeInsets.all(SizeConfig.r(14)),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(16))),
              child: Row(
                children: [
                  Image.asset(sport.asset, width: SizeConfig.r(34), height: SizeConfig.r(34)),
                  SizedBox(width: SizeConfig.w(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sport.label, style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(15), color: Colors.white)),
                        Text(Sports.labelOf(sport.roles, s.role),
                            style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(12), color: Colors.white.withAlpha(130))),
                      ],
                    ),
                  ),
                  _Metric(label: 'Matches', value: '0'),
                  for (final (label, value) in _metrics[sport.code] ?? const <(String, String)>[]) _Metric(label: label, value: value),
                ],
              ),
            ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
          child: Text(
            'Your stats update automatically after every scored match.',
            style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(12), color: Colors.white.withAlpha(110)),
          ),
        ),
      ],
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
