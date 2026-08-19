import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../controllers/counter_controller.dart';
import '../controllers/theme_controller.dart';
import '../widgets/counter_buttons.dart';
import '../widgets/counter_display.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/stats_card.dart';

class CounterPage extends GetView<CounterController> {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('GetX Counter'),
        actions: [
          Obx(() => IconButton(
                icon: Icon(
                  themeController.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: themeController.toggleTheme,
              )),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Get.toNamed(AppRoutes.history),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const CounterDisplay(),
              const SizedBox(height: 48),
              CounterButtons(
                onIncrement: controller.increment,
                onDecrement: controller.decrement,
                onReset: controller.reset,
                onCustom: () => CustomDialog.showSetValueDialog(controller),
              ),
              const Spacer(),
              Obx(() => StatsCard(
                    totalIncrements: controller.totalIncrements,
                    totalDecrements: controller.totalDecrements,
                    totalOperations: controller.totalOperations,
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
