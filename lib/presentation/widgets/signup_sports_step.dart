import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/signup_controller.dart';

class SignupSportsStep extends GetView<SignupController> {
  const SignupSportsStep({super.key});

  static const _sports = [
    ('Cricket', '🏏'),
    ('Badminton', '🏸'),
    ('Pickleball', '🎾'),
    ('Football', '⚽'),
  ];

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
                  'Which sports\ndo you play? 🏅',
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
                  'Pick 1–4 sports and rank them',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w400,
                    fontSize: SizeConfig.sp(15),
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                SizedBox(height: SizeConfig.h(28)),
                Obx(() {
                  final selected = controller.selectedSports.toList();
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: SizeConfig.h(12),
                    crossAxisSpacing: SizeConfig.w(12),
                    childAspectRatio: 1.15,
                    children: [
                      for (final (name, emoji) in _sports)
                        _SportCard(
                          name: name,
                          emoji: emoji,
                          isSelected: selected.contains(name),
                          onTap: () => controller.toggleSport(name),
                        ),
                    ],
                  );
                }),
                Obx(() {
                  final selected = controller.selectedSports.toList();
                  if (selected.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: SizeConfig.h(28)),
                      Row(
                        children: [
                          Text(
                            'Your Sports',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontWeight: FontWeight.w700,
                              fontSize: SizeConfig.sp(16),
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          if (selected.length < 4)
                            Text(
                              'Add ${4 - selected.length} more',
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontWeight: FontWeight.w500,
                                fontSize: SizeConfig.sp(13),
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: SizeConfig.h(12)),
                      Wrap(
                        spacing: SizeConfig.w(8),
                        runSpacing: SizeConfig.h(8),
                        children: [
                          for (final e in selected.asMap().entries)
                            _SelectedSportChip(
                              rank: e.key + 1,
                              sport: e.value,
                              emoji: _sports
                                  .firstWhere((s) => s.$1 == e.value)
                                  .$2,
                              onRemove: () => controller.removeSport(e.value),
                            ),
                        ],
                      ),
                    ],
                  );
                }),
                SizedBox(height: SizeConfig.h(24)),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            SizeConfig.w(24),
            0,
            SizeConfig.w(24),
            SizeConfig.h(24),
          ),
          child: Obx(() {
            final hasSelection = controller.selectedSports.isNotEmpty;
            return SizedBox(
              width: double.infinity,
              height: SizeConfig.h(56),
              child: ElevatedButton(
                onPressed: hasSelection ? controller.nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withAlpha(60),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                  ),
                ),
                child: Text(
                  'Continue',
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

class _SportCard extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _SportCard({
    required this.name,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(SizeConfig.r(16)),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.primary.withAlpha(35),
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: TextStyle(fontSize: SizeConfig.sp(34))),
                  SizedBox(height: SizeConfig.h(8)),
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w700,
                      fontSize: SizeConfig.sp(14),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: SizeConfig.h(10),
                right: SizeConfig.w(10),
                child: Container(
                  width: SizeConfig.r(20),
                  height: SizeConfig.r(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: SizeConfig.r(13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedSportChip extends StatelessWidget {
  final int rank;
  final String sport;
  final String emoji;
  final VoidCallback onRemove;

  const _SelectedSportChip({
    required this.rank,
    required this.sport,
    required this.emoji,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: SizeConfig.w(4),
        top: SizeConfig.h(4),
        bottom: SizeConfig.h(4),
        right: SizeConfig.w(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(SizeConfig.r(100)),
        border: Border.all(
          color: AppColors.primary.withAlpha(80),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: SizeConfig.r(26),
            height: SizeConfig.r(26),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w700,
                  fontSize: SizeConfig.sp(12),
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: SizeConfig.w(6)),
          Text(emoji, style: TextStyle(fontSize: SizeConfig.sp(16))),
          SizedBox(width: SizeConfig.w(6)),
          Text(
            sport,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: SizeConfig.sp(14),
              color: Colors.white,
            ),
          ),
          SizedBox(width: SizeConfig.w(8)),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: SizeConfig.r(16),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
