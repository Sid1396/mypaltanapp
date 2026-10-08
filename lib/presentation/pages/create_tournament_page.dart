import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/create_tournament_controller.dart';
import '../widgets/create_tournament_steps.dart';
import '../widgets/form_widgets.dart';
import '../widgets/tournament_form_widgets.dart';

class CreateTournamentPage extends GetView<CreateTournamentController> {
  const CreateTournamentPage({super.key});

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
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final step = controller.currentStep;
            final isReview = step == 'review';
            return Column(
              children: [
                _Header(controller: controller),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(key: ValueKey(step), child: stepFor(step)),
                  ),
                ),
                StepBottomButton(
                  key: const ValueKey('t-next'),
                  label: isReview ? (controller.isEditing ? 'Save changes' : 'Create tournament') : 'Continue',
                  loading: controller.isSaving.value,
                  onPressed: controller.next,
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
  final CreateTournamentController controller;
  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final steps = c.steps;
    final current = c.index + 1;
    final step = c.currentStep;
    Widget iconButton(IconData icon, VoidCallback onTap, {Key? key}) => GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            width: SizeConfig.r(40),
            height: SizeConfig.r(40),
            decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
            child: Icon(icon, size: SizeConfig.r(18), color: Colors.white),
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(12)),
      child: Column(
        children: [
          Row(
            children: [
              iconButton(c.index == 0 ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded, c.back, key: const ValueKey('t-back')),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.isEditing ? 'Edit tournament' : 'New tournament', style: tfStyle(12, color: Colors.white.withAlpha(130))),
                    Text('Step $current of ${steps.length} · ${CreateTournamentController.stepTitles[step]}',
                        style: tfStyle(14, weight: FontWeight.w700)),
                  ],
                ),
              ),
              if (c.reviewReached.value && step != 'review')
                GestureDetector(
                  onTap: () => c.goTo('review'),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(8)),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                    child: Text('Review', style: tfStyle(12.5, weight: FontWeight.w700)),
                  ),
                )
              else if (c.index > 0)
                iconButton(Icons.close_rounded, c.requestClose),
            ],
          ),
          gapH(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(SizeConfig.r(4)),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: current / steps.length),
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
