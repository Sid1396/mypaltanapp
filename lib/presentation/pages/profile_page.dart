import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../bindings/profile_binding.dart';
import '../controllers/profile_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    ProfileBinding().dependencies();
    final controller = Get.find<ProfileController>();

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (controller.errorMessage.value.isNotEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(32)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white.withAlpha(100),
                      size: SizeConfig.r(40),
                    ),
                    SizedBox(height: SizeConfig.h(12)),
                    Text(
                      controller.errorMessage.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w500,
                        fontSize: SizeConfig.sp(14),
                        color: Colors.white.withAlpha(160),
                      ),
                    ),
                    SizedBox(height: SizeConfig.h(16)),
                    TextButton(
                      onPressed: controller.fetchProfile,
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w700,
                          fontSize: SizeConfig.sp(14),
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final user = controller.profile.value;
          if (user == null) return const SizedBox.shrink();

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.h(16)),
                Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                    fontSize: SizeConfig.sp(26),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: SizeConfig.h(24)),

                // ── Avatar + name + phone ──────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: SizeConfig.r(96),
                        height: SizeConfig.r(96),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withAlpha(20),
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: user.photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  user.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.person_rounded,
                                    color: AppColors.primary,
                                    size: SizeConfig.r(44),
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                                size: SizeConfig.r(44),
                              ),
                      ),
                      SizedBox(height: SizeConfig.h(14)),
                      Text(
                        user.name,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w800,
                          fontSize: SizeConfig.sp(20),
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: SizeConfig.h(4)),
                      Text(
                        '+91 ${controller.phone}',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w400,
                          fontSize: SizeConfig.sp(14),
                          color: Colors.white.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: SizeConfig.h(32)),

                _InfoRow(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  value: [user.area, user.city, user.state]
                      .where((s) => s.isNotEmpty)
                      .join(', '),
                ),
                _InfoRow(
                  icon: Icons.emoji_events_rounded,
                  label: 'Skill Level',
                  value: user.skillLevel,
                ),
                if (user.age != null)
                  _InfoRow(
                    icon: Icons.cake_rounded,
                    label: 'Age',
                    value: '${user.age} years',
                  ),

                SizedBox(height: SizeConfig.h(24)),
                Text(
                  'Sports',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: SizeConfig.sp(15),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: SizeConfig.h(12)),
                Wrap(
                  spacing: SizeConfig.w(8),
                  runSpacing: SizeConfig.h(8),
                  children: user.sports
                      .map((s) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: SizeConfig.w(14),
                              vertical: SizeConfig.h(8),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                              border: Border.all(color: AppColors.primary.withAlpha(80)),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w600,
                                fontSize: SizeConfig.sp(13),
                                color: AppColors.primary,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                SizedBox(height: SizeConfig.h(40)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: SizeConfig.h(14)),
      child: Row(
        children: [
          Container(
            width: SizeConfig.r(40),
            height: SizeConfig.r(40),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(SizeConfig.r(12)),
            ),
            child: Icon(icon, color: AppColors.primary, size: SizeConfig.r(20)),
          ),
          SizedBox(width: SizeConfig.w(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(12),
                    color: Colors.white.withAlpha(120),
                  ),
                ),
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.sp(15),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
