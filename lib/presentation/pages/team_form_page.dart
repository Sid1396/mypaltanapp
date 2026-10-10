import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/team_controllers.dart';
import '../widgets/form_widgets.dart';
import '../widgets/onboarding_widgets.dart';
import '../widgets/tournament_form_widgets.dart';

class TeamFormPage extends GetView<TeamFormController> {
  const TeamFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), 0),
              child: Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('team-form-close'),
                    onTap: Get.back,
                    child: Container(
                      width: SizeConfig.r(40),
                      height: SizeConfig.r(40),
                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
                      child: Icon(Icons.close_rounded, size: SizeConfig.r(18), color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(24)),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  StepIntro(
                    title: c.isEditing ? 'Edit team' : 'Create a team',
                    subtitle: c.isEditing ? 'Changes show everywhere your team appears.' : 'You become the captain. Share one link and your players join.',
                  ),
                  gapH(24),
                  if (!c.isEditing) ...[
                    const FormLabel('Sport'),
                    Obx(() => ChoiceChips(
                          options: [for (final s in Sports.all) (s.code, s.label)],
                          selected: c.sport.value,
                          onSelected: (v) => c.sport.value = v,
                        )),
                    gapH(20),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FormLabel('Logo'),
                          UploadBox(
                            key: const ValueKey('team-logo'),
                            slot: c.logo,
                            aspectRatio: 1,
                            width: SizeConfig.w(110),
                            label: 'Add logo',
                            hint: 'Square',
                            icon: Icons.shield_rounded,
                            onPick: c.pickLogo,
                          ),
                        ],
                      ),
                      SizedBox(width: SizeConfig.w(14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FormLabel('Team name'),
                            FieldTextInput(
                              key: const ValueKey('team-name'),
                              controller: c.nameCtrl,
                              hint: 'e.g. Borivali Tigers',
                              maxLength: 40,
                              textCapitalization: TextCapitalization.words,
                            ),
                            gapH(12),
                            const FormLabel('Short name', hint: 'For scorecards, 2-4 letters'),
                            Focus(
                              onFocusChange: (f) => f ? c.onShortTyped() : null,
                              child: FieldTextInput(
                                key: const ValueKey('team-short'),
                                controller: c.shortCtrl,
                                hint: 'BTG',
                                maxLength: 4,
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  gapH(20),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FormLabel('Area'),
                            FieldTextInput(
                              key: const ValueKey('team-area'),
                              controller: c.areaCtrl,
                              hint: 'e.g. Borivali West',
                              maxLength: 100,
                              textCapitalization: TextCapitalization.words,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: SizeConfig.w(10)),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FormLabel('City'),
                            FieldTextInput(controller: c.cityCtrl, hint: 'City', maxLength: 50, textCapitalization: TextCapitalization.words),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!c.isEditing) ...[
                    gapH(20),
                    const FormLabel('Are you playing in this team?'),
                    Obx(() => Column(children: [
                          OptionCard(
                            key: const ValueKey('team-role-captain'),
                            title: "Yes, I'm the captain",
                            subtitle: 'You play and run the team. You are counted in the squad.',
                            icon: Icons.sports_rounded,
                            selected: c.playing.value == true,
                            onTap: () => c.playing.value = true,
                          ),
                          gapH(10),
                          OptionCard(
                            key: const ValueKey('team-role-coach'),
                            title: "No, I'm the coach or manager",
                            subtitle: 'You run the team but do not play. You can pick a captain from the squad.',
                            icon: Icons.assignment_ind_rounded,
                            selected: c.playing.value == false,
                            onTap: () => c.playing.value = false,
                          ),
                        ])),
                    gapH(20),
                    const InfoNote('Coaching a kids\' team? After creating it you can add players under 13 yourself. They do not need the app.',
                        icon: Icons.child_care_rounded),
                  ],
                ],
              ),
            ),
            Obx(() => StepBottomButton(
                  key: const ValueKey('team-save'),
                  label: c.isEditing ? 'Save changes' : 'Create team',
                  loading: c.isSaving.value,
                  onPressed: c.save,
                )),
          ],
        ),
      ),
    );
  }
}
