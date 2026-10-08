import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/onboarding_controller.dart';
import 'form_widgets.dart';
import 'onboarding_widgets.dart';

class OnboardingJerseyStep extends GetView<OnboardingController> {
  const OnboardingJerseyStep({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.h(24)),
          const StepIntro(
            title: 'Your jersey',
            subtitle: 'Shown on lineups and live scorecards. You can change it later.',
          ),
          SizedBox(height: SizeConfig.h(20)),
          Center(
            child: Obx(() => JerseyPreview(
                  name: controller.jerseyName.value,
                  number: controller.jerseyNumber.value,
                  width: SizeConfig.w(170),
                )),
          ),
          SizedBox(height: SizeConfig.h(20)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Jersey name'),
                    SizedBox(height: SizeConfig.h(8)),
                    _JerseyField(
                      controller: controller.jerseyNameController,
                      hint: 'ROHIT',
                      formatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                        LengthLimitingTextInputFormatter(12),
                        _UpperCaseFormatter(),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Number'),
                    SizedBox(height: SizeConfig.h(8)),
                    _JerseyField(
                      controller: controller.jerseyNumberController,
                      hint: '0-99',
                      keyboardType: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.h(20)),
          Row(
            children: [
              const FieldLabel('Jersey size'),
              const Spacer(),
              GestureDetector(
                onTap: () => _showSizeGuide(context),
                child: Text(
                  'Size guide',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.sp(13),
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.h(10)),
          Obx(() => Wrap(
                spacing: SizeConfig.w(8),
                runSpacing: SizeConfig.h(8),
                children: Sports.jerseySizes
                    .map((s) => PillToggle(
                          label: s,
                          selected: controller.jerseySize.value == s,
                          onTap: () => controller.jerseySize.value = s,
                        ))
                    .toList(),
              )),
          SizedBox(height: SizeConfig.h(16)),
        ],
      ),
    );
  }

  void _showSizeGuide(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(SizeConfig.w(24), SizeConfig.h(20), SizeConfig.w(24), SizeConfig.h(32)),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(SizeConfig.r(28))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Size guide',
              style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w900, fontSize: SizeConfig.sp(20), color: Colors.white),
            ),
            SizedBox(height: SizeConfig.h(4)),
            Text(
              'Measure around the fullest part of your chest.',
              style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(13), color: Colors.white.withAlpha(140)),
            ),
            SizedBox(height: SizeConfig.h(16)),
            ...Sports.jerseySizes.map((s) => Padding(
                  padding: EdgeInsets.symmetric(vertical: SizeConfig.h(6)),
                  child: Row(
                    children: [
                      SizedBox(
                        width: SizeConfig.w(60),
                        child: Text(
                          s,
                          style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(15), color: Colors.white),
                        ),
                      ),
                      Text(
                        'Chest ${Sports.jerseyChestInches[s]}"',
                        style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(15), color: Colors.white.withAlpha(170)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _JerseyField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter> formatters;
  const _JerseyField({required this.controller, required this.hint, this.keyboardType, required this.formatters});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(8),
        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
        border: Border.all(color: AppColors.primary.withAlpha(35), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(16), color: Colors.white, letterSpacing: 1),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w400, fontSize: SizeConfig.sp(14), color: Colors.white.withAlpha(80)),
          contentPadding: EdgeInsets.symmetric(horizontal: SizeConfig.w(16), vertical: SizeConfig.h(15)),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
