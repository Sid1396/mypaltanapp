import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';

class AppSnackbar {
  AppSnackbar._();

  static void success(String title, String message) => _show(
        title: title,
        message: message,
        backgroundColor: AppColors.positive,
        icon: Icons.check_circle_rounded,
      );

  static void error(String title, String message) => _show(
        title: title,
        message: message,
        backgroundColor: AppColors.negative,
        icon: Icons.error_rounded,
      );

  static void warning(String title, String message) => _show(
        title: title,
        message: message,
        backgroundColor: AppColors.reset,
        icon: Icons.warning_rounded,
      );

  static void info(String title, String message) => _show(
        title: title,
        message: message,
        backgroundColor: AppColors.positive,
        icon: Icons.info_rounded,
      );

  static void _show({
    required String title,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    Get.snackbar(
      '',
      '',
      titleText: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Gilroy',
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      messageText: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Gilroy',
          fontWeight: FontWeight.w400,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
      snackPosition: SnackPosition.TOP,
      backgroundColor: backgroundColor,
      icon: Icon(icon, color: Colors.white),
      shouldIconPulse: false,
      duration: duration,
    );
  }
}
