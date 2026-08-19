import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/create_event_controller.dart';
import 'create_event_shared_widgets.dart';

class CreateEventBasicInfoStep extends GetView<CreateEventController> {
  const CreateEventBasicInfoStep({super.key});

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
                  'Tell us about\nyour event 🎉',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                    fontSize: SizeConfig.sp(28),
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: SizeConfig.h(24)),

                const FieldLabel('Event Title'),
                SizedBox(height: SizeConfig.h(8)),
                FieldTextInput(
                  controller: controller.titleController,
                  hint: 'e.g. Sunday Morning Box Cricket',
                  textCapitalization: TextCapitalization.sentences,
                ),
                SizedBox(height: SizeConfig.h(24)),

                const FieldLabel('Sport'),
                SizedBox(height: SizeConfig.h(10)),
                Obx(() => Wrap(
                      spacing: SizeConfig.w(10),
                      runSpacing: SizeConfig.h(10),
                      children: CreateEventController.sports.map((s) {
                        final selected = s == controller.selectedSport.value;
                        return GestureDetector(
                          onTap: () => controller.selectSport(s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: EdgeInsets.symmetric(
                              horizontal: SizeConfig.w(14),
                              vertical: SizeConfig.h(10),
                            ),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary : AppColors.primary.withAlpha(8),
                              borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                              border: Border.all(
                                color: selected ? AppColors.primary : AppColors.primary.withAlpha(35),
                                width: selected ? 2 : 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(CreateEventController.sportEmojis[s]!,
                                    style: TextStyle(fontSize: SizeConfig.sp(15))),
                                SizedBox(width: SizeConfig.w(6)),
                                Text(
                                  s,
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontWeight: FontWeight.w600,
                                    fontSize: SizeConfig.sp(13),
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    )),
                SizedBox(height: SizeConfig.h(24)),

                const FieldLabel('Date & Time'),
                SizedBox(height: SizeConfig.h(10)),
                Row(
                  children: [
                    Expanded(
                      child: Obx(() => FieldPicker(
                            icon: Icons.calendar_today_rounded,
                            label: controller.selectedDate.value == null
                                ? 'Date'
                                : '${controller.selectedDate.value!.day.toString().padLeft(2, '0')}/${controller.selectedDate.value!.month.toString().padLeft(2, '0')}/${controller.selectedDate.value!.year}',
                            filled: controller.selectedDate.value != null,
                            onTap: () => controller.pickDate(context),
                          )),
                    ),
                    SizedBox(width: SizeConfig.w(12)),
                    Expanded(
                      child: Obx(() => FieldPicker(
                            icon: Icons.access_time_rounded,
                            label: controller.selectedTime.value?.format(context) ?? 'Time',
                            filled: controller.selectedTime.value != null,
                            onTap: () => controller.pickTime(context),
                          )),
                    ),
                  ],
                ),
                SizedBox(height: SizeConfig.h(24)),

                const FieldLabel('Max Participants'),
                SizedBox(height: SizeConfig.h(8)),
                FieldTextInput(
                  controller: controller.maxSpotsController,
                  hint: 'e.g. 10',
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: SizeConfig.h(24)),

                const FieldLabel('Entry Fee'),
                SizedBox(height: SizeConfig.h(10)),
                Obx(() => Row(
                      children: [
                        PillToggle(
                          label: 'Free',
                          selected: controller.isFree.value,
                          onTap: () => controller.toggleFree(true),
                        ),
                        SizedBox(width: SizeConfig.w(10)),
                        PillToggle(
                          label: 'Paid',
                          selected: !controller.isFree.value,
                          onTap: () => controller.toggleFree(false),
                        ),
                      ],
                    )),
                Obx(() {
                  if (controller.isFree.value) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.only(top: SizeConfig.h(12)),
                    child: FieldTextInput(
                      controller: controller.feeController,
                      hint: 'Amount per person (₹)',
                      keyboardType: TextInputType.number,
                    ),
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
