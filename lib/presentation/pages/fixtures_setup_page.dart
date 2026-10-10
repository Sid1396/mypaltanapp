import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../data/models/fixtures.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/fixtures_setup_controller.dart';
import '../widgets/form_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/onboarding_widgets.dart';
import '../widgets/tournament_fixtures.dart' show fixturePickerTheme, fmtFixtureDay, fmtFixtureTime;
import '../widgets/tournament_form_widgets.dart';

class FixturesSetupPage extends GetView<FixturesSetupController> {
  const FixturesSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Obx(() {
          if (c.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final f = c.fixtures.value;
          if (f == null) {
            return Center(
              child: EmptyCard(
                icon: Icons.event_busy_rounded,
                title: 'Fixtures',
                message: c.error.value ?? 'Could not load the tournament.',
                actions: [SmallButton(label: 'Try again', onTap: c.load)],
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), 0),
                child: Row(children: [
                  GestureDetector(
                    key: const ValueKey('fixtures-setup-close'),
                    onTap: Get.back,
                    child: Container(
                      width: SizeConfig.r(40),
                      height: SizeConfig.r(40),
                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
                      child: Icon(Icons.close_rounded, size: SizeConfig.r(18), color: Colors.white),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(24)),
                  children: [
                    StepIntro(
                      title: f.hasMatches ? 'Make fixtures again' : 'Make fixtures',
                      subtitle: 'Set when each division plays. MyPaltan works out who plays whom, at what time and on which pitch.',
                    ),
                    gapH(20),
                    if (f.hasMatches) ...[
                      InfoNote(f.published
                          ? 'Making them again replaces the published fixtures. Teams see the new ones after you publish again.'
                          : 'This replaces the draft fixtures, including any times you changed by hand.'),
                      gapH(16),
                    ],
                    const FormLabel('Playing hours each day', hint: 'Matches that do not fit move to the next day.'),
                    FormCard(
                      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(4)),
                      child: Column(children: [
                        _TimeRow(
                          key: const ValueKey('fixtures-day-start'),
                          label: 'First kick-off from',
                          value: c.dayStart.value,
                          onPick: (t) => c.dayStart.value = t,
                        ),
                        Divider(height: 1, color: Colors.white.withAlpha(14)),
                        _TimeRow(
                          key: const ValueKey('fixtures-day-end'),
                          label: 'Last match ends by',
                          value: c.dayEnd.value,
                          onPick: (t) => c.dayEnd.value = t,
                        ),
                      ]),
                    ),
                    for (final p in c.plans) ...[gapH(20), _DivisionPlanCard(p: p, f: f, multi: c.plans.length > 1)],
                  ],
                ),
              ),
              StepBottomButton(
                key: const ValueKey('fixtures-generate'),
                label: '${f.hasMatches ? 'Make again' : 'Make fixtures'} · ${c.included.fold<int>(0, (a, p) => a + p.matchCount)} matches',
                loading: c.isSaving.value,
                onPressed: c.generate,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onPick;
  const _TimeRow({super.key, required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: value, builder: fixturePickerTheme);
        if (t != null) onPick(t);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SizeConfig.h(12)),
        child: Row(children: [
          Expanded(child: Text(label, style: tfStyle(14, weight: FontWeight.w600))),
          Text(value.format(context), style: tfStyle(15, weight: FontWeight.w800, color: AppColors.primary)),
          SizedBox(width: SizeConfig.w(4)),
          Icon(Icons.edit_rounded, size: SizeConfig.r(14), color: Colors.white.withAlpha(110)),
        ]),
      ),
    );
  }
}

class _DivisionPlanCard extends GetView<FixturesSetupController> {
  final DivisionPlan p;
  final Fixtures f;
  final bool multi;
  const _DivisionPlanCard({required this.p, required this.f, required this.multi});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final on = p.include.value && p.canSchedule;
      final prev = controller.previousOf(p);
      return FormCard(
        key: ValueKey('fixtures-division-${p.d.id}'),
        padding: EdgeInsets.all(SizeConfig.r(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.d.name, style: tfStyle(17, weight: FontWeight.w900)),
                  Text(p.canSchedule ? p.summary : '${p.teamCount} confirmed ${p.teamCount == 1 ? 'team' : 'teams'}. Needs at least 2.',
                      style: tfStyle(12.5, color: p.canSchedule ? Colors.white.withAlpha(160) : const Color(0xFFFFB74D))),
                ]),
              ),
              if (multi && p.canSchedule) Switch(value: p.include.value, activeThumbColor: AppColors.primary, onChanged: (v) => p.include.value = v),
            ]),
            if (on) ...[
              gapH(12),
              const FormLabel('Starts'),
              if (prev != null) ...[
                ChoiceChips(
                  options: [('AFTER', 'Right after ${prev.d.name}'), ('SET', 'At a set time')],
                  selected: p.afterPrevious.value ? 'AFTER' : 'SET',
                  onSelected: (v) => p.afterPrevious.value = v == 'AFTER',
                ),
                gapH(8),
              ],
              if (prev == null || !p.afterPrevious.value)
                GestureDetector(
                  key: ValueKey('fixtures-start-${p.d.id}'),
                  onTap: () => _pickStart(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(12)),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(8),
                      borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                      border: Border.all(color: AppColors.primary.withAlpha(35), width: 1.2),
                    ),
                    child: Row(children: [
                      Icon(Icons.schedule_rounded, size: SizeConfig.r(17), color: AppColors.primary),
                      SizedBox(width: SizeConfig.w(10)),
                      Expanded(
                        child: Text('${fmtFixtureDay(p.start.value)} · ${fmtFixtureTime(p.start.value)}', style: tfStyle(14, weight: FontWeight.w700)),
                      ),
                      Icon(Icons.edit_rounded, size: SizeConfig.r(14), color: Colors.white.withAlpha(110)),
                    ]),
                  ),
                ),
              gapH(6),
              NumberStepper(
                key: ValueKey('fixtures-pitches-${p.d.id}'),
                label: 'Pitches',
                hint: 'Matches that kick off together',
                value: p.pitches.value,
                min: 1,
                max: 8,
                onChanged: (v) => p.pitches.value = v,
              ),
              NumberStepper(
                key: ValueKey('fixtures-gap-${p.d.id}'),
                label: 'Kick-off every',
                hint: 'Minutes, match length plus changeover',
                value: p.gap.value,
                min: 5,
                max: 300,
                step: 5,
                onChanged: (v) => p.gap.value = v,
              ),
              if (p.hasDraw) ...[
                gapH(10),
                FormLabel(p.isKnockout ? 'Who plays whom' : 'Groups'),
                ChoiceChips(
                  options: const [('RANDOM', 'Random draw'), ('MANUAL', 'I\'ll choose')],
                  selected: p.draw.value,
                  onSelected: (v) => p.draw.value = v,
                ),
                if (p.draw.value == 'MANUAL') ...[gapH(12), if (p.isKnockout) _SeedList(p: p) else _GroupPicker(p: p)],
              ],
            ],
          ],
        ),
      );
    });
  }

  Future<void> _pickStart(BuildContext context) async {
    final init = p.start.value;
    final d = await showDatePicker(
      context: context,
      initialDate: init.isBefore(f.startDate) || init.isAfter(f.endDate.add(const Duration(days: 1))) ? f.startDate : init,
      firstDate: f.startDate,
      lastDate: f.endDate,
      builder: fixturePickerTheme,
    );
    if (d == null || !context.mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init), builder: fixturePickerTheme);
    if (t == null) return;
    p.start.value = DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }
}

class _GroupPicker extends StatelessWidget {
  final DivisionPlan p;
  const _GroupPicker({required this.p});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Column(
          children: [
            for (final t in p.d.teams)
              Padding(
                padding: EdgeInsets.symmetric(vertical: SizeConfig.h(5)),
                child: Row(children: [
                  Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w700))),
                  for (var k = 1; k <= p.groupCount; k++)
                    GestureDetector(
                      key: ValueKey('group-${t.entryId}-$k'),
                      onTap: () => p.groups[t.entryId] = k,
                      child: Container(
                        width: SizeConfig.r(32),
                        height: SizeConfig.r(32),
                        margin: EdgeInsets.only(left: SizeConfig.w(6)),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.groups[t.entryId] == k ? AppColors.primary : Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(SizeConfig.r(8)),
                        ),
                        child: Text(groupLetters[k - 1], style: tfStyle(13, weight: FontWeight.w800)),
                      ),
                    ),
                ]),
              ),
          ],
        ));
  }
}

class _SeedList extends GetView<FixturesSetupController> {
  final DivisionPlan p;
  const _SeedList({required this.p});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final teams = {for (final t in p.d.teams) t.entryId: t};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Strongest first. Top seeds get a bye if the numbers are uneven and meet each other last.',
              style: tfStyle(12, color: Colors.white.withAlpha(140), height: 1.35)),
          gapH(8),
          for (var i = 0; i < p.seeds.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(vertical: SizeConfig.h(3)),
              child: Row(children: [
                SizedBox(width: SizeConfig.w(26), child: Text('${i + 1}', style: tfStyle(13, weight: FontWeight.w800, color: AppColors.primary))),
                Expanded(child: Text(teams[p.seeds[i]]?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w700))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: i == 0 ? null : () => controller.moveSeed(p, i, -1),
                  icon: Icon(Icons.arrow_upward_rounded, size: SizeConfig.r(18), color: i == 0 ? Colors.white24 : Colors.white),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: i == p.seeds.length - 1 ? null : () => controller.moveSeed(p, i, 1),
                  icon: Icon(Icons.arrow_downward_rounded, size: SizeConfig.r(18), color: i == p.seeds.length - 1 ? Colors.white24 : Colors.white),
                ),
              ]),
            ),
        ],
      );
    });
  }
}
