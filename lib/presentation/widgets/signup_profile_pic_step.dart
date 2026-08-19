import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/signup_controller.dart';

class SignupProfilePicStep extends GetView<SignupController> {
  const SignupProfilePicStep({super.key});

  void _showPickOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SizeConfig.r(24)),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            SizeConfig.w(24),
            SizeConfig.h(12),
            SizeConfig.w(24),
            SizeConfig.h(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: SizeConfig.w(40),
                height: SizeConfig.h(4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(60),
                  borderRadius: BorderRadius.circular(SizeConfig.r(4)),
                ),
              ),
              SizedBox(height: SizeConfig.h(24)),
              _PickOption(
                icon: Icons.camera_alt_rounded,
                label: 'Take a photo',
                onTap: () {
                  Navigator.pop(context);
                  controller.pickImage(ImageSource.camera);
                },
              ),
              SizedBox(height: SizeConfig.h(12)),
              _PickOption(
                icon: Icons.photo_library_rounded,
                label: 'Choose from gallery',
                onTap: () {
                  Navigator.pop(context);
                  controller.pickImage(ImageSource.gallery);
                },
              ),
              SizedBox(height: SizeConfig.h(8)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.h(36)),

                Text(
                  'Add your\nprofile photo 📸',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                    fontSize: SizeConfig.sp(30),
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: SizeConfig.h(8)),
                Text(
                  'Show off your sports look — wear your jersey! 🏏',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(15),
                    color: Colors.white.withAlpha(140),
                  ),
                ),

                SizedBox(height: SizeConfig.h(48)),

                // ── Avatar ────────────────────────────────────
                Center(
                  child: Obx(() {
                    final path = controller.profileImagePath.value;
                    return GestureDetector(
                      onTap: () => _showPickOptions(context),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: SizeConfig.r(168),
                            height: SizeConfig.r(168),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withAlpha(12),
                              border: Border.all(
                                color: path != null
                                    ? AppColors.primary
                                    : AppColors.primary.withAlpha(50),
                                width: path != null ? 2.5 : 1.5,
                              ),
                            ),
                            child: path != null
                                ? ClipOval(
                                    child: Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sports_cricket_rounded,
                                        color: AppColors.primary.withAlpha(100),
                                        size: SizeConfig.r(54),
                                      ),
                                      SizedBox(height: SizeConfig.h(10)),
                                      Text(
                                        'Tap to add photo',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontWeight: FontWeight.w500,
                                          fontSize: SizeConfig.sp(12),
                                          color: Colors.white.withAlpha(90),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          // Camera badge
                          Container(
                            width: SizeConfig.r(44),
                            height: SizeConfig.r(44),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.secondary,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: SizeConfig.r(20),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),

              ],
            ),
          ),
        ),

        // ── Continue ──────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            SizeConfig.w(24),
            0,
            SizeConfig.w(24),
            SizeConfig.h(24),
          ),
          child: Obx(() {
            final hasPhoto = controller.profileImagePath.value != null;
            final submitting = controller.isSubmitting.value;
            return SizedBox(
              width: double.infinity,
              height: SizeConfig.h(56),
              child: ElevatedButton(
                onPressed: (hasPhoto && !submitting) ? controller.submitSignup : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withAlpha(60),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                  ),
                ),
                child: submitting
                    ? SizedBox(
                        width: SizeConfig.r(22),
                        height: SizeConfig.r(22),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Create Account',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w700,
                          fontSize: SizeConfig.sp(16),
                          color: Colors.white,
                          letterSpacing: SizeConfig.w(0.3),
                        ),
                      ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PickOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.w(16),
          vertical: SizeConfig.h(16),
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(10),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(
            color: AppColors.primary.withAlpha(40),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: SizeConfig.r(22)),
            SizedBox(width: SizeConfig.w(14)),
            Text(
              label,
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
    );
  }
}
