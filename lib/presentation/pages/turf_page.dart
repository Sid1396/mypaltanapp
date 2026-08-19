import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../bindings/turf_binding.dart';
import '../controllers/turf_controller.dart';
import '../widgets/turf_card.dart';
import '../widgets/turf_filter_row.dart';

class TurfPage extends StatelessWidget {
  const TurfPage({super.key});

  @override
  Widget build(BuildContext context) {
    TurfBinding().dependencies();
    final controller = Get.find<TurfController>();

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.h(12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
              child: Text(
                'Turfs Near You',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w900,
                  fontSize: SizeConfig.sp(26),
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: SizeConfig.h(16)),
            const TurfFilterRow(),
            SizedBox(height: SizeConfig.h(16)),
            Expanded(
              child: Obx(() {
                final turfs = controller.filteredTurfs;
                if (turfs.isEmpty) {
                  return Center(
                    child: Text(
                      'No turfs found',
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
                    children: turfs.map((t) => TurfCard(turf: t)).toList(),
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
