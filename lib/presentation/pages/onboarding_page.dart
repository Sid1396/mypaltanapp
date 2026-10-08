import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/form_widgets.dart';
import '../widgets/onboarding_about_step.dart';
import '../widgets/onboarding_done_step.dart';
import '../widgets/onboarding_jersey_step.dart';
import '../widgets/onboarding_photo_step.dart';
import '../widgets/onboarding_sports_step.dart';

class OnboardingPage extends GetView<OnboardingController> {
  const OnboardingPage({super.key});

  static const _buttonLabels = {'about': 'Continue', 'jersey': 'Continue', 'sports': 'Continue', 'photo': 'Finish'};

  Widget _stepView(String step) => switch (step) {
        'about' => const OnboardingAboutStep(),
        'jersey' => const OnboardingJerseyStep(),
        'sports' => const OnboardingSportsStep(),
        'photo' => const OnboardingPhotoStep(),
        _ => const OnboardingDoneStep(),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.back();
      },
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        body: SafeArea(
          child: Obx(() {
            final step = controller.currentStep;
            // The final screen sits outside the PageView so finishing never disturbs the pager.
            if (step == 'done') return const OnboardingDoneStep();
            return Column(
              children: [
                _Header(controller: controller),
                Expanded(
                  child: PageView(
                    key: const ValueKey('onboarding-pages'),
                    controller: controller.pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (_) {
                      if (controller.currentStep == 'jersey') controller.onEnterJerseyStep();
                    },
                    children: controller.steps.where((s) => s != 'done').map(_stepView).toList(),
                  ),
                ),
                StepBottomButton(
                  label: controller.isEditing ? 'Save' : _buttonLabels[step]!,
                  loading: controller.isSaving.value,
                  onPressed: controller.isStepValid(step) ? controller.next : null,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final OnboardingController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    final total = controller.dataStepCount;
    final current = controller.index + 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(16), SizeConfig.w(20), SizeConfig.h(12)),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: controller.back,
                child: Container(
                  width: SizeConfig.r(40),
                  height: SizeConfig.r(40),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                  ),
                  child: Icon(
                    controller.isEditing ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
                    size: SizeConfig.r(18),
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (!controller.isEditing)
                Text(
                  'Step $current of $total',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.sp(14),
                    color: Colors.white.withAlpha(140),
                  ),
                ),
            ],
          ),
          if (!controller.isEditing) ...[
            SizedBox(height: SizeConfig.h(12)),
            ClipRRect(
              borderRadius: BorderRadius.circular(SizeConfig.r(4)),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: current / total),
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
        ],
      ),
    );
  }
}
