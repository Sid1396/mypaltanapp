import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/sports.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/onboarding_controller.dart';
import 'form_widgets.dart';
import 'onboarding_widgets.dart';

class OnboardingAboutStep extends GetView<OnboardingController> {
  const OnboardingAboutStep({super.key});

  static const _genderIcons = {
    'MALE': Icons.man_rounded,
    'FEMALE': Icons.woman_rounded,
    'UNDISCLOSED': Icons.shield_rounded,
  };

  static const _foods = [
    ('VEG', 'Veg', Icons.eco_rounded),
    ('NON_VEG', 'Non-veg', Icons.set_meal_rounded),
    ('EGG', 'Eggetarian', Icons.egg_rounded),
    ('JAIN', 'Jain', Icons.spa_rounded),
  ];

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.h(24)),
          const StepIntro(
            title: 'About you',
            subtitle: 'Your name appears on team lists, scorecards and leaderboards.',
          ),
          SizedBox(height: SizeConfig.h(28)),
          const FieldLabel('Full name'),
          SizedBox(height: SizeConfig.h(8)),
          FieldTextInput(
            controller: controller.nameController,
            hint: 'e.g. Rohit Sharma',
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: SizeConfig.h(20)),
          const FieldLabel('Date of birth'),
          SizedBox(height: SizeConfig.h(8)),
          Obx(() {
            final d = controller.birthdate.value;
            return FieldPicker(
              icon: Icons.calendar_today_rounded,
              label: d == null
                  ? 'Select your date of birth'
                  : '${d.day} ${_months[d.month - 1]} ${d.year}  ·  ${OnboardingController.ageOf(d)} yrs',
              filled: d != null,
              onTap: () => controller.pickBirthdate(context),
            );
          }),
          SizedBox(height: SizeConfig.h(6)),
          Text(
            'You must be 13 or older. Only your age is shown to others.',
            style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(12), color: Colors.white.withAlpha(110)),
          ),
          SizedBox(height: SizeConfig.h(20)),
          const FieldLabel('Gender'),
          SizedBox(height: SizeConfig.h(8)),
          Obx(() => Column(
                children: Sports.genders.map((g) {
                  final (code, label) = g;
                  return Padding(
                    padding: EdgeInsets.only(bottom: SizeConfig.h(10)),
                    child: ChoiceCard(
                      label: label,
                      icon: _genderIcons[code]!,
                      selected: controller.gender.value == code,
                      onTap: () => controller.gender.value = code,
                    ),
                  );
                }).toList(),
              )),
          SizedBox(height: SizeConfig.h(10)),
          const FieldLabel('Current address pincode'),
          SizedBox(height: SizeConfig.h(8)),
          FieldTextInput(
            controller: controller.pincodeController,
            hint: 'e.g. 400067',
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          Obx(() {
            final u = controller.savedLocation;
            return Text(
              u ?? 'Used to show where you rank in your area. Only your area is shown to others, never the pincode.',
              style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(12), color: Colors.white.withAlpha(u == null ? 110 : 170)),
            );
          }),
          SizedBox(height: SizeConfig.h(20)),
          const FieldLabel('Food preference'),
          SizedBox(height: SizeConfig.h(8)),
          Obx(() => Column(
                children: _foods.map((f) {
                  final (code, label, icon) = f;
                  return Padding(
                    padding: EdgeInsets.only(bottom: SizeConfig.h(10)),
                    child: ChoiceCard(
                      label: label,
                      icon: icon,
                      selected: controller.foodPref.value == code,
                      onTap: () => controller.foodPref.value = code,
                    ),
                  );
                }).toList(),
              )),
          SizedBox(height: SizeConfig.h(16)),
        ],
      ),
    );
  }
}
