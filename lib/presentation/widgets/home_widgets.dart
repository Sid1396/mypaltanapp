import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/sports.dart';
import '../../data/models/home_models.dart';
import '../../data/models/tournament.dart';
import '../../utils/helpers/size_config.dart';

const _card = Color(0xFF1A1A1A);

TextStyle _gilroy(double size, {FontWeight weight = FontWeight.w400, Color color = Colors.white, double? height}) =>
    TextStyle(fontFamily: 'Gilroy', fontWeight: weight, fontSize: SizeConfig.sp(size), color: color, height: height);

/// Title row for a Home section with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.leading, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(28), SizeConfig.w(20), SizeConfig.h(12)),
      child: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: SizeConfig.w(8))],
          Text(title, style: _gilroy(18, weight: FontWeight.w800)),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: _gilroy(13, weight: FontWeight.w700, color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

/// Muted card used where a section has nothing to show yet.
class EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  const EmptyCard({super.key, required this.icon, required this.title, required this.message, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
      padding: EdgeInsets.all(SizeConfig.r(18)),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(SizeConfig.r(18)),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: SizeConfig.r(40),
                height: SizeConfig.r(40),
                decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
                child: Icon(icon, color: Colors.white.withAlpha(140), size: SizeConfig.r(20)),
              ),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(child: Text(title, style: _gilroy(15, weight: FontWeight.w700))),
            ],
          ),
          SizedBox(height: SizeConfig.h(10)),
          Text(message, style: _gilroy(13, color: Colors.white.withAlpha(140), height: 1.45)),
          if (actions.isNotEmpty) ...[
            SizedBox(height: SizeConfig.h(14)),
            Row(children: [for (var i = 0; i < actions.length; i++) ...[if (i > 0) SizedBox(width: SizeConfig.w(10)), Expanded(child: actions[i])]]),
          ],
        ],
      ),
    );
  }
}

/// Compact pill button used inside cards.
class SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const SmallButton({super.key, required this.label, required this.onTap, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: SizeConfig.h(11)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(SizeConfig.r(12)),
          border: Border.all(color: filled ? AppColors.primary : Colors.white.withAlpha(40)),
        ),
        child: Text(label, style: _gilroy(13, weight: FontWeight.w700)),
      ),
    );
  }
}

/// Auto-rotating banner carousel driven by `home_banners`.
class BannerCarousel extends StatefulWidget {
  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner> onTap;
  const BannerCarousel({super.key, required this.banners, required this.onTap});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.banners.length < 2 || !_controller.hasClients) return;
      _controller.animateToPage((_page + 1) % widget.banners.length,
          duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    return Column(
      children: [
        SizedBox(
          height: SizeConfig.h(160),
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(5)),
              child: _BannerCard(banner: banners[i], onTap: () => widget.onTap(banners[i])),
            ),
          ),
        ),
        if (banners.length > 1) ...[
          SizedBox(height: SizeConfig.h(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: SizeConfig.w(3)),
                width: i == _page ? SizeConfig.w(18) : SizeConfig.w(6),
                height: SizeConfig.h(6),
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(SizeConfig.r(3)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final HomeBanner banner;
  final VoidCallback onTap;
  const _BannerCard({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = banner.isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SizeConfig.r(20)),
          gradient: dark
              ? const LinearGradient(colors: [Color(0xFF1F1F1F), Color(0xFF151515)])
              : const LinearGradient(colors: [Color(0xFFF55018), Color(0xFFB8360A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: dark ? Border.all(color: Colors.white.withAlpha(15)) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(SizeConfig.r(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner.badge != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(4)),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.primary.withAlpha(35) : Colors.black.withAlpha(45),
                          borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                        ),
                        child: Text(banner.badge!.toUpperCase(),
                            style: _gilroy(10, weight: FontWeight.w700, color: dark ? AppColors.primary : Colors.white)),
                      ),
                    const Spacer(),
                    Text(banner.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _gilroy(19, weight: FontWeight.w800, height: 1.15)),
                    if (banner.subtitle != null) ...[
                      SizedBox(height: SizeConfig.h(4)),
                      Text(banner.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: _gilroy(12, color: Colors.white.withAlpha(dark ? 150 : 220), height: 1.35)),
                    ],
                  ],
                ),
              ),
            ),
            if (banner.imageUrl != null)
              Padding(
                padding: EdgeInsets.only(right: SizeConfig.w(14)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                  child: Image.network(
                    banner.imageUrl!,
                    width: SizeConfig.r(104),
                    height: SizeConfig.r(104),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _LogoFallback(size: SizeConfig.r(104), sport: 'CRICKET'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  final double size;
  final String sport;
  const _LogoFallback({required this.size, required this.sport});

  @override
  Widget build(BuildContext context) {
    final asset = Sports.byCode(sport)?.asset;
    return Container(
      width: size,
      height: size,
      color: Colors.white.withAlpha(10),
      alignment: Alignment.center,
      child: asset != null ? Image.asset(asset, width: size * 0.45) : const SizedBox.shrink(),
    );
  }
}

/// Upcoming tournament card; `compact` is used in the Home horizontal list.
class TournamentCard extends StatelessWidget {
  final FeaturedTournament t;
  final bool compact;
  const TournamentCard({super.key, required this.t, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final sport = Sports.byCode(t.sport);
    final imageSize = compact ? SizeConfig.w(220) : double.infinity;
    return GestureDetector(
      onTap: () => t.code != null
          ? Get.toNamed(AppRoutes.tournament, arguments: {'code': t.code})
          : Get.toNamed(AppRoutes.tournamentDetail, arguments: t),
      child: Container(
        width: compact ? SizeConfig.w(220) : null,
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(SizeConfig.r(18))),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: compact ? 1.25 : 1.6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  t.logoUrl != null
                      ? Image.network(t.logoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _LogoFallback(size: imageSize, sport: t.sport))
                      : _LogoFallback(size: imageSize, sport: t.sport),
                  Positioned(
                    top: SizeConfig.r(10),
                    left: SizeConfig.r(10),
                    child: t.startDate != null
                        ? Container(
                            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(6)),
                            decoration: BoxDecoration(color: Colors.black.withAlpha(200), borderRadius: BorderRadius.circular(SizeConfig.r(8))),
                            child: Column(
                              children: [
                                Text(t.dayLabel!, style: _gilroy(18, weight: FontWeight.w800, height: 1)),
                                Text(t.monthLabel!.toUpperCase(), style: _gilroy(10, weight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                          )
                        : Container(
                            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(6)),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(SizeConfig.r(8))),
                            child: Text('COMING SOON', style: _gilroy(10, weight: FontWeight.w700)),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(SizeConfig.r(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (sport != null) ...[Image.asset(sport.asset, width: SizeConfig.r(16)), SizedBox(width: SizeConfig.w(6))],
                      Text((sport?.label ?? t.sport).toUpperCase(), style: _gilroy(11, weight: FontWeight.w700, color: Colors.white.withAlpha(140))),
                    ],
                  ),
                  SizedBox(height: SizeConfig.h(6)),
                  Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _gilroy(compact ? 15 : 17, weight: FontWeight.w800)),
                  SizedBox(height: SizeConfig.h(2)),
                  Text(t.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: _gilroy(12, color: Colors.white.withAlpha(140))),
                  SizedBox(height: SizeConfig.h(10)),
                  Text(t.statusLabel, style: _gilroy(11, weight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for features that are planned but not built yet.
void showComingSoon(String feature, {String? detail}) {
  Get.bottomSheet(
    Builder(
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(SizeConfig.w(24), SizeConfig.h(12), SizeConfig.w(24), SizeConfig.h(20) + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(SizeConfig.r(24))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: SizeConfig.w(40), height: 4, decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(2))),
            SizedBox(height: SizeConfig.h(20)),
            Container(
              width: SizeConfig.r(56),
              height: SizeConfig.r(56),
              decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), shape: BoxShape.circle),
              child: Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: SizeConfig.r(26)),
            ),
            SizedBox(height: SizeConfig.h(14)),
            Text('$feature is coming soon', textAlign: TextAlign.center, style: _gilroy(19, weight: FontWeight.w800)),
            SizedBox(height: SizeConfig.h(8)),
            Text(
              detail ?? "We're building this right now. You'll get a notification as soon as it's ready.",
              textAlign: TextAlign.center,
              style: _gilroy(14, color: Colors.white.withAlpha(150), height: 1.45),
            ),
            SizedBox(height: SizeConfig.h(20)),
            SizedBox(width: double.infinity, child: SmallButton(label: 'Got it', onTap: Get.back)),
          ],
        ),
      ),
    ),
  );
}

/// Sheet opened by the centre "Create" button.
void showCreateSheet() {
  Widget option(IconData icon, String title, String subtitle, VoidCallback onTap, {Key? key}) => GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(14)),
          decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(SizeConfig.r(14))),
          child: Row(
            children: [
              Container(
                width: SizeConfig.r(44),
                height: SizeConfig.r(44),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
                child: Icon(icon, color: AppColors.primary, size: SizeConfig.r(22)),
              ),
              SizedBox(width: SizeConfig.w(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _gilroy(15, weight: FontWeight.w700)),
                    Text(subtitle, style: _gilroy(12, color: Colors.white.withAlpha(130))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(90)),
            ],
          ),
        ),
      );

  Get.bottomSheet(
    Builder(
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(16) + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(SizeConfig.r(24))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: SizeConfig.w(40), height: 4, decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(2)))),
            SizedBox(height: SizeConfig.h(16)),
            Text('Create', style: _gilroy(20, weight: FontWeight.w800)),
            SizedBox(height: SizeConfig.h(14)),
            option(Icons.emoji_events_rounded, 'Create a tournament', 'League, knockout or groups', key: const ValueKey('create-tournament'), () {
              Get.back();
              Get.toNamed(AppRoutes.createTournament);
            }),
            SizedBox(height: SizeConfig.h(10)),
            option(Icons.shield_rounded, 'Create a team', 'Invite players with one link', key: const ValueKey('create-team'), () {
              Get.back();
              Get.toNamed(AppRoutes.teamForm);
            }),
            SizedBox(height: SizeConfig.h(10)),
            option(Icons.sports_score_rounded, 'Score a match', 'Ball by ball, goal by goal', () {
              Get.back();
              showComingSoon('Live scoring');
            }),
          ],
        ),
      ),
    ),
  );
}

/// Row in "My tournaments": logo, name, status and team counts.
class MyTournamentCard extends StatelessWidget {
  final MyTournament t;
  final VoidCallback onTap;
  const MyTournamentCard({super.key, required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sport = Sports.byCode(t.sport);
    final d = t.startDate;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final draft = t.status == 'DRAFT';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(SizeConfig.r(12)),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(SizeConfig.r(18)), border: Border.all(color: Colors.white.withAlpha(12))),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(SizeConfig.r(12)),
              child: SizedBox(
                width: SizeConfig.r(62),
                height: SizeConfig.r(62),
                child: t.logoUrl != null
                    ? Image.network(t.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _LogoFallback(size: SizeConfig.r(62), sport: t.sport))
                    : _LogoFallback(size: SizeConfig.r(62), sport: t.sport),
              ),
            ),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(8), vertical: SizeConfig.h(3)),
                        decoration: BoxDecoration(
                          color: (draft ? Colors.white : AppColors.primary).withAlpha(30),
                          borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                        ),
                        child: Text(t.statusLabel.toUpperCase(),
                            style: _gilroy(9.5, weight: FontWeight.w800, color: draft ? Colors.white.withAlpha(170) : AppColors.primary)),
                      ),
                      SizedBox(width: SizeConfig.w(6)),
                      Text('ORGANISER', style: _gilroy(9.5, weight: FontWeight.w800, color: Colors.white.withAlpha(110))),
                    ],
                  ),
                  SizedBox(height: SizeConfig.h(5)),
                  Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _gilroy(16, weight: FontWeight.w800)),
                  SizedBox(height: SizeConfig.h(2)),
                  Text(
                    [
                      sport?.label ?? t.sport,
                      if (d != null) '${d.day} ${months[d.month - 1]}',
                      '${t.approvedTeams}/${t.maxTeams} teams',
                      if (t.pendingTeams > 0) '${t.pendingTeams} waiting',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _gilroy(12, color: Colors.white.withAlpha(140)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(100)),
          ],
        ),
      ),
    );
  }
}
