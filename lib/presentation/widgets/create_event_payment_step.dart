import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/create_event_controller.dart';
import 'create_event_shared_widgets.dart';

class CreateEventPaymentStep extends GetView<CreateEventController> {
  const CreateEventPaymentStep({super.key});

  static const _methodIcons = {
    'UPI': Icons.qr_code_rounded,
    'Card': Icons.credit_card_rounded,
    'Net Banking': Icons.account_balance_rounded,
  };

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
                  'Confirm &\npay for the slot 💳',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                    fontSize: SizeConfig.sp(28),
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: SizeConfig.h(24)),

                // ── Booking summary ────────────────────────
                Obx(() {
                  final turf = controller.selectedTurf.value;
                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(SizeConfig.w(16)),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(SizeConfig.r(18)),
                      border: Border.all(color: Colors.white.withAlpha(15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              CreateEventController.sportEmojis[controller.selectedSport.value] ?? '',
                              style: TextStyle(fontSize: SizeConfig.sp(22)),
                            ),
                            SizedBox(width: SizeConfig.w(8)),
                            Expanded(
                              child: Text(
                                controller.titleController.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontWeight: FontWeight.w800,
                                  fontSize: SizeConfig.sp(16),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(color: Colors.white.withAlpha(20), height: SizeConfig.h(28)),
                        _SummaryRow(icon: Icons.location_on_rounded, label: turf?.name ?? ''),
                        SizedBox(height: SizeConfig.h(10)),
                        _SummaryRow(
                          icon: Icons.calendar_today_rounded,
                          label: controller.formattedDateTime,
                        ),
                        SizedBox(height: SizeConfig.h(10)),
                        _SummaryRow(
                          icon: Icons.access_time_rounded,
                          label: 'Slot: ${controller.selectedSlot.value ?? ''}',
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: SizeConfig.h(20)),

                // ── Price breakdown ─────────────────────────
                const FieldLabel('Price Breakdown'),
                SizedBox(height: SizeConfig.h(10)),
                Obx(() => Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(SizeConfig.w(16)),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(8),
                        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                        border: Border.all(color: AppColors.primary.withAlpha(35)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Turf Booking (1 hr)',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w500,
                              fontSize: SizeConfig.sp(14),
                              color: Colors.white.withAlpha(180),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '₹${controller.bookingTotal}',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w800,
                              fontSize: SizeConfig.sp(16),
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )),
                SizedBox(height: SizeConfig.h(24)),

                const FieldLabel('Payment Method'),
                SizedBox(height: SizeConfig.h(10)),
                Obx(() => Column(
                      children: CreateEventController.paymentMethods.map((m) {
                        final selected = m == controller.selectedPaymentMethod.value;
                        return GestureDetector(
                          onTap: () => controller.selectPaymentMethod(m),
                          child: Container(
                            margin: EdgeInsets.only(bottom: SizeConfig.h(10)),
                            padding: EdgeInsets.symmetric(
                              horizontal: SizeConfig.w(14),
                              vertical: SizeConfig.h(14),
                            ),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary.withAlpha(15) : AppColors.primary.withAlpha(8),
                              borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                              border: Border.all(
                                color: selected ? AppColors.primary : AppColors.primary.withAlpha(35),
                                width: selected ? 1.8 : 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(_methodIcons[m], color: AppColors.primary, size: SizeConfig.r(20)),
                                SizedBox(width: SizeConfig.w(12)),
                                Text(
                                  m,
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontWeight: FontWeight.w600,
                                    fontSize: SizeConfig.sp(14),
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                  color: selected ? AppColors.primary : Colors.white.withAlpha(80),
                                  size: SizeConfig.r(20),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    )),
                SizedBox(height: SizeConfig.h(24)),
              ],
            ),
          ),
        ),
        Obx(() => StepBottomButton(
              label: 'Confirm & Pay ₹${controller.bookingTotal}',
              onPressed: controller.confirmAndPay,
              loading: controller.isSubmitting.value,
            )),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: SizeConfig.r(15)),
        SizedBox(width: SizeConfig.w(10)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w500,
              fontSize: SizeConfig.sp(13),
              color: Colors.white.withAlpha(180),
            ),
          ),
        ),
      ],
    );
  }
}
