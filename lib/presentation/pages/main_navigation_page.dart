import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../data/services/deep_link_service.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_nav_controller.dart';
import '../widgets/home_widgets.dart';
import 'home_page.dart';
import 'my_teams_page.dart';
import 'profile_page.dart';
import 'tournaments_page.dart';

class MainNavigationPage extends StatelessWidget {
  const MainNavigationPage({super.key});

  // Index 2 is the Create button, so its slot holds an empty placeholder.
  static const _pages = [HomePage(), TournamentsPage(), SizedBox.shrink(), MyTeamsPage(), ProfilePage()];

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.emoji_events_rounded, label: 'Tournaments'),
    (icon: Icons.add_rounded, label: 'Create'),
    (icon: Icons.shield_rounded, label: 'My Teams'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = Get.put(MainNavController());
    Get.put(HomeController());
    // Home is ready, so a tournament link tapped before login can open now.
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<DeepLinkService>().markReady());

    return Scaffold(
      backgroundColor: AppColors.secondary,
      extendBody: true,
      body: Obx(() => IndexedStack(index: nav.index.value, children: _pages)),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: EdgeInsets.fromLTRB(SizeConfig.w(12), 0, SizeConfig.w(12), SizeConfig.h(8)),
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(6), horizontal: SizeConfig.w(4)),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(SizeConfig.r(24)),
            border: Border.all(color: Colors.white.withAlpha(15)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(120), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Obx(() => Row(
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  if (i == 2) {
                    return Expanded(
                      child: GestureDetector(
                        key: const ValueKey('nav-create'),
                        onTap: showCreateSheet,
                        child: Center(
                          heightFactor: 1,
                          child: Container(
                            width: SizeConfig.r(50),
                            height: SizeConfig.r(50),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(110), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: Icon(Icons.add_rounded, color: Colors.white, size: SizeConfig.r(28)),
                          ),
                        ),
                      ),
                    );
                  }
                  final selected = nav.index.value == i;
                  final color = selected ? AppColors.primary : Colors.white.withAlpha(120);
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => nav.go(i),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: SizeConfig.h(6)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tab.icon, size: SizeConfig.r(22), color: color),
                            SizedBox(height: SizeConfig.h(4)),
                            Text(
                              tab.label,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: SizeConfig.sp(10.5),
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              )),
        ),
      ),
    );
  }
}
