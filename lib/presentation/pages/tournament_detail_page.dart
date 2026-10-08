import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../data/models/home_models.dart';
import '../../utils/helpers/size_config.dart';
import '../widgets/form_widgets.dart';
import '../widgets/home_widgets.dart';

class TournamentDetailPage extends StatelessWidget {
  const TournamentDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Get.arguments as FeaturedTournament;
    final sport = Sports.byCode(t.sport);
    TextStyle style(double size, {FontWeight w = FontWeight.w400, Color? color}) =>
        TextStyle(fontFamily: 'Gilroy', fontWeight: w, fontSize: SizeConfig.sp(size), color: color ?? Colors.white);

    Widget infoRow(IconData icon, String label, String value) => Padding(
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(8)),
          child: Row(
            children: [
              Container(
                width: SizeConfig.r(38),
                height: SizeConfig.r(38),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(SizeConfig.r(10))),
                child: Icon(icon, color: AppColors.primary, size: SizeConfig.r(19)),
              ),
              SizedBox(width: SizeConfig.w(12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: style(12, color: Colors.white.withAlpha(130))),
                  Text(value, style: style(15, w: FontWeight.w700)),
                ],
              ),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: SizeConfig.h(320),
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  systemOverlayStyle: SystemUiOverlayStyle.light,
                  automaticallyImplyLeading: false,
                  // Dark circular back button so it stays visible on light logos.
                  leading: Padding(
                    padding: EdgeInsets.only(left: SizeConfig.w(12)),
                    child: Center(
                      child: GestureDetector(
                        onTap: Get.back,
                        child: Container(
                          width: SizeConfig.r(40),
                          height: SizeConfig.r(40),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(170),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(40)),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: SizeConfig.r(18)),
                        ),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        t.logoUrl != null
                            ? Image.network(t.logoUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)))
                            : Container(color: const Color(0xFF1A1A1A)),
                        // Darkens the top so the status bar and back button read on any image.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x99000000), Color(0x00000000)],
                              stops: [0, 0.35],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(SizeConfig.r(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(5)),
                          decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                          child: Text(t.statusLabel.toUpperCase(), style: style(11, w: FontWeight.w700, color: AppColors.primary)),
                        ),
                        SizedBox(height: SizeConfig.h(12)),
                        Text(t.name, style: style(26, w: FontWeight.w900)),
                        if (t.tags.isNotEmpty) ...[
                          SizedBox(height: SizeConfig.h(10)),
                          Wrap(
                            spacing: SizeConfig.w(8),
                            runSpacing: SizeConfig.h(8),
                            children: t.tags
                                .map((tag) => Container(
                                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(5)),
                                      decoration: BoxDecoration(color: Colors.white.withAlpha(12), borderRadius: BorderRadius.circular(SizeConfig.r(8))),
                                      child: Text(tag, style: style(12, w: FontWeight.w600)),
                                    ))
                                .toList(),
                          ),
                        ],
                        SizedBox(height: SizeConfig.h(16)),
                        infoRow(Icons.sports_rounded, 'Sport', sport?.label ?? t.sport),
                        infoRow(Icons.calendar_today_rounded, 'Starts', t.dateLabel),
                        infoRow(Icons.place_rounded, 'Where', t.location),
                        SizedBox(height: SizeConfig.h(12)),
                        Text(
                          'Registrations for this tournament will open on MyPaltan. Team captains will be able to register their squad, and every match will be scored live with stats for every player.',
                          style: style(14, color: Colors.white.withAlpha(150)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: StepBottomButton(
              label: t.status == 'REGISTRATION_OPEN' ? 'Register my team' : 'Notify me when registration opens',
              onPressed: () => showComingSoon(
                'Tournament registration',
                detail: "We'll notify you when registrations for ${t.name} open.",
              ),
            ),
          ),
        ],
      ),
    );
  }
}
