import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/onboarding_controller.dart';
import 'onboarding_widgets.dart';

class OnboardingPhotoStep extends GetView<OnboardingController> {
  const OnboardingPhotoStep({super.key});

  @override
  Widget build(BuildContext context) {
    final size = SizeConfig.r(190);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.h(24)),
          const StepIntro(
            title: 'Add your photo',
            subtitle: 'Your team and scorers use it to recognise you. A clear face photo works best.',
          ),
          SizedBox(height: SizeConfig.h(32)),
          Center(
            child: Obx(() {
              final path = controller.photoPath.value;
              final existing = controller.existingPhotoUrl.value;
              Widget content;
              if (controller.isPreparingPhoto.value) {
                content = const Center(child: CircularProgressIndicator(color: AppColors.primary));
              } else if (path != null) {
                content = Image.file(File(path), fit: BoxFit.cover);
              } else if (existing != null) {
                content = Image.network(existing, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
              } else {
                content = _placeholder();
              }
              return GestureDetector(
                onTap: () => _chooseSource(context),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withAlpha(12),
                    border: Border.all(color: path != null ? AppColors.primary : AppColors.primary.withAlpha(60), width: 2.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: content,
                ),
              );
            }),
          ),
          SizedBox(height: SizeConfig.h(28)),
          Row(
            children: [
              Expanded(
                child: _SourceButton(
                  icon: Icons.photo_camera_rounded,
                  label: 'Camera',
                  onTap: () => controller.pickPhoto(ImageSource.camera),
                ),
              ),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(
                child: _SourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => controller.pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.h(16)),
        ],
      ),
    );
  }

  Widget _placeholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_rounded, size: SizeConfig.r(72), color: Colors.white.withAlpha(70)),
          Text(
            'Tap to add',
            style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w600, fontSize: SizeConfig.sp(13), color: Colors.white.withAlpha(110)),
          ),
        ],
      );

  void _chooseSource(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(
          SizeConfig.w(20),
          SizeConfig.h(10),
          SizeConfig.w(20),
          SizeConfig.h(16) + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(SizeConfig.r(24))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: SizeConfig.w(40),
                height: 4,
                decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            SizedBox(height: SizeConfig.h(16)),
            Text(
              'Add a photo',
              style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(18), color: Colors.white),
            ),
            SizedBox(height: SizeConfig.h(12)),
            _SheetOption(
              icon: Icons.photo_camera_rounded,
              title: 'Take a photo',
              subtitle: 'Use your camera',
              onTap: () {
                Get.back();
                controller.pickPhoto(ImageSource.camera);
              },
            ),
            SizedBox(height: SizeConfig.h(8)),
            _SheetOption(
              icon: Icons.photo_library_rounded,
              title: 'Choose from gallery',
              subtitle: 'Pick an existing photo',
              onTap: () {
                Get.back();
                controller.pickPhoto(ImageSource.gallery);
              },
            ),
            SizedBox(height: SizeConfig.h(12)),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: Get.back,
                child: Text(
                  'Cancel',
                  style:
                      TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w600, fontSize: SizeConfig.sp(15), color: Colors.white.withAlpha(160)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(12)),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
        ),
        child: Row(
          children: [
            Container(
              width: SizeConfig.r(42),
              height: SizeConfig.r(42),
              decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
              child: Icon(icon, color: AppColors.primary, size: SizeConfig.r(22)),
            ),
            SizedBox(width: SizeConfig.w(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(15), color: Colors.white)),
                  Text(subtitle, style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(12), color: Colors.white.withAlpha(130))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(90)),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: SizeConfig.h(16)),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(color: AppColors.primary.withAlpha(50), width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: SizeConfig.r(26)),
            SizedBox(height: SizeConfig.h(6)),
            Text(label, style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(14), color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
