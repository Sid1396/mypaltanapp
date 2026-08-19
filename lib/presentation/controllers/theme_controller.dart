import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/providers/local_storage_provider.dart';

class ThemeController extends GetxController {
  final _provider = LocalStorageProvider();
  final _isDarkMode = false.obs;

  bool get isDarkMode => _isDarkMode.value;

  @override
  void onInit() {
    super.onInit();
    _isDarkMode.value = _provider.readIsDarkMode();
  }

  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    Get.changeThemeMode(_isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
    _provider.writeIsDarkMode(_isDarkMode.value);
  }
}
