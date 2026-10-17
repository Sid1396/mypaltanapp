import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../data/models/match.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/match_setup_controller.dart';
import '../widgets/form_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/onboarding_widgets.dart';
import '../widgets/tournament_form_widgets.dart';

class MatchSetupPage extends GetView<MatchSetupController> {
  const MatchSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Obx(() {
          final m = c.match.value;
          if (c.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          if (m == null || m.home == null || m.away == null) {
            return Center(child: EmptyCard(icon: Icons.sports_cricket, title: 'Match', message: c.error.value ?? 'Both teams must be known first.'));
          }
          return Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(onPressed: Get.back, icon: const Icon(Icons.close_rounded, color: Colors.white)),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), SizeConfig.h(24)),
                  children: [
                    StepIntro(title: 'Before the match', subtitle: '${m.home!.name} vs ${m.away!.name}'),
                    gapH(c.isCricket ? 20 : 4),
                    if (c.isCricket) ...[
                      const FormLabel('Who won the toss?'),
                      ChoiceChips(
                        options: [
                          for (final t in [m.home!, m.away!]) ('${t.entryId}', t.name)
                        ],
                        selected: '${c.tossWinner.value ?? ''}',
                        onSelected: (v) => c.tossWinner.value = int.tryParse(v),
                      ),
                      gapH(16),
                      const FormLabel('They chose to'),
                      ChoiceChips(
                        options: const [('BAT', 'Bat first'), ('BOWL', 'Bowl first')],
                        selected: c.decision.value ?? '',
                        onSelected: (v) => c.decision.value = v,
                      ),
                    ],
                    for (final t in [m.home!, m.away!]) ...[gapH(24), _XiPicker(t: t)],
                  ],
                ),
              ),
              StepBottomButton(
                key: const ValueKey('setup-save'),
                label: 'Save and start scoring',
                loading: c.isSaving.value,
                onPressed: () async {
                  // Back to the match page, which opens scoring and refreshes when scoring closes.
                  if (await c.save() && context.mounted) Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _XiPicker extends GetView<MatchSetupController> {
  final MatchTeam t;
  const _XiPicker({required this.t});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final picked = controller.picked[t.entryId] ?? const <int>{};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                '${t.name} · ${controller.isCricket ? 'Playing XI' : (controller.match.value!.isFootball ? 'Matchday squad' : 'Players')}',
                style: tfStyle(15, weight: FontWeight.w800),
              ),
            ),
            Text('${picked.length}/${controller.maxPlayers}', style: tfStyle(13, weight: FontWeight.w800, color: AppColors.primary)),
          ]),
          Text(
            controller.isCricket
                ? 'Tick who plays. Tap C for captain and WK for wicket-keeper.'
                : controller.match.value!.isFootball
                    ? 'Tick the players and substitutes for this match. Tap C for captain, GK for goalkeeper.'
                    : 'Tick who plays this match.',
            style: tfStyle(12, color: Colors.white.withAlpha(130)),
          ),
          gapH(8),
          if (t.squad.isEmpty) Text('No squad yet. The team adds players before the match.', style: tfStyle(13, color: const Color(0xFFFFB74D))),
          for (final p in t.squad)
            GestureDetector(
              key: ValueKey('xi-${t.entryId}-${p.memberId}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.toggle(t.entryId, p.memberId),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: SizeConfig.h(5)),
                child: Row(children: [
                  Icon(picked.contains(p.memberId) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: picked.contains(p.memberId) ? AppColors.primary : Colors.white.withAlpha(90)),
                  SizedBox(width: SizeConfig.w(10)),
                  Expanded(child: Text(p.name, style: tfStyle(14, weight: FontWeight.w600))),
                  _Tag(label: 'C', on: controller.captain[t.entryId] == p.memberId, onTap: () => controller.setCaptain(t.entryId, p.memberId)),
                  SizedBox(width: SizeConfig.w(6)),
                  if (!(controller.match.value?.isRacket ?? false))
                    _Tag(
                      label: controller.isCricket ? 'WK' : 'GK',
                      on: controller.keeper[t.entryId] == p.memberId,
                      onTap: () => controller.setKeeper(t.entryId, p.memberId),
                    ),
                ]),
              ),
            ),
        ],
      );
    });
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Tag({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(8), vertical: SizeConfig.h(4)),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(SizeConfig.r(6)),
            border: Border.all(color: on ? AppColors.primary : Colors.white.withAlpha(40)),
          ),
          child: Text(label, style: tfStyle(11, weight: FontWeight.w800)),
        ),
      );
}
