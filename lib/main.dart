import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'data/providers/local_storage_provider.dart';
import 'presentation/bindings/initial_binding.dart';
import 'presentation/controllers/theme_controller.dart';
import 'utils/helpers/size_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.put(ThemeController(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = LocalStorageProvider().readIsDarkMode();
    return GetMaterialApp(
      title: 'GetX Counter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
      builder: (context, child) {
        SizeConfig.init(context);
        return child!;
      },
    );
  }
}
