import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import 'home_page.dart';
import 'mypaltan_page.dart';
import 'profile_page.dart';
import 'turf_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  static const _pages = [
    HomePage(),
    MyPaltanPage(),
    TurfPage(),
    ProfilePage(),
  ];

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.groups_rounded, label: 'MyPaltan'),
    (icon: Icons.grass_rounded, label: 'Turf'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: EdgeInsets.fromLTRB(
            SizeConfig.w(16),
            0,
            SizeConfig.w(16),
            SizeConfig.h(10),
          ),
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(8)),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(SizeConfig.r(24)),
            border: Border.all(color: Colors.white.withAlpha(15), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final selected = i == _currentIndex;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _currentIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.w(14),
                    vertical: SizeConfig.h(8),
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withAlpha(25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(SizeConfig.r(16)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: SizeConfig.r(22),
                        color: selected ? AppColors.primary : Colors.white.withAlpha(120),
                      ),
                      SizedBox(height: SizeConfig.h(4)),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: SizeConfig.sp(11),
                          color: selected ? AppColors.primary : Colors.white.withAlpha(120),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
