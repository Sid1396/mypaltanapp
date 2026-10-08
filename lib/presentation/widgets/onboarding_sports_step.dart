import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/onboarding_controller.dart';
import 'onboarding_widgets.dart';

class OnboardingSportsStep extends GetView<OnboardingController> {
  const OnboardingSportsStep({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.h(24)),
          const StepIntro(
            title: 'Sports & roles',
            subtitle: 'Pick the sports you play and how you play them. Captains use this for lineups.',
          ),
          SizedBox(height: SizeConfig.h(24)),
          Obx(() {
            // Read both so Obx rebuilds on selection and on role changes.
            final order = controller.sportOrder.toList();
            final drafts = controller.sportDrafts;
            return Column(
              children: Sports.all.map((sport) {
                final selected = order.contains(sport.code);
                return Padding(
                  padding: EdgeInsets.only(bottom: SizeConfig.h(12)),
                  child: _SportCard(
                    sport: sport,
                    selected: selected,
                    draft: drafts[sport.code],
                    rank: selected ? order.indexOf(sport.code) + 1 : null,
                    onToggle: () => controller.toggleSport(sport.code),
                    onRole: (r) => controller.setSportField(sport.code, role: r),
                    onHand: (h) => controller.setSportField(sport.code, battingHand: h),
                    onBowling: (b) => controller.setSportField(sport.code, bowlingStyle: b),
                  ),
                );
              }).toList(),
            );
          }),
          SizedBox(height: SizeConfig.h(8)),
        ],
      ),
    );
  }
}

class _SportCard extends StatelessWidget {
  final SportOption sport;
  final bool selected;
  final SportDraft? draft;
  final int? rank;
  final VoidCallback onToggle;
  final ValueChanged<String> onRole;
  final ValueChanged<String> onHand;
  final ValueChanged<String> onBowling;

  const _SportCard({
    required this.sport,
    required this.selected,
    required this.draft,
    required this.rank,
    required this.onToggle,
    required this.onRole,
    required this.onHand,
    required this.onBowling,
  });

  @override
  Widget build(BuildContext context) {
    final complete = selected && (draft?.isCompleteFor(sport.code) ?? false);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withAlpha(18) : AppColors.primary.withAlpha(8),
        borderRadius: BorderRadius.circular(SizeConfig.r(16)),
        border: Border.all(color: selected ? AppColors.primary : AppColors.primary.withAlpha(35), width: selected ? 2 : 1.2),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(SizeConfig.r(14)),
              child: Row(
                children: [
                  Image.asset(sport.asset, width: SizeConfig.r(40), height: SizeConfig.r(40)),
                  SizedBox(width: SizeConfig.w(14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sport.label,
                          style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(16), color: Colors.white),
                        ),
                        if (selected)
                          Text(
                            complete ? _summary() : 'Choose your role',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: SizeConfig.sp(12),
                              color: complete ? Colors.white.withAlpha(150) : AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: SizeConfig.r(26),
                    height: SizeConfig.r(26),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: selected ? AppColors.primary : Colors.white.withAlpha(60), width: 2),
                    ),
                    child: Center(
                      child: selected
                          ? Text(
                              '$rank',
                              style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(12), color: Colors.white),
                            )
                          : Icon(Icons.add_rounded, size: SizeConfig.r(16), color: Colors.white.withAlpha(120)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected)
            Padding(
              padding: EdgeInsets.fromLTRB(SizeConfig.w(14), 0, SizeConfig.w(14), SizeConfig.h(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OptionGroup(title: 'Role', options: sport.roles, value: draft?.role, onChanged: onRole),
                  if (sport.code == 'CRICKET') ...[
                    SizedBox(height: SizeConfig.h(12)),
                    _OptionGroup(title: 'Batting', options: Sports.battingHands, value: draft?.battingHand, onChanged: onHand),
                    SizedBox(height: SizeConfig.h(12)),
                    _OptionGroup(title: 'Bowling', options: Sports.bowlingStyles, value: draft?.bowlingStyle, onChanged: onBowling),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _summary() {
    final parts = [Sports.labelOf(sport.roles, draft?.role)];
    if (sport.code == 'CRICKET') {
      parts.add(Sports.labelOf(Sports.battingHands, draft?.battingHand));
      parts.add(Sports.labelOf(Sports.bowlingStyles, draft?.bowlingStyle));
    }
    return parts.join(' · ');
  }
}

class _OptionGroup extends StatelessWidget {
  final String title;
  final List<(String, String)> options;
  final String? value;
  final ValueChanged<String> onChanged;
  const _OptionGroup({required this.title, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(11), letterSpacing: 1, color: Colors.white.withAlpha(120)),
        ),
        SizedBox(height: SizeConfig.h(8)),
        Wrap(
          spacing: SizeConfig.w(8),
          runSpacing: SizeConfig.h(8),
          children: options.map((o) {
            final (code, label) = o;
            final sel = value == code;
            return GestureDetector(
              onTap: () => onChanged(code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(9)),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                  border: Border.all(color: sel ? AppColors.primary : Colors.white.withAlpha(30)),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w600, fontSize: SizeConfig.sp(13), color: Colors.white),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
