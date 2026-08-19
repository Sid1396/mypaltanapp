import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import 'home_section_title.dart';

class HomeVenuePromoSection extends StatelessWidget {
  final String title;
  final List<PromoVenue> venues;
  const HomeVenuePromoSection({super.key, required this.title, required this.venues});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(title),
        SizedBox(height: SizeConfig.h(14)),
        SizedBox(
          height: SizeConfig.h(240),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
            itemCount: venues.length,
            separatorBuilder: (_, __) => SizedBox(width: SizeConfig.w(14)),
            itemBuilder: (_, i) => _PromoVenueCard(venue: venues[i]),
          ),
        ),
      ],
    );
  }
}

class _PromoVenueCard extends StatelessWidget {
  final PromoVenue venue;
  const _PromoVenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SizeConfig.w(220),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(SizeConfig.r(18)),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: SizeConfig.h(110),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withAlpha(90),
                      AppColors.primary.withAlpha(20),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(venue.emoji, style: TextStyle(fontSize: SizeConfig.sp(48))),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.w(10),
                    vertical: SizeConfig.h(5),
                  ),
                  color: AppColors.primary.withAlpha(230),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer_rounded, color: Colors.white, size: SizeConfig.r(12)),
                      SizedBox(width: SizeConfig.w(6)),
                      Text(
                        venue.discountLabel,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w700,
                          fontSize: SizeConfig.sp(11),
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(SizeConfig.w(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        venue.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w700,
                          fontSize: SizeConfig.sp(13),
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (venue.rating != null) ...[
                      SizedBox(width: SizeConfig.w(6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: SizeConfig.w(6),
                          vertical: SizeConfig.h(3),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.positive.withAlpha(35),
                          borderRadius: BorderRadius.circular(SizeConfig.r(6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: AppColors.positive, size: SizeConfig.r(12)),
                            Text(
                              ' ${venue.rating}',
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w700,
                                fontSize: SizeConfig.sp(11),
                                color: AppColors.positive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: SizeConfig.h(4)),
                Text(
                  '${venue.distance} • ${venue.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(11),
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                SizedBox(height: SizeConfig.h(6)),
                Text(
                  venue.priceFrom,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.sp(12),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
