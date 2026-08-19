import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/signup_controller.dart';
import '../widgets/signup_birthdate_step.dart';
import '../widgets/signup_gender_step.dart';
import '../widgets/signup_name_step.dart';
import '../widgets/signup_pincode_step.dart';
import '../widgets/signup_sports_step.dart';
import '../widgets/signup_skill_step.dart';
import '../widgets/signup_profile_pic_step.dart';
import '../widgets/signup_success.dart';

class SignupPage extends GetView<SignupController> {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Column(
          children: [
            Obx(() => _SignupHeader(
                  step: controller.currentStep,
                  onBack: controller.prevStep,
                )),
            Expanded(
              child: PageView(
                controller: controller.pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  SignupNameStep(),
                  SignupBirthdateStep(),
                  SignupGenderStep(),
                  SignupPincodeStep(),
                  SignupSportsStep(),
                  SignupSkillStep(),
                  SignupProfilePicStep(),
                  SignupSuccess(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupHeader extends StatelessWidget {
  final int step;
  final VoidCallback onBack;

  const _SignupHeader({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    if (step >= 7) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SizeConfig.w(20),
        SizeConfig.h(16),
        SizeConfig.w(20),
        SizeConfig.h(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: SizeConfig.r(40),
                  height: SizeConfig.r(40),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: SizeConfig.r(18),
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Step ${step + 1} of 7',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                  fontSize: SizeConfig.sp(14),
                  color: Colors.white.withAlpha(140),
                ),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.h(12)),
          ClipRRect(
            borderRadius: BorderRadius.circular(SizeConfig.r(4)),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (step + 1) / 7),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white.withAlpha(20),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: SizeConfig.h(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
