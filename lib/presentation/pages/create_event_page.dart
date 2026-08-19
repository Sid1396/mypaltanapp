import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../bindings/create_event_binding.dart';
import '../controllers/create_event_controller.dart';
import '../widgets/create_event_basic_info_step.dart';
import '../widgets/create_event_payment_step.dart';
import '../widgets/create_event_turf_step.dart';

class CreateEventPage extends StatelessWidget {
  const CreateEventPage({super.key});

  @override
  Widget build(BuildContext context) {
    CreateEventBinding().dependencies();
    final controller = Get.find<CreateEventController>();

    return Scaffold(
      backgroundColor: AppColors.secondary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Obx(() => _StepHeader(step: controller.currentStep.value, onBack: controller.prevStep)),
            Expanded(
              child: PageView(
                controller: controller.pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  CreateEventBasicInfoStep(),
                  CreateEventTurfStep(),
                  CreateEventPaymentStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final VoidCallback onBack;
  const _StepHeader({required this.step, required this.onBack});

  static const _labels = ['Basic Info', 'Select Turf', 'Payment'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(12)),
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
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: SizeConfig.r(18), color: Colors.white),
                ),
              ),
              const Spacer(),
              Text(
                'Step ${step + 1} of 3 · ${_labels[step]}',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                  fontSize: SizeConfig.sp(13),
                  color: Colors.white.withAlpha(140),
                ),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.h(12)),
          ClipRRect(
            borderRadius: BorderRadius.circular(SizeConfig.r(4)),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (step + 1) / 3),
              duration: const Duration(milliseconds: 350),
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
