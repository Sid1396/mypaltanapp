import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
      child: Container(
        height: SizeConfig.h(52),
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(16)),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(SizeConfig.r(16)),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: Colors.white.withAlpha(140),
              size: SizeConfig.r(22),
            ),
            SizedBox(width: SizeConfig.w(10)),
            Text(
              "Search for 'Cricket'",
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w400,
                fontSize: SizeConfig.sp(15),
                color: Colors.white.withAlpha(140),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeCategoryTabs extends GetView<HomeController> {
  const HomeCategoryTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SizeConfig.h(44),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
        itemCount: controller.categories.length,
        separatorBuilder: (_, __) => SizedBox(width: SizeConfig.w(24)),
        itemBuilder: (_, i) {
          final cat = controller.categories[i];
          return GestureDetector(
            onTap: () => controller.selectCategory(cat),
            child: Obx(() {
              final selected = cat == controller.selectedCategory.value;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cat,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      fontSize: SizeConfig.sp(15),
                      color: selected ? Colors.white : Colors.white.withAlpha(120),
                    ),
                  ),
                  SizedBox(height: SizeConfig.h(6)),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 2.5,
                    width: selected ? SizeConfig.w(28) : 0,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}
