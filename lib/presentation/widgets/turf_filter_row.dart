import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/turf_controller.dart';

class TurfFilterRow extends GetView<TurfController> {
  const TurfFilterRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SizeConfig.h(40),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
        children: [
          Container(
            margin: EdgeInsets.only(right: SizeConfig.w(10)),
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14)),
            alignment: Alignment.center,
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
    );
  }
}
