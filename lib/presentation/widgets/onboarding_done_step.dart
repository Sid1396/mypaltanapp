import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../data/services/session_service.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/onboarding_controller.dart';
import 'form_widgets.dart';
import 'onboarding_widgets.dart';

class OnboardingDoneStep extends GetView<OnboardingController> {
  const OnboardingDoneStep({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Get.find<SessionService>().user.value;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: JerseyPreview(
                    name: user?.jerseyName ?? controller.jerseyName.value,
                    number: (user?.jerseyNumber ?? controller.jerseyNumber.value).toString(),
                    width: SizeConfig.w(200),
                  ),
                ),
                SizedBox(height: SizeConfig.h(28)),
                Text(
                  "You're in, ${user?.firstName ?? 'player'}!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w900, fontSize: SizeConfig.sp(30), color: Colors.white),
                ),
                SizedBox(height: SizeConfig.h(10)),
                Text(
                  'Your profile is ready. Join a team, play tournaments and every run, goal and point will count.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(15), height: 1.5, color: Colors.white.withAlpha(150)),
                ),
                SizedBox(height: SizeConfig.h(18)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(8)),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                  ),
                  child: Text(
                    'Free for everyone · No ads',
                    style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(12), color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        StepBottomButton(label: "Let's play", onPressed: controller.finish),
      ],
    );
  }
}
