import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/signup_controller.dart';

class SignupSkillStep extends GetView<SignupController> {
  const SignupSkillStep({super.key});

  static const _levels = [
    ('Beginner', 'First time or still learning', Icons.emoji_people_rounded),
    ('Intermediate', 'Play regularly, know the basics', Icons.sports_rounded),
    ('Advanced', 'Competitive, experienced player', Icons.emoji_events_rounded),
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
                  "What's your\nskill level? 🎯",
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
                  "We'll match you with the right players",
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(15),
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                SizedBox(height: SizeConfig.h(32)),
                Obx(() => Column(
                      children: _levels.map((level) {
                        final (title, subtitle, icon) = level;
                        final isSelected =
                            controller.skillLevel.value == title;
                        return Padding(
                          padding: EdgeInsets.only(bottom: SizeConfig.h(12)),
                          child: GestureDetector(
                            onTap: () => controller.skillLevel.value = title,
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
                                      size: SizeConfig.r(22),
                                    ),
                                  ),
                                  SizedBox(width: SizeConfig.w(14)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontFamily: 'Gilroy',
                                            fontWeight: FontWeight.w700,
                                            fontSize: SizeConfig.sp(15),
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: SizeConfig.h(2)),
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            fontFamily: 'Gilroy',
                                            fontWeight: FontWeight.w400,
                                            fontSize: SizeConfig.sp(13),
                                            color: Colors.white.withAlpha(120),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
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
        Padding(
          padding: EdgeInsets.fromLTRB(
            SizeConfig.w(24),
            0,
            SizeConfig.w(24),
            SizeConfig.h(24),
          ),
          child: SizedBox(
            width: double.infinity,
            height: SizeConfig.h(56),
            child: ElevatedButton(
              onPressed: controller.nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
          ),
        ),
      ],
    );
  }
}
