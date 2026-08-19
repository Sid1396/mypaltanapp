import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../controllers/counter_controller.dart';

class CounterDisplay extends GetView<CounterController> {
  const CounterDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final value = controller.value;
      final color = value > 0
          ? AppColors.positive
          : value < 0
              ? AppColors.negative
              : AppColors.neutral;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Text(
          '$value',
          key: ValueKey(value),
          style: TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      );
    });
  }
}
