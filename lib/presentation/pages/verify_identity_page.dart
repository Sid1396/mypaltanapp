import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/tournament_options.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/verify_identity_controller.dart';
import '../widgets/form_widgets.dart';
import '../widgets/onboarding_widgets.dart';
import '../widgets/tournament_form_widgets.dart';

class VerifyIdentityPage extends GetView<VerifyIdentityController> {
  const VerifyIdentityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Obx(() {
          final s = controller.status.value;
          final showForm = !controller.isLoading.value && s != null && (s.status == 'NOT_SUBMITTED' || s.status == 'REJECTED');
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(8)),
                child: Row(
                  children: [
                    GestureDetector(
                      key: const ValueKey('verify-back'),
                      onTap: Get.back,
                      child: Container(
                        width: SizeConfig.r(40),
                        height: SizeConfig.r(40),
                        decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: SizeConfig.r(18), color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : s == null
                        ? Center(child: SmallTextButton(label: 'Try again', onTap: controller.load))
                        : showForm
                            ? const _Form()
                            : _StatusView(status: s.status, submittedAt: s.submittedAt),
              ),
              if (showForm)
                StepBottomButton(
                  key: const ValueKey('verify-submit'),
                  label: 'Submit for review',
                  loading: controller.isSubmitting.value,
                  onPressed: controller.submit,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class SmallTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SmallTextButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: onTap, child: Text(label, style: tfStyle(14, weight: FontWeight.w700, color: AppColors.primary)));
}

class _StatusView extends StatelessWidget {
  final String status;
  final String? submittedAt;
  const _StatusView({required this.status, this.submittedAt});

  @override
  Widget build(BuildContext context) {
    final verified = status == 'VERIFIED';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: SizeConfig.r(88),
            height: SizeConfig.r(88),
            decoration: BoxDecoration(
              color: (verified ? AppColors.positive : AppColors.primary).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(verified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                size: SizeConfig.r(44), color: verified ? AppColors.positive : AppColors.primary),
          ),
          gapH(24),
          Text(verified ? "You're verified" : 'Under review', textAlign: TextAlign.center, style: tfStyle(26, weight: FontWeight.w900)),
          gapH(10),
          Text(
            verified
                ? 'You can publish tournaments and collect entry fees. Players see a verified badge next to your name.'
                : 'The MyPaltan team is checking your ID. This usually takes less than 24 hours. We will notify you when it is done.',
            textAlign: TextAlign.center,
            style: tfStyle(14.5, color: Colors.white.withAlpha(160), height: 1.5),
          ),
          if (!verified && submittedAt != null) ...[
            gapH(12),
            Text('Submitted $submittedAt', style: tfStyle(12.5, color: Colors.white.withAlpha(110))),
          ],
          gapH(60),
        ],
      ),
    );
  }
}

class _Form extends GetView<VerifyIdentityController> {
  const _Form();

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final rejected = c.status.value?.status == 'REJECTED';
    return ListView(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(8), SizeConfig.w(20), SizeConfig.h(24)),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const StepIntro(
          title: 'Verify your identity',
          subtitle: 'Organisers verify once so players know who they are paying. Only the MyPaltan team sees your ID.',
        ),
        if (rejected) ...[
          gapH(16),
          InfoNote(
            'Your last submission was not approved${c.status.value?.rejectReason != null ? ': ${c.status.value!.rejectReason}' : '.'} Please try again.',
            icon: Icons.error_outline_rounded,
          ),
        ],
        gapH(24),
        const FormLabel('ID type'),
        Obx(() => ChoiceChips(options: TournamentOptions.idTypes, selected: c.idType.value, onSelected: (v) => c.idType.value = v)),
        gapH(20),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FormLabel('Name on the ID'),
                  FieldTextInput(controller: c.nameCtrl, hint: 'Full name', maxLength: 100, textCapitalization: TextCapitalization.words),
                ],
              ),
            ),
            SizedBox(width: SizeConfig.w(10)),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FormLabel('Last 4 of ID no.'),
                  FieldTextInput(
                    key: const ValueKey('verify-last4'),
                    controller: c.last4Ctrl,
                    hint: 'e.g. 4F7K',
                    maxLength: 4,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ),
            ),
          ],
        ),
        gapH(20),
        Obx(() => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _PhotoBox(part: 'front', label: 'Front of ID', path: c.front.value, icon: Icons.badge_rounded)),
                if (c.needsBack) ...[
                  SizedBox(width: SizeConfig.w(10)),
                  Expanded(child: _PhotoBox(part: 'back', label: 'Back of ID', path: c.back.value, icon: Icons.flip_rounded)),
                ],
              ],
            )),
        gapH(12),
        Obx(() => _PhotoBox(part: 'selfie', label: 'Selfie', hint: 'Face the camera in good light', path: c.selfie.value, icon: Icons.face_rounded, selfie: true)),
        gapH(16),
        const InfoNote(
          'For Aadhaar, use a masked Aadhaar that shows only the last 4 digits. Your ID is stored securely and never shown to other users.',
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}

class _PhotoBox extends GetView<VerifyIdentityController> {
  final String part;
  final String label;
  final String? hint;
  final String? path;
  final IconData icon;
  final bool selfie;
  const _PhotoBox({required this.part, required this.label, required this.path, required this.icon, this.hint, this.selfie = false});

  void _choose() {
    if (selfie) {
      controller.pick(part, ImageSource.camera);
      return;
    }
    Get.bottomSheet(SheetFrame(title: label, children: [
      _SourceRow(icon: Icons.photo_camera_rounded, label: 'Take a photo', onTap: () {
        Get.back();
        controller.pick(part, ImageSource.camera);
      }),
      gapH(10),
      _SourceRow(icon: Icons.photo_library_rounded, label: 'Choose from gallery', onTap: () {
        Get.back();
        controller.pick(part, ImageSource.gallery);
      }),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = controller.preparing.value == part;
      return GestureDetector(
        key: ValueKey('verify-$part'),
        onTap: busy ? null : _choose,
        child: AspectRatio(
          aspectRatio: selfie ? 2.2 : 1.45,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(8),
              borderRadius: BorderRadius.circular(SizeConfig.r(14)),
              border: Border.all(color: path != null ? AppColors.primary : AppColors.primary.withAlpha(50), width: path != null ? 1.8 : 1.2),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (path != null)
                  Image.file(File(path!), fit: BoxFit.cover)
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: AppColors.primary, size: SizeConfig.r(28)),
                      gapH(6),
                      Text(label, style: tfStyle(13, weight: FontWeight.w700)),
                      if (hint != null) Text(hint!, style: tfStyle(11.5, color: Colors.white.withAlpha(110))),
                    ],
                  ),
                if (busy)
                  Container(color: Colors.black.withAlpha(150), child: const Center(child: CircularProgressIndicator(color: AppColors.primary))),
                if (path != null && !busy)
                  Positioned(
                    left: SizeConfig.r(8),
                    bottom: SizeConfig.r(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(8), vertical: SizeConfig.h(4)),
                      decoration: BoxDecoration(color: Colors.black.withAlpha(170), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                      child: Text('$label · Retake', style: tfStyle(11, weight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _SourceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(14)),
        decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(SizeConfig.r(14))),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: SizeConfig.r(22)),
            SizedBox(width: SizeConfig.w(12)),
            Text(label, style: tfStyle(15, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
