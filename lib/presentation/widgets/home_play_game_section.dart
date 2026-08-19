import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import 'home_section_title.dart';

class HomePlayGameSection extends GetView<HomeController> {
  const HomePlayGameSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionTitle('PLAY YOUR GAME'),
        SizedBox(height: SizeConfig.h(14)),
        SizedBox(
          height: SizeConfig.h(300),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
            itemCount: controller.playVenues.length,
            separatorBuilder: (_, __) => SizedBox(width: SizeConfig.w(14)),
            itemBuilder: (_, i) {
              final venue = controller.playVenues[i];
              return Container(
                width: SizeConfig.w(280),
                padding: EdgeInsets.all(SizeConfig.w(16)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withAlpha(60),
                      AppColors.primary.withAlpha(15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(SizeConfig.r(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Box Cricket',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w800,
                              fontSize: SizeConfig.sp(20),
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(venue.emoji, style: TextStyle(fontSize: SizeConfig.sp(36))),
                      ],
                    ),
                    Text(
                      'slots available today',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: SizeConfig.sp(13),
                        color: Colors.white.withAlpha(160),
                      ),
                    ),
                    SizedBox(height: SizeConfig.h(16)),
                    Container(
                      padding: EdgeInsets.all(SizeConfig.w(12)),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withAlpha(140),
                        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: SizeConfig.r(44),
                                height: SizeConfig.r(44),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(SizeConfig.r(10)),
                                ),
                                child: Center(
                                  child: Text(venue.emoji, style: TextStyle(fontSize: SizeConfig.sp(20))),
                                ),
                              ),
                              SizedBox(width: SizeConfig.w(10)),
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
                                        fontSize: SizeConfig.sp(13),
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${venue.distance} • ${venue.area}',
                                      style: TextStyle(
                                        fontFamily: 'Gilroy',
                                        fontWeight: FontWeight.w400,
                                        fontSize: SizeConfig.sp(11),
                                        color: Colors.white.withAlpha(140),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: SizeConfig.h(12)),
                          Row(
                            children: venue.slots
                                .map((s) => Expanded(
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          right: s == venue.slots.last ? 0 : SizeConfig.w(8),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: SizeConfig.h(8)),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(SizeConfig.r(10)),
                                          border: Border.all(color: Colors.white.withAlpha(40)),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              s.time,
                                              style: TextStyle(
                                                fontFamily: 'Gilroy',
                                                fontWeight: FontWeight.w700,
                                                fontSize: SizeConfig.sp(12),
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              s.type,
                                              style: TextStyle(
                                                fontFamily: 'Gilroy',
                                                fontWeight: FontWeight.w400,
                                                fontSize: SizeConfig.sp(10),
                                                color: Colors.white.withAlpha(140),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
