import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import 'home_section_title.dart';

class HomePickSportSection extends GetView<HomeController> {
  const HomePickSportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionTitle('PICK A SPORT'),
        SizedBox(height: SizeConfig.h(14)),
        SizedBox(
          height: SizeConfig.h(148),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
            itemCount: controller.sports.length,
            separatorBuilder: (_, __) => SizedBox(width: SizeConfig.w(12)),
            itemBuilder: (_, i) {
              final sport = controller.sports[i];
              return Container(
                width: SizeConfig.w(120),
                padding: EdgeInsets.symmetric(vertical: SizeConfig.h(14)),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(SizeConfig.r(18)),
                  border: Border.all(color: AppColors.primary.withAlpha(30)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(sport.iconAsset, width: SizeConfig.r(44), height: SizeConfig.r(44)),
                    SizedBox(height: SizeConfig.h(10)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(6)),
                      child: Text(
                        sport.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w700,
                          fontSize: SizeConfig.sp(13),
                          color: Colors.white,
                          height: 1.2,
                        ),
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
