import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import 'home_section_title.dart';

class HomeAllVenuesSection extends GetView<HomeController> {
  const HomeAllVenuesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionTitle('ALL SPORTS VENUES'),
        SizedBox(height: SizeConfig.h(14)),
        SizedBox(
          height: SizeConfig.h(40),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
            children: [
              Container(
                margin: EdgeInsets.only(right: SizeConfig.w(10)),
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14)),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                  border: Border.all(color: AppColors.primary.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, color: AppColors.primary, size: SizeConfig.r(16)),
                    SizedBox(width: SizeConfig.w(6)),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w700,
                        fontSize: SizeConfig.sp(13),
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Obx(() => Row(
                    children: controller.filters.map((f) {
                      final selected = f == controller.selectedFilter.value;
                      return GestureDetector(
                        onTap: () => controller.selectFilter(f),
                        child: Container(
                          margin: EdgeInsets.only(right: SizeConfig.w(10)),
                          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14)),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? Colors.white.withAlpha(20) : Colors.white.withAlpha(8),
                            borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                            border: Border.all(
                              color: selected ? Colors.white.withAlpha(80) : Colors.white.withAlpha(25),
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w600,
                              fontSize: SizeConfig.sp(13),
                              color: selected ? Colors.white : Colors.white.withAlpha(140),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )),
            ],
          ),
        ),
        SizedBox(height: SizeConfig.h(16)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
          child: Column(
            children: controller.allVenues
                .map((v) => Padding(
                      padding: EdgeInsets.only(bottom: SizeConfig.h(12)),
                      child: _AllVenueTile(venue: v),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _AllVenueTile extends StatelessWidget {
  final AllVenue venue;
  const _AllVenueTile({required this.venue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SizeConfig.w(12)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(SizeConfig.r(16)),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        children: [
          Container(
            width: SizeConfig.r(64),
            height: SizeConfig.r(64),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(SizeConfig.r(12)),
            ),
            child: Center(
              child: Text(venue.emoji, style: TextStyle(fontSize: SizeConfig.sp(28))),
            ),
          ),
          SizedBox(width: SizeConfig.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: SizeConfig.sp(14),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: SizeConfig.h(3)),
                Text(
                  '${venue.distance} • ${venue.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(12),
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                SizedBox(height: SizeConfig.h(6)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(8), vertical: SizeConfig.h(3)),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(SizeConfig.r(6)),
                  ),
                  child: Text(
                    venue.sport,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      fontSize: SizeConfig.sp(10),
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            venue.priceFrom,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: SizeConfig.sp(12),
              color: Colors.white.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}
