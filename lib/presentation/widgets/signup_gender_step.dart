import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/signup_controller.dart';

class SignupGenderStep extends GetView<SignupController> {
  const SignupGenderStep({super.key});

  static const _options = [
    ('Male', 'He / Him', Icons.man_rounded),
    ('Female', 'She / Her', Icons.woman_rounded),
    ('Non-binary', 'They / Them', Icons.transgender_rounded),
    ('Prefer not to say', '', Icons.shield_rounded),
  ];

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
                  'How do you\nidentify? 🙌',
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
                  'This helps us personalise your experience',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(15),
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                SizedBox(height: SizeConfig.h(32)),
                Obx(() => Column(
                      children: _options.map((option) {
                        final (label, pronoun, icon) = option;
                        final isSelected = controller.gender.value == label;
                        return Padding(
                          padding:
                              EdgeInsets.only(bottom: SizeConfig.h(12)),
                          child: GestureDetector(
                            onTap: () => controller.gender.value = label,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: EdgeInsets.symmetric(
                                horizontal: SizeConfig.w(16),
                                vertical: SizeConfig.h(18),
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withAlpha(25)
                                    : AppColors.primary.withAlpha(8),
                                borderRadius:
                                    BorderRadius.circular(SizeConfig.r(14)),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.primary.withAlpha(35),
                                  width: isSelected ? 2 : 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: SizeConfig.r(44),
                                    height: SizeConfig.r(44),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withAlpha(40)
                                          : AppColors.primary.withAlpha(15),
                                      borderRadius: BorderRadius.circular(
                                          SizeConfig.r(12)),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.white.withAlpha(160),
                                      size: SizeConfig.r(24),
                                    ),
                                  ),
                                  SizedBox(width: SizeConfig.w(14)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontFamily: 'Gilroy',
                                            fontWeight: FontWeight.w700,
                                            fontSize: SizeConfig.sp(15),
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.white,
                                          ),
                                        ),
                                        if (pronoun.isNotEmpty) ...[
                                          SizedBox(height: SizeConfig.h(2)),
                                          Text(
                                            pronoun,
                                            style: TextStyle(
                                              fontFamily: 'Gilroy',
                                              fontWeight: FontWeight.w400,
                                              fontSize: SizeConfig.sp(13),
                                              color:
                                                  Colors.white.withAlpha(120),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    width: SizeConfig.r(22),
                                    height: SizeConfig.r(22),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.white.withAlpha(60),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: SizeConfig.r(14),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )),
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
            final hasSelection = controller.gender.value.isNotEmpty;
            return SizedBox(
              width: double.infinity,
              height: SizeConfig.h(56),
              child: ElevatedButton(
                onPressed: hasSelection ? controller.nextStep : null,
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
}
