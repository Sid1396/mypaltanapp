import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../bindings/home_binding.dart';
import '../widgets/home_carousel.dart';
import '../widgets/home_events_section.dart';
import '../widgets/home_header.dart';
import '../widgets/home_pick_sport_section.dart';
import '../widgets/home_play_game_section.dart';
import '../widgets/home_venue_promo_section.dart';
import '../widgets/home_vendors_section.dart';
import '../controllers/home_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    HomeBinding().dependencies();
    final controller = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const HomeHeader(),
            SizedBox(height: SizeConfig.h(16)),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HomeCarousel(),
                    SizedBox(height: SizeConfig.h(24)),
                    const HomePickSportSection(),
                    SizedBox(height: SizeConfig.h(28)),
                    HomeEventsSection(
                      title: 'SPORTING EVENTS NEAR YOU',
                      events: controller.events,
                    ),
                    SizedBox(height: SizeConfig.h(28)),
                    HomeVenuePromoSection(
                      title: 'FEATURED VENUES',
                      venues: controller.promoVenues,
                    ),
                    SizedBox(height: SizeConfig.h(28)),
                    HomeVenuePromoSection(
                      title: 'JOIN THE PICKLEBALL CRAZE',
                      venues: controller.pickleballVenues,
                    ),
                    SizedBox(height: SizeConfig.h(28)),
                    HomeEventsSection(
                      title: 'UPCOMING TOURNAMENTS',
                      events: controller.upcomingTournaments,
                    ),
                    SizedBox(height: SizeConfig.h(28)),
                    const HomeVendorsSection(),
                    SizedBox(height: SizeConfig.h(28)),
                    const HomePlayGameSection(),
                    SizedBox(height: SizeConfig.h(24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
