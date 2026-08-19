import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../utils/helpers/size_config.dart';
import '../bindings/mypaltan_binding.dart';
import '../controllers/mypaltan_controller.dart';
import '../widgets/mypaltan_event_card.dart';
import '../widgets/mypaltan_search_bar.dart';

class MyPaltanPage extends StatelessWidget {
  const MyPaltanPage({super.key});

  @override
  Widget build(BuildContext context) {
    MyPaltanBinding().dependencies();
    final controller = Get.find<MyPaltanController>();

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.h(12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
              child: Row(
                children: [
                  Text(
                    'MyPaltan',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w900,
                      fontSize: SizeConfig.sp(26),
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.createEvent),
                    child: Container(
                      width: SizeConfig.r(44),
                      height: SizeConfig.r(44),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: SizeConfig.r(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: SizeConfig.h(16)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
              child: const MyPaltanSearchBar(),
            ),
            SizedBox(height: SizeConfig.h(20)),
            Expanded(
              child: Obx(() {
                final events = controller.filteredEvents;
                if (events.isEmpty) {
                  return Center(
                    child: Text(
                      'No events found',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w500,
                        fontSize: SizeConfig.sp(14),
                        color: Colors.white.withAlpha(120),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
                  child: Column(
                    children: events
                        .map((e) => MyPaltanEventCard(event: e))
                        .toList(),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
