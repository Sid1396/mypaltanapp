import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../data/models/app_user.dart';
import '../../utils/helpers/size_config.dart';
import '../bindings/profile_binding.dart';
import '../controllers/profile_controller.dart';
import '../widgets/onboarding_widgets.dart';

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
          final user = controller.user.value;
          if (user == null && controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (user == null) {
            return _ErrorView(message: controller.errorMessage.value, onRetry: controller.fetchProfile);
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.fetchProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: SizeConfig.h(16)),
                  Text(
                    'Profile',
                    style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w900, fontSize: SizeConfig.sp(26), color: Colors.white),
                  ),
                  SizedBox(height: SizeConfig.h(20)),
                  _Header(user: user, onEdit: () => controller.edit('about'), onPhoto: () => controller.edit('photo')),
                  SizedBox(height: SizeConfig.h(24)),
                  _Section(
                    title: 'Jersey',
                    onEdit: () => controller.edit('jersey'),
                    child: Row(
                      children: [
                        JerseyPreview(
                          name: user.jerseyName ?? '',
                          number: user.jerseyNumber?.toString() ?? '',
                          width: SizeConfig.w(96),
                        ),
                        SizedBox(width: SizeConfig.w(16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow(label: 'Name', value: user.jerseyName ?? '—'),
                              _InfoRow(label: 'Number', value: user.jerseyNumber != null ? '#${user.jerseyNumber}' : '—'),
                              _InfoRow(label: 'Size', value: user.jerseySize ?? '—'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: SizeConfig.h(16)),
                  _Section(
                    title: 'Sports & roles',
                    onEdit: () => controller.edit('sports'),
                    child: Column(children: user.sports.map((s) => _SportRow(role: s)).toList()),
                  ),
                  SizedBox(height: SizeConfig.h(16)),
                  _Section(
                    title: 'Account',
                    child: Column(
                      children: [
                        _InfoRow(label: 'Mobile', value: '+91 ${user.phone}'),
                        if (user.memberSince != null) _InfoRow(label: 'Member since', value: user.memberSince!),
                      ],
                    ),
                  ),
                  SizedBox(height: SizeConfig.h(20)),
                  SizedBox(
                    width: double.infinity,
                    height: SizeConfig.h(52),
                    child: OutlinedButton.icon(
                      onPressed: controller.logout,
                      icon: const Icon(Icons.logout_rounded, color: AppColors.negative),
                      label: Text(
                        'Log out',
                        style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(15), color: AppColors.negative),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.negative.withAlpha(120)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14))),
                      ),
                    ),
                  ),
                  SizedBox(height: SizeConfig.h(120)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onPhoto;
  const _Header({required this.user, required this.onEdit, required this.onPhoto});

  static const _genders = {'MALE': 'Male', 'FEMALE': 'Female', 'UNDISCLOSED': 'Prefer not to say'};

  @override
  Widget build(BuildContext context) {
    final avatar = SizeConfig.r(84);
    return Row(
      children: [
        GestureDetector(
          onTap: onPhoto,
          child: Stack(
            children: [
              Container(
                width: avatar,
                height: avatar,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(30),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: user.photoUrl != null
                    ? Image.network(user.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials())
                    : _initials(),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.all(SizeConfig.r(5)),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Icon(Icons.camera_alt_rounded, size: SizeConfig.r(14), color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: SizeConfig.w(16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name ?? '',
                style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(20), color: Colors.white),
              ),
              SizedBox(height: SizeConfig.h(4)),
              Text(
                [if (user.age != null) '${user.age} yrs', if (user.gender != null) _genders[user.gender] ?? ''].join(' · '),
                style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(14), color: Colors.white.withAlpha(150)),
              ),
              SizedBox(height: SizeConfig.h(6)),
              GestureDetector(
                onTap: onEdit,
                child: Text(
                  'Edit details',
                  style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(13), color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _initials() => Center(
        child: Text(
          user.initials,
          style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(26), color: Colors.white),
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onEdit;
  const _Section({required this.title, required this.child, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(SizeConfig.r(16)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(SizeConfig.r(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(12), letterSpacing: 1, color: Colors.white.withAlpha(130)),
              ),
              const Spacer(),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Text(
                    'Edit',
                    style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(13), color: AppColors.primary),
                  ),
                ),
            ],
          ),
          SizedBox(height: SizeConfig.h(12)),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SizeConfig.h(4)),
      child: Row(
        children: [
          SizedBox(
            width: SizeConfig.w(100),
            child: Text(label, style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(14), color: Colors.white.withAlpha(130))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(14), color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SportRow extends StatelessWidget {
  final SportRole role;
  const _SportRow({required this.role});

  @override
  Widget build(BuildContext context) {
    final sport = Sports.byCode(role.sport);
    if (sport == null) return const SizedBox.shrink();
    final details = [
      Sports.labelOf(sport.roles, role.role),
      if (role.sport == 'CRICKET') Sports.labelOf(Sports.battingHands, role.battingHand),
      if (role.sport == 'CRICKET') Sports.labelOf(Sports.bowlingStyles, role.bowlingStyle),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SizeConfig.h(6)),
      child: Row(
        children: [
          Image.asset(sport.asset, width: SizeConfig.r(34), height: SizeConfig.r(34)),
          SizedBox(width: SizeConfig.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sport.label, style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(15), color: Colors.white)),
                Text(details, style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(13), color: Colors.white.withAlpha(140))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white.withAlpha(100), size: SizeConfig.r(40)),
            SizedBox(height: SizeConfig.h(12)),
            Text(
              message.isEmpty ? 'Could not load your profile.' : message,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(14), color: Colors.white.withAlpha(160)),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text('Retry', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(14), color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
