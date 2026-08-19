import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/create_event_controller.dart';
import '../controllers/turf_controller.dart';
import 'create_event_shared_widgets.dart';

class CreateEventTurfStep extends GetView<CreateEventController> {
  const CreateEventTurfStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.h(12)),
                Text(
                  'Pick a turf\nto book 📍',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                    fontSize: SizeConfig.sp(28),
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: SizeConfig.h(8)),
                Obx(() => Text(
                      'Showing turfs for ${controller.selectedSport.value ?? "your sport"}',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: SizeConfig.sp(14),
                        color: Colors.white.withAlpha(140),
                      ),
                    )),
                SizedBox(height: SizeConfig.h(20)),
                Obx(() => Column(
                      children: controller.turfsForSport
                          .map((t) => _SelectableTurfTile(turf: t))
                          .toList(),
                    )),
                Obx(() {
                  final turf = controller.selectedTurf.value;
                  if (turf == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: SizeConfig.h(8)),
                      const FieldLabel('Available Slots'),
                      SizedBox(height: SizeConfig.h(10)),
                      Wrap(
                        spacing: SizeConfig.w(10),
                        runSpacing: SizeConfig.h(10),
                        children: TurfListing.availableSlots.map((slot) {
                          final selected = slot == controller.selectedSlot.value;
                          return GestureDetector(
                            onTap: () => controller.selectSlot(slot),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: SizeConfig.w(14),
                                vertical: SizeConfig.h(10),
                              ),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : AppColors.primary.withAlpha(8),
                                borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                                border: Border.all(
                                  color: selected ? AppColors.primary : AppColors.primary.withAlpha(35),
                                  width: selected ? 1.8 : 1.2,
                                ),
                              ),
                              child: Text(
                                slot,
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w600,
                                  fontSize: SizeConfig.sp(13),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }),
                SizedBox(height: SizeConfig.h(32)),
              ],
            ),
          ),
        ),
        StepBottomButton(label: 'Continue', onPressed: controller.nextStep),
      ],
    );
  }
}

class _SelectableTurfTile extends GetView<CreateEventController> {
  final TurfListing turf;
  const _SelectableTurfTile({required this.turf});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = turf == controller.selectedTurf.value;
      return GestureDetector(
        onTap: () => controller.selectTurf(turf),
        child: Container(
          margin: EdgeInsets.only(bottom: SizeConfig.h(12)),
          padding: EdgeInsets.all(SizeConfig.w(12)),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withAlpha(15) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(SizeConfig.r(16)),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.white.withAlpha(15),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: SizeConfig.r(56),
                height: SizeConfig.r(56),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                ),
                child: Center(
                  child: Text(turf.emoji, style: TextStyle(fontSize: SizeConfig.sp(26))),
                ),
              ),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      turf.name,
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
                      '${turf.distance} • ${turf.area}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w400,
                        fontSize: SizeConfig.sp(12),
                        color: Colors.white.withAlpha(140),
                      ),
                    ),
                    SizedBox(height: SizeConfig.h(4)),
                    Text(
                      turf.priceFrom,
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
              if (selected)
                Icon(Icons.check_circle_rounded, color: AppColors.primary, size: SizeConfig.r(22)),
            ],
          ),
        ),
      );
    });
  }
}
