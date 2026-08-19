import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/home_controller.dart';

class HomeHeader extends GetView<HomeController> {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SizeConfig.w(20),
        SizeConfig.h(16),
        SizeConfig.w(20),
        SizeConfig.h(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(() => Text(
                  'Hello ${controller.userName.value}',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w800,
                    fontSize: SizeConfig.sp(20),
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                )),
          ),
          SizedBox(width: SizeConfig.w(12)),
          _CircleIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {},
          ),
          SizedBox(width: SizeConfig.w(10)),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: SizeConfig.r(40),
              height: SizeConfig.r(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(30),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: SizeConfig.r(22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: SizeConfig.r(40),
        height: SizeConfig.r(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(15),
        ),
        child: Icon(icon, color: Colors.white, size: SizeConfig.r(22)),
      ),
    );
  }
}
