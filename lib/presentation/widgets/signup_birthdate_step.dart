import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/signup_controller.dart';

class SignupBirthdateStep extends GetView<SignupController> {
  const SignupBirthdateStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.h(36)),
                Text(
                  "When's your\nbirthday? 🎂",
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                    fontSize: SizeConfig.sp(30),
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: SizeConfig.h(8)),
                Text(
                  'You must be at least 13 years old to join',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(15),
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                SizedBox(height: SizeConfig.h(40)),

                // ── Date selector ─────────────────────────────
                Obx(() {
                  final date = controller.birthdate.value;
                  return GestureDetector(
                    onTap: () => controller.pickDate(context),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: SizeConfig.w(16),
                        vertical: SizeConfig.h(18),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(8),
                        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                        border: Border.all(
                          color: date != null
                              ? AppColors.primary
                              : AppColors.primary.withAlpha(35),
                          width: date != null ? 1.8 : 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cake_rounded,
                            size: SizeConfig.r(22),
                            color: date != null
                                ? AppColors.primary
                                : Colors.white.withAlpha(80),
                          ),
                          SizedBox(width: SizeConfig.w(12)),
                          Expanded(
                            child: Text(
                              date != null
                                  ? _formatDate(date)
                                  : 'Select your birthday',
                              style: TextStyle(
                                color: date != null
                                    ? Colors.white
                                    : Colors.white.withAlpha(80),
                                fontFamily: 'Gilroy',
                                fontWeight: date != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: SizeConfig.sp(16),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit_calendar_rounded,
                            size: SizeConfig.r(18),
                            color: Colors.white.withAlpha(80),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                SizedBox(height: SizeConfig.h(16)),

                // ── Age badge ─────────────────────────────────
                Obx(() {
                  final date = controller.birthdate.value;
                  if (date == null) return const SizedBox.shrink();
                  final age = controller.age;
                  return Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: SizeConfig.w(14),
                          vertical: SizeConfig.h(8),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius:
                              BorderRadius.circular(SizeConfig.r(100)),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(80),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          '$age years old',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontWeight: FontWeight.w700,
                            fontSize: SizeConfig.sp(13),
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),

        // ── Continue button ───────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            SizeConfig.w(24),
            0,
            SizeConfig.w(24),
            SizeConfig.h(24),
          ),
          child: Obx(() {
            final hasDate = controller.birthdate.value != null;
            return SizedBox(
              width: double.infinity,
              height: SizeConfig.h(56),
              child: ElevatedButton(
                onPressed: hasDate ? controller.nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withAlpha(60),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: SizeConfig.sp(16),
                    color: Colors.white,
                    letterSpacing: SizeConfig.w(0.3),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}
