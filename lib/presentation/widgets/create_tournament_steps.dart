import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../config/tournament_options.dart';
import '../../utils/helpers/image_prep.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/create_tournament_controller.dart';
import '../controllers/division_draft.dart';
import 'form_widgets.dart';
import 'onboarding_widgets.dart';
import 'tournament_form_widgets.dart';
import 'tournament_media_editors.dart';

String fmtDate(DateTime? d) {
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String fmtDateTime(DateTime? d) {
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${fmtDate(d)}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String rupees(int v) {
  final s = v.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

final _digits = [FilteringTextInputFormatter.digitsOnly];

/// Scrollable padded body shared by every step.
class _StepBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _StepBody({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(8), SizeConfig.w(20), SizeConfig.h(24)),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [StepIntro(title: title, subtitle: subtitle), gapH(24), ...children],
    );
  }
}

Widget stepFor(String step) {
  final c = Get.find<CreateTournamentController>();
  final d = c.divisionOf(step);
  final i = int.tryParse(step.split('@').last) ?? 0;
  if (d != null) {
    return switch (CreateTournamentController.kindOf(step)) {
      'format' => FormatStep(d: d, index: i),
      'rules' => RulesStep(d: d, index: i),
      'points' => PointsStep(d: d, index: i),
      _ => FeesStep(d: d, index: i),
    };
  }
  return switch (step) {
      'sport' => const SportStep(),
      'basics' => const BasicsStep(),
      'venue' => const VenueStep(),
      'divisions' => const DivisionsStep(),
      'payment' => const PaymentStep(),
      'extras' => const ExtrasStep(),
      'registration' => const RegistrationStep(),
      'media' => const MediaStep(),
      _ => const ReviewStep(),
    };
}

// ─── 1. Sport ───────────────────────────────────────────────────

class SportStep extends GetView<CreateTournamentController> {
  const SportStep({super.key});

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Which sport?',
      subtitle: 'Rules, scoring and stats are set up for the sport you pick.',
      children: [
        Obx(() => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: SizeConfig.h(12),
              crossAxisSpacing: SizeConfig.w(12),
              childAspectRatio: 1,
              children: [
                for (final s in Sports.all)
                  GestureDetector(
                    key: ValueKey('sport-${s.code}'),
                    onTap: controller.isEditing ? null : () => controller.selectSport(s.code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: controller.sport.value == s.code ? AppColors.primary.withAlpha(30) : AppColors.primary.withAlpha(8),
                        borderRadius: BorderRadius.circular(SizeConfig.r(18)),
                        border: Border.all(
                          color: controller.sport.value == s.code ? AppColors.primary : AppColors.primary.withAlpha(35),
                          width: controller.sport.value == s.code ? 2 : 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(s.asset, height: SizeConfig.r(64)),
                          gapH(12),
                          Text(s.label, style: tfStyle(16, weight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
              ],
            )),
        if (controller.isEditing) ...[gapH(16), const InfoNote('The sport cannot be changed after a tournament is created.')],
      ],
    );
  }
}

// ─── 2. Basics ──────────────────────────────────────────────────

class BasicsStep extends GetView<CreateTournamentController> {
  const BasicsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'The basics',
      subtitle: 'This is what captains and players see first.',
      children: [
        const FormLabel('Tournament name'),
        FieldTextInput(
          key: const ValueKey('t-name'),
          controller: c.nameCtrl,
          hint: 'e.g. Charkop Premier League 2027',
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
        ),
        gapH(20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FormLabel('Logo'),
                UploadBox(
                  key: const ValueKey('t-logo'),
                  slot: c.logo,
                  aspectRatio: 1,
                  width: SizeConfig.w(120),
                  label: 'Add logo',
                  hint: 'Square',
                  onPick: () => c.pickImage(c.logo, 'TOURNAMENT_LOGO', ImageShape.square),
                ),
              ],
            ),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FormLabel('Banner', optional: true),
                  UploadBox(
                    slot: c.banner,
                    aspectRatio: 16 / 9,
                    label: 'Add banner',
                    hint: 'Wide, 16:9',
                    icon: Icons.panorama_rounded,
                    onPick: () => c.pickImage(c.banner, 'TOURNAMENT_BANNER', ImageShape.banner),
                    onRemove: () => c.banner.file.value = null,
                  ),
                ],
              ),
            ),
          ],
        ),
        gapH(20),
        const FormLabel('Category'),
        Obx(() => ChoiceChips(options: TournamentOptions.categories, selected: c.category.value, onSelected: (v) => c.category.value = v)),
        gapH(20),
        const FormLabel('About the tournament', optional: true),
        FieldTextInput(
          controller: c.descCtrl,
          hint: 'Anything captains should know: who can play, rules, highlights...',
          maxLines: 5,
          maxLength: 1000,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}

// ─── 3. Where & when ────────────────────────────────────────────

class VenueStep extends GetView<CreateTournamentController> {
  const VenueStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'Where & when',
      subtitle: 'Where matches happen and on which dates.',
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FormLabel('Area'),
                  FieldTextInput(
                    key: const ValueKey('t-area'),
                    controller: c.areaCtrl,
                    hint: 'e.g. Charkop, Kandivali',
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
        gapH(20),
        const FormLabel('Grounds', hint: 'Add every ground or court you will use.'),
        Row(
          children: [
            Expanded(
              child: FieldTextInput(
                key: const ValueKey('t-ground'),
                controller: c.groundCtrl,
                hint: 'e.g. Nalanda Turf',
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                // Adds the ground and keeps the keyboard open for the next one.
                onEditingComplete: c.addGround,
              ),
            ),
            SizedBox(width: SizeConfig.w(8)),
            GestureDetector(
              key: const ValueKey('t-add-ground'),
              onTap: c.addGround,
              child: Container(
                width: SizeConfig.r(50),
                height: SizeConfig.r(50),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(SizeConfig.r(14))),
                child: Icon(Icons.add_rounded, color: Colors.white, size: SizeConfig.r(24)),
              ),
            ),
          ],
        ),
        Obx(() => c.grounds.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsets.only(top: SizeConfig.h(10)),
                child: Wrap(
                  spacing: SizeConfig.w(8),
                  runSpacing: SizeConfig.h(8),
                  children: [
                    for (final g in c.grounds)
                      Container(
                        padding: EdgeInsets.fromLTRB(SizeConfig.w(12), SizeConfig.h(7), SizeConfig.w(6), SizeConfig.h(7)),
                        decoration: BoxDecoration(color: Colors.white.withAlpha(12), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_rounded, size: SizeConfig.r(14), color: AppColors.primary),
                            SizedBox(width: SizeConfig.w(4)),
                            Text(g, style: tfStyle(13, weight: FontWeight.w600)),
                            GestureDetector(
                              onTap: () => c.grounds.remove(g),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(4)),
                                child: Icon(Icons.close_rounded, size: SizeConfig.r(16), color: Colors.white.withAlpha(140)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              )),
        gapH(20),
        Obx(() => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FormLabel('Starts'),
                      FieldPicker(
                        key: const ValueKey('t-start'),
                        icon: Icons.calendar_today_rounded,
                        label: c.startDate.value == null ? 'Start date' : fmtDate(c.startDate.value),
                        filled: c.startDate.value != null,
                        onTap: () async {
                          final d = await c.pickDate(context, initial: c.startDate.value, help: 'Start date');
                          if (d != null) c.setStartDate(d);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: SizeConfig.w(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FormLabel('Ends'),
                      FieldPicker(
                        icon: Icons.event_rounded,
                        label: c.endDate.value == null ? 'End date' : fmtDate(c.endDate.value),
                        filled: c.endDate.value != null,
                        onTap: () async {
                          final d = await c.pickDate(context,
                              initial: c.endDate.value ?? c.startDate.value, first: c.startDate.value, help: 'End date');
                          if (d != null) c.endDate.value = d;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            )),
        gapH(20),
        const FormLabel('Match days'),
        Obx(() => ChoiceChips(options: TournamentOptions.matchDays, selected: c.matchDays.value, onSelected: (v) => c.matchDays.value = v)),
        gapH(20),
        const FormLabel('Match timing'),
        Obx(() => ChoiceChips(options: TournamentOptions.matchTimings, selected: c.matchTiming.value, onSelected: (v) => c.matchTiming.value = v)),
      ],
    );
  }
}

// ─── 4. Divisions ───────────────────────────────────────────────

class DivisionsStep extends GetView<CreateTournamentController> {
  const DivisionsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'Divisions',
      subtitle: 'Age groups or categories each get their own teams, rules, points table and prizes.',
      children: [
        Obx(() => Column(
              children: [
                OptionCard(
                  key: const ValueKey('divisions-one'),
                  title: 'One competition',
                  subtitle: 'All teams play under the same rules. Most tournaments.',
                  icon: Icons.emoji_events_rounded,
                  selected: !c.multiDivision.value,
                  onTap: () => c.setMultiDivision(false),
                ),
                gapH(10),
                OptionCard(
                  key: const ValueKey('divisions-many'),
                  title: 'Several divisions',
                  subtitle: 'For example Under 9, Under 11 and Under 13, or Men and Women.',
                  icon: Icons.view_week_rounded,
                  selected: c.multiDivision.value,
                  onTap: () => c.setMultiDivision(true),
                ),
              ],
            )),
        Obx(() {
          if (!c.multiDivision.value) return const SizedBox.shrink();
          final used = c.divisions.map((d) => d.name.toLowerCase()).toSet();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              gapH(24),
              const FormLabel('Your divisions', hint: 'You set the format, rules and fee for each one next.'),
              for (var i = 0; i < c.divisions.length; i++) ...[
                Row(
                  children: [
                    Container(
                      width: SizeConfig.r(30),
                      height: SizeConfig.r(30),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), shape: BoxShape.circle),
                      child: Text('${i + 1}', style: tfStyle(13, weight: FontWeight.w800, color: AppColors.primary)),
                    ),
                    SizedBox(width: SizeConfig.w(10)),
                    Expanded(
                      child: FieldTextInput(
                        key: ValueKey('division-name-$i'),
                        controller: c.divisions[i].nameCtrl,
                        hint: 'e.g. Under 13',
                        maxLength: 40,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    if (c.divisions.length > 1)
                      IconButton(
                        onPressed: () => c.removeDivision(i),
                        icon: Icon(Icons.close_rounded, color: Colors.white.withAlpha(140), size: SizeConfig.r(20)),
                      ),
                  ],
                ),
                gapH(8),
              ],
              if (c.divisions.length < 8) ...[
                gapH(4),
                AddRowButton(key: const ValueKey('division-add'), icon: Icons.add_rounded, label: 'Add a division', onTap: () => c.addDivision()),
                gapH(14),
                Text('Quick add', style: tfStyle(12, color: Colors.white.withAlpha(120))),
                gapH(8),
                Wrap(
                  spacing: SizeConfig.w(6),
                  runSpacing: SizeConfig.h(6),
                  children: [
                    for (final n in TournamentOptions.divisionSuggestions.where((n) => !used.contains(n.toLowerCase())))
                      GestureDetector(
                        key: ValueKey('quick-$n'),
                        onTap: () => c.addDivision(n),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(6)),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(12), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                          child: Text('+ $n', style: tfStyle(12.5, weight: FontWeight.w600, color: Colors.white.withAlpha(210))),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        }),
      ],
    );
  }
}

// ─── 4b. Format ──────────────────────────────────────────────────

class FormatStep extends GetView<CreateTournamentController> {
  final DivisionDraft d;
  final int index;
  const FormatStep({super.key, required this.d, required this.index});

  static const _icons = {'LEAGUE': Icons.table_rows_rounded, 'KNOCKOUT': Icons.account_tree_rounded, 'LEAGUE_KNOCKOUT': Icons.grid_view_rounded};

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final isRacket = c.sport.value == 'BADMINTON' || c.sport.value == 'PICKLEBALL';
    return _StepBody(
      title: c.multiDivision.value ? '${d.name} format' : 'Format',
      subtitle: 'How teams progress and how many can take part.',
      children: [
        if (index > 0) ...[
          GestureDetector(
            key: ValueKey('copy-division-$index'),
            onTap: () => c.copyDivisionSettings(index, index - 1),
            child: Container(
              padding: EdgeInsets.all(SizeConfig.r(12)),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Icon(Icons.content_copy_rounded, size: SizeConfig.r(18), color: AppColors.primary),
                  SizedBox(width: SizeConfig.w(10)),
                  Expanded(
                    child: Text('Same as ${c.divisions[index - 1].name}? Copy its format, rules, points and fee.',
                        style: tfStyle(12.5, color: Colors.white.withAlpha(210), height: 1.35)),
                  ),
                  Text('Copy', style: tfStyle(13, weight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ),
          ),
          gapH(16),
        ],
        Obx(() => Column(
              children: [
                for (final (code, title, desc) in TournamentOptions.formats) ...[
                  OptionCard(
                    key: ValueKey('format-$code'),
                    title: title,
                    subtitle: desc,
                    icon: _icons[code]!,
                    selected: d.format.value == code,
                    onTap: () => d.format.value = code,
                  ),
                  gapH(10),
                ],
              ],
            )),
        gapH(10),
        FormCard(
          child: Obx(() => Column(
                children: [
                  NumberStepper(
                    label: isRacket ? 'Number of entries' : 'Number of teams',
                    value: d.maxTeams.value,
                    min: 2,
                    max: 128,
                    onChanged: (v) => d.maxTeams.value = v,
                  ),
                  if (d.format.value == 'LEAGUE_KNOCKOUT') ...[
                    NumberStepper(label: 'Groups', value: d.groupCount.value, min: 1, max: 16, onChanged: (v) => d.groupCount.value = v),
                    NumberStepper(
                      label: 'Qualify from each group',
                      value: d.qualifyPerGroup.value,
                      min: 1,
                      max: 8,
                      onChanged: (v) => d.qualifyPerGroup.value = v,
                    ),
                  ],
                  Divider(color: Colors.white.withAlpha(15)),
                  NumberStepper(
                    label: 'Min players per squad',
                    value: d.squadMin.value,
                    min: 1,
                    max: 40,
                    onChanged: (v) => d.squadMin.value = v,
                  ),
                  NumberStepper(
                    label: 'Max players per squad',
                    hint: 'Including substitutes',
                    value: d.squadMax.value,
                    min: 1,
                    max: 40,
                    onChanged: (v) => d.squadMax.value = v,
                  ),
                ],
              )),
        ),
        gapH(20),
        const FormLabel('Who can play', hint: 'Age on the first day of the tournament. We check it from players\' birthdates.'),
        Obx(() {
          final mode = d.maxAge.value != null ? 'UNDER' : d.minAge.value != null ? 'OVER' : 'ANY';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChoiceChips(
                options: const [('ANY', 'Any age'), ('UNDER', 'Under an age'), ('OVER', 'Over an age')],
                selected: mode,
                onSelected: (v) {
                  d.minAge.value = v == 'OVER' ? (d.minAge.value ?? 35) : null;
                  d.maxAge.value = v == 'UNDER' ? (d.maxAge.value ?? 12) : null;
                },
              ),
              if (mode != 'ANY') ...[
                gapH(8),
                FormCard(
                  child: mode == 'UNDER'
                      ? NumberStepper(
                          label: 'Under',
                          hint: 'Players must be ${d.maxAge.value} or younger',
                          value: d.maxAge.value! + 1,
                          min: 5,
                          max: 25,
                          onChanged: (v) => d.maxAge.value = v - 1,
                        )
                      : NumberStepper(
                          label: 'Age and over',
                          hint: 'Players must be ${d.minAge.value} or older',
                          value: d.minAge.value!,
                          min: 18,
                          max: 70,
                          onChanged: (v) => d.minAge.value = v,
                        ),
                ),
              ],
            ],
          );
        }),
        Obx(() {
          if (d.format.value != 'LEAGUE_KNOCKOUT') return const SizedBox.shrink();
          final per = (d.maxTeams.value / d.groupCount.value).ceil();
          return Padding(
            padding: EdgeInsets.only(top: SizeConfig.h(12)),
            child: InfoNote('${d.groupCount.value} groups of about $per teams. '
                'Top ${d.qualifyPerGroup.value} from each group go through: ${d.groupCount.value * d.qualifyPerGroup.value} teams in the knockouts.'),
          );
        }),
      ],
    );
  }
}

// ─── 5. Match rules ─────────────────────────────────────────────

class RulesStep extends GetView<CreateTournamentController> {
  final DivisionDraft d;
  final int index;
  const RulesStep({super.key, required this.d, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: c.multiDivision.value ? '${d.name} rules' : 'Match rules',
      subtitle: 'Scorers use these for every match. You can change them before the tournament starts.',
      children: switch (c.sport.value) {
        'CRICKET' => _cricket(c),
        'FOOTBALL' => _football(c),
        _ => _racket(c),
      },
    );
  }

  List<Widget> _cricket(CreateTournamentController c) => [
        const FormLabel('Match type'),
        Obx(() => ChoiceChips(options: TournamentOptions.cricketMatchTypes, selected: d.matchType.value, onSelected: d.setMatchType)),
        gapH(20),
        const FormLabel('Ball'),
        Obx(() => ChoiceChips(options: TournamentOptions.ballTypes, selected: d.ballType.value, onSelected: (v) => d.ballType.value = v)),
        gapH(20),
        const FormLabel('Pitch', optional: true),
        Obx(() => ChoiceChips(
              options: TournamentOptions.pitchTypes,
              selected: d.pitchType.value,
              allowDeselect: true,
              onSelected: (v) => d.pitchType.value = v,
            )),
        gapH(20),
        FormCard(
          child: Obx(() => Column(
                children: [
                  NumberStepper(
                    label: 'Players per side',
                    value: d.playersPerSide.value,
                    min: 2,
                    max: 11,
                    onChanged: (v) => d.playersPerSide.value = v,
                  ),
                  if (d.matchType.value != 'TEST') ...[
                    NumberStepper(label: 'Overs per innings', value: d.overs.value, min: 1, max: 90, onChanged: d.setOvers),
                    NumberStepper(
                      label: 'Overs per bowler',
                      value: d.oversPerBowler.value,
                      min: 1,
                      max: d.overs.value,
                      onChanged: (v) => d.oversPerBowler.value = v,
                    ),
                    NumberStepper(
                      label: 'Powerplay overs',
                      value: d.powerplayOvers.value,
                      min: 0,
                      max: d.overs.value,
                      onChanged: (v) => d.powerplayOvers.value = v,
                      display: (v) => v == 0 ? 'None' : '$v',
                    ),
                  ],
                  SwitchRow(
                    label: 'Last batter can bat alone',
                    hint: 'The innings continues until every batter is out.',
                    value: d.lastBatter.value,
                    onChanged: (v) => d.lastBatter.value = v,
                  ),
                ],
              )),
        ),
      ];

  List<Widget> _football(CreateTournamentController c) => [
        FormCard(
          child: Obx(() => Column(
                children: [
                  NumberStepper(
                    label: 'Players per side',
                    hint: 'Including the goalkeeper',
                    value: d.footballPlayers.value,
                    min: 3,
                    max: 11,
                    onChanged: (v) => d.footballPlayers.value = v,
                  ),
                  NumberStepper(
                    label: 'Minutes per half',
                    value: d.halfMinutes.value,
                    min: 5,
                    max: 45,
                    onChanged: (v) => d.halfMinutes.value = v,
                  ),
                  SwitchRow(
                    label: 'Rolling substitutions',
                    hint: 'Players can come off and go back on.',
                    value: d.rollingSubs.value,
                    onChanged: (v) => d.rollingSubs.value = v,
                  ),
                  SwitchRow(label: 'Extra time in knockouts', value: d.extraTime.value, onChanged: (v) => d.extraTime.value = v),
                  SwitchRow(label: 'Penalty shootout if tied', value: d.penalties.value, onChanged: (v) => d.penalties.value = v),
                ],
              )),
        ),
      ];

  List<Widget> _racket(CreateTournamentController c) => [
        const FormLabel('Event'),
        Obx(() => ChoiceChips(options: TournamentOptions.racketEvents, selected: d.racketEvent.value, onSelected: (v) => d.racketEvent.value = v)),
        gapH(20),
        const FormLabel('Match length'),
        Obx(() => ChoiceChips(
              options: const [('1', 'Best of 1'), ('3', 'Best of 3'), ('5', 'Best of 5')],
              selected: '${d.games.value}',
              onSelected: (v) => d.games.value = int.parse(v),
            )),
        if (c.sport.value == 'PICKLEBALL') ...[
          gapH(20),
          const FormLabel('Scoring'),
          Obx(() => ChoiceChips(options: TournamentOptions.pickleballScoring, selected: d.scoring.value, onSelected: (v) => d.scoring.value = v)),
        ],
        gapH(20),
        FormCard(
          child: Obx(() => Column(
                children: [
                  NumberStepper(
                    label: 'Points per game',
                    value: d.pointsPerGame.value,
                    min: 5,
                    max: 30,
                    onChanged: (v) => d.pointsPerGame.value = v,
                  ),
                  SwitchRow(
                    label: 'Win by 2 points',
                    hint: 'A game at deuce continues until one side leads by 2.',
                    value: d.winByTwo.value,
                    onChanged: (v) => d.winByTwo.value = v,
                  ),
                ],
              )),
        ),
      ];
}

// ─── 6. Points ──────────────────────────────────────────────────

class PointsStep extends GetView<CreateTournamentController> {
  final DivisionDraft d;
  final int index;
  const PointsStep({super.key, required this.d, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: c.multiDivision.value ? '${d.name} points' : 'Points table',
      subtitle: 'Points for each result in the league stage.',
      children: [
        FormCard(
          child: Obx(() => Column(
                children: [
                  NumberStepper(label: 'Win', value: d.ptsWin.value, min: 0, max: 10, onChanged: (v) => d.ptsWin.value = v),
                  NumberStepper(
                    label: c.sport.value == 'FOOTBALL' ? 'Draw' : 'Tie',
                    value: d.ptsTie.value,
                    min: 0,
                    max: 10,
                    onChanged: (v) => d.ptsTie.value = v,
                  ),
                  NumberStepper(
                    label: 'No result',
                    hint: 'Abandoned or washed out',
                    value: d.ptsNoResult.value,
                    min: 0,
                    max: 10,
                    onChanged: (v) => d.ptsNoResult.value = v,
                  ),
                  NumberStepper(label: 'Loss', value: d.ptsLoss.value, min: 0, max: 10, onChanged: (v) => d.ptsLoss.value = v),
                ],
              )),
        ),
        gapH(20),
        const FormLabel('If teams are level on points', hint: 'Checked in this order. Tap to add or remove.'),
        Obx(() {
          final options = TournamentOptions.tiebreakers[c.sport.value] ?? const [];
          return Wrap(
            spacing: SizeConfig.w(8),
            runSpacing: SizeConfig.h(8),
            children: [
              for (final (code, label) in options)
                GestureDetector(
                  onTap: () => d.toggleTiebreaker(code),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(SizeConfig.w(8), SizeConfig.h(7), SizeConfig.w(14), SizeConfig.h(7)),
                    decoration: BoxDecoration(
                      color: d.tiebreakers.contains(code) ? AppColors.primary : AppColors.primary.withAlpha(8),
                      borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                      border: Border.all(color: d.tiebreakers.contains(code) ? AppColors.primary : AppColors.primary.withAlpha(35), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: SizeConfig.r(20),
                          height: SizeConfig.r(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d.tiebreakers.contains(code) ? Colors.black.withAlpha(60) : Colors.white.withAlpha(15),
                          ),
                          child: Text(d.tiebreakers.contains(code) ? '${d.tiebreakers.indexOf(code) + 1}' : '+',
                              style: tfStyle(11, weight: FontWeight.w800)),
                        ),
                        SizedBox(width: SizeConfig.w(8)),
                        Text(label, style: tfStyle(13, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

// ─── 7. Fees & prize ────────────────────────────────────────────

class FeesStep extends GetView<CreateTournamentController> {
  final DivisionDraft d;
  final int index;
  const FeesStep({super.key, required this.d, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: c.multiDivision.value ? '${d.name} fee & prize' : 'Entry fee & prize',
      subtitle: c.multiDivision.value ? 'Leave the fee empty if this division is free.' : 'Leave the fee empty for a free tournament.',
      children: [
        const FormLabel('Entry fee per team', optional: true),
        FieldTextInput(
          key: const ValueKey('t-fee'),
          controller: d.entryFeeCtrl,
          hint: '0',
          prefixText: '₹ ',
          keyboardType: TextInputType.number,
          inputFormatters: _digits,
          maxLength: 6,
        ),
        gapH(12),
        const InfoNote(
          'Captains pay you directly by UPI. MyPaltan never holds the money. '
          'You approve a team once you have received its payment.',
          icon: Icons.shield_outlined,
        ),
        gapH(24),
        const FormLabel('Prize'),
        Obx(() => ChoiceChips(options: TournamentOptions.prizeTypes, selected: d.prizeType.value, onSelected: (v) => d.prizeType.value = v)),
        Obx(() => d.prizeType.value == 'NONE'
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsets.only(top: SizeConfig.h(12)),
                child: FieldTextInput(
                  controller: d.prizeCtrl,
                  hint: 'e.g. Winner ₹21,000 + trophy, runner-up ₹11,000',
                  maxLines: 3,
                  maxLength: 255,
                  textCapitalization: TextCapitalization.sentences,
                ),
              )),
      ],
    );
  }
}

// ─── 8. Payment ─────────────────────────────────────────────────

class PaymentStep extends GetView<CreateTournamentController> {
  const PaymentStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'How captains pay you',
      subtitle: 'Captains see these details after they register. Payments go straight to you.',
      children: [
        const FormLabel('UPI ID'),
        FieldTextInput(
          key: const ValueKey('t-upi'),
          controller: c.upiCtrl,
          hint: 'yourname@okaxis',
          keyboardType: TextInputType.emailAddress,
          maxLength: 120,
        ),
        gapH(16),
        const FormLabel('Name on the UPI account', hint: 'Must match the name captains see when they pay.'),
        FieldTextInput(
          key: const ValueKey('t-upi-name'),
          controller: c.upiNameCtrl,
          hint: 'Full name',
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
        ),
        gapH(16),
        const FormLabel('UPI QR code', optional: true),
        Row(
          children: [
            UploadBox(
              slot: c.qr,
              aspectRatio: 1,
              width: SizeConfig.w(120),
              label: 'Add QR',
              icon: Icons.qr_code_2_rounded,
              onPick: () => c.pickImage(c.qr, 'PAYMENT_QR', ImageShape.original),
              onRemove: () => c.qr.file.value = null,
            ),
            SizedBox(width: SizeConfig.w(14)),
            Expanded(
              child: Text(
                'A screenshot of your UPI QR from GPay, PhonePe or Paytm. Captains can scan it to pay.',
                style: tfStyle(12.5, color: Colors.white.withAlpha(140), height: 1.4),
              ),
            ),
          ],
        ),
        gapH(16),
        FormCard(
          child: Obx(() => SwitchRow(
                label: 'Also accept cash',
                hint: 'Captains can pay you in person instead.',
                value: c.acceptCash.value,
                onChanged: (v) => c.acceptCash.value = v,
              )),
        ),
        gapH(16),
        const FormLabel('Note for captains', optional: true),
        FieldTextInput(
          controller: c.payNoteCtrl,
          hint: 'e.g. Add your team name in the payment note',
          maxLines: 2,
          maxLength: 255,
          textCapitalization: TextCapitalization.sentences,
        ),
        gapH(16),
        const InfoNote(
          'To collect entry fees you need a verified ID. We will ask for it when you publish.',
          icon: Icons.verified_user_outlined,
        ),
      ],
    );
  }
}

// ─── 9. Extras ──────────────────────────────────────────────────

class ExtrasStep extends GetView<CreateTournamentController> {
  const ExtrasStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'Food & jerseys',
      subtitle: 'If you provide these, every player fills a short checklist before the tournament.',
      children: [
        FormCard(
          child: Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchRow(
                    label: 'Food is provided',
                    hint: 'Players pick veg, non-veg, Jain or eggetarian.',
                    value: c.foodProvided.value,
                    onChanged: (v) => c.foodProvided.value = v,
                  ),
                  if (c.foodProvided.value) ...[
                    gapH(6),
                    MultiChips(options: TournamentOptions.meals, selected: c.meals.toSet(), onToggle: c.toggleMeal),
                    gapH(10),
                  ],
                ],
              )),
        ),
        gapH(12),
        FormCard(
          child: Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchRow(
                    label: 'Jerseys are provided',
                    hint: 'Players confirm their size and printed name.',
                    value: c.jerseyProvided.value,
                    onChanged: (v) => c.jerseyProvided.value = v,
                  ),
                  if (c.jerseyProvided.value) ...[
                    gapH(6),
                    const FormLabel('Printed on the jersey'),
                    ChoiceChips(options: TournamentOptions.jerseyPrints, selected: c.jerseyPrint.value, onSelected: (v) => c.jerseyPrint.value = v),
                    gapH(16),
                    const FormLabel('Jersey cost per team', optional: true, hint: 'Part of the entry fee, not charged on top.'),
                    FieldTextInput(
                      controller: c.jerseyFeeCtrl,
                      hint: '0',
                      prefixText: '₹ ',
                      keyboardType: TextInputType.number,
                      inputFormatters: _digits,
                      maxLength: 6,
                    ),
                    gapH(12),
                  ],
                ],
              )),
        ),
      ],
    );
  }
}

// ─── 10. Registration ───────────────────────────────────────────

class RegistrationStep extends GetView<CreateTournamentController> {
  const RegistrationStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'Registration',
      subtitle: 'When captains must register their teams by.',
      children: [
        const FormLabel('Registration closes'),
        Obx(() => FieldPicker(
              key: const ValueKey('t-reg'),
              icon: Icons.schedule_rounded,
              label: c.registrationDeadline.value == null ? 'Choose date and time' : fmtDateTime(c.registrationDeadline.value),
              filled: c.registrationDeadline.value != null,
              onTap: () async {
                final d = await c.pickDateTime(context,
                    initial: c.registrationDeadline.value, last: c.startDate.value, help: 'Registration closes');
                if (d != null) c.registrationDeadline.value = d;
              },
            )),
        Obx(() {
          if (!c.hasExtras) return const SizedBox.shrink();
          final def = c.startDate.value?.subtract(const Duration(days: 3));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              gapH(20),
              FormLabel('Player checklist due',
                  optional: true,
                  hint: 'Last time players can confirm food and jersey details. '
                      '${def != null ? 'Default: ${fmtDate(def)}, 11:59 PM.' : ''}'),
              FieldPicker(
                icon: Icons.checklist_rounded,
                label: c.checklistDeadline.value == null ? '3 days before the start' : fmtDateTime(c.checklistDeadline.value),
                filled: c.checklistDeadline.value != null,
                onTap: () async {
                  final d = await c.pickDateTime(context,
                      initial: c.checklistDeadline.value ?? def, last: c.startDate.value, help: 'Checklist due');
                  if (d != null) c.checklistDeadline.value = d;
                },
              ),
            ],
          );
        }),
        gapH(20),
        const InfoNote('You approve each team yourself. Teams you have not approved by the deadline stay on the waitlist.'),
      ],
    );
  }
}

// ─── 11. Documents & sponsors ───────────────────────────────────

class MediaStep extends GetView<CreateTournamentController> {
  const MediaStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'Documents & sponsors',
      subtitle: 'Both are optional. You can add them later too.',
      children: [
        const FormLabel('Documents', hint: 'Flyer, rule book or schedule. PDF, JPG or PNG up to 10 MB.'),
        Obx(() => Column(
              children: [
                for (var i = 0; i < c.documents.length; i++) ...[
                  DocumentTile(
                    doc: c.documents[i],
                    onTap: () => showDocumentEditor(c, index: i),
                    onRemove: () => c.removeDocument(i),
                  ),
                  gapH(8),
                ],
                if (c.documents.length < 10)
                  AddRowButton(
                    key: const ValueKey('t-add-doc'),
                    icon: Icons.upload_file_rounded,
                    label: 'Add a document',
                    busy: c.docBusy.value,
                    onTap: () => showDocumentEditor(c),
                  ),
              ],
            )),
        gapH(24),
        const FormLabel('Sponsors', hint: 'Shown on the tournament page. Taps open the sponsor link.'),
        Obx(() => Column(
              children: [
                for (var i = 0; i < c.sponsors.length; i++) ...[
                  SponsorTile(
                    sponsor: c.sponsors[i],
                    onTap: () => showSponsorEditor(c, index: i),
                    onRemove: () => c.removeSponsor(i),
                  ),
                  gapH(8),
                ],
                if (c.sponsors.length < 10)
                  AddRowButton(icon: Icons.handshake_rounded, label: 'Add a sponsor', onTap: () => showSponsorEditor(c)),
              ],
            )),
      ],
    );
  }
}

// ─── 12. Review ─────────────────────────────────────────────────

class ReviewStep extends GetView<CreateTournamentController> {
  const ReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    String label(List<(String, String)> o, String code) => Sports.labelOf(o, code);
    final sport = Sports.byCode(c.sport.value);
    final isRacket = c.sport.value == 'BADMINTON' || c.sport.value == 'PICKLEBALL';

    String rulesSummary(DivisionDraft d) {
      switch (c.sport.value) {
        case 'CRICKET':
          final t = label(TournamentOptions.cricketMatchTypes, d.matchType.value);
          final o = d.matchType.value == 'TEST' ? '' : ', ${d.overs.value} overs';
          return '$t$o, ${label(TournamentOptions.ballTypes, d.ballType.value).toLowerCase()} ball, ${d.playersPerSide.value} a side';
        case 'FOOTBALL':
          return '${d.footballPlayers.value} a side, 2 × ${d.halfMinutes.value} min';
        default:
          return '${label(TournamentOptions.racketEvents, d.racketEvent.value)}, best of ${d.games.value}, ${d.pointsPerGame.value} points';
      }
    }

    List<String> divisionLines(DivisionDraft d) {
      final format = TournamentOptions.formats.where((f) => f.$1 == d.format.value).firstOrNull?.$2 ?? 'No format yet';
      final tbs = d.tiebreakers.map((t) => label(TournamentOptions.tiebreakers[c.sport.value] ?? const [], t).toLowerCase()).join(', then ');
      final age = d.maxAge.value != null ? 'Under ${d.maxAge.value! + 1}' : d.minAge.value != null ? '${d.minAge.value} and over' : null;
      return [
        [if (age != null && age.toLowerCase() != d.name.toLowerCase()) age, '$format · ${d.maxTeams.value} ${isRacket ? 'entries' : 'teams'}'].join(' · '),
        if (d.format.value == 'LEAGUE_KNOCKOUT')
          '${d.groupCount.value} ${d.groupCount.value == 1 ? 'group' : 'groups'}, top ${d.qualifyPerGroup.value} qualify',
        '${rulesSummary(d)} · squad of ${d.squadMin.value} to ${d.squadMax.value}',
        if (d.format.value != 'KNOCKOUT')
          'Win ${d.ptsWin.value} · ${c.sport.value == 'FOOTBALL' ? 'Draw' : 'Tie'} ${d.ptsTie.value} · Loss ${d.ptsLoss.value}${tbs.isEmpty ? '' : ' · then $tbs'}',
        [
          d.entryFee > 0 ? '${rupees(d.entryFee)} per team' : 'Free entry',
          if (d.prizeType.value != 'NONE')
            d.prizeCtrl.text.trim().isEmpty ? label(TournamentOptions.prizeTypes, d.prizeType.value) : d.prizeCtrl.text.trim(),
        ].join(' · '),
      ];
    }

    return Obx(() {
      c.documents.length;
      c.sponsors.length;
      final steps = c.steps;
      return ListView(
        padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(8), SizeConfig.w(20), SizeConfig.h(24)),
        children: [
          const StepIntro(title: 'Review', subtitle: 'Check everything. Tap a section to change it.'),
          gapH(20),
          ClipRRect(
            borderRadius: BorderRadius.circular(SizeConfig.r(18)),
            child: Container(
              color: const Color(0xFF1A1A1A),
              child: Column(
                children: [
                  if (c.banner.file.value != null)
                    AspectRatio(aspectRatio: 16 / 9, child: UploadedImage(c.banner.file.value!)),
                  Padding(
                    padding: EdgeInsets.all(SizeConfig.r(14)),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(SizeConfig.r(12)),
                          child: SizedBox(
                            width: SizeConfig.r(60),
                            height: SizeConfig.r(60),
                            child: c.logo.file.value != null ? UploadedImage(c.logo.file.value!) : const ColoredBox(color: Color(0xFF222222)),
                          ),
                        ),
                        SizedBox(width: SizeConfig.w(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.nameCtrl.text.trim(), style: tfStyle(18, weight: FontWeight.w900)),
                              gapH(2),
                              Text('${sport?.label ?? ''} · ${label(TournamentOptions.categories, c.category.value)}',
                                  style: tfStyle(12.5, color: Colors.white.withAlpha(140))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          gapH(12),
          _ReviewSection(step: 'basics', title: 'Basics', lines: [
            if (c.descCtrl.text.trim().isNotEmpty) c.descCtrl.text.trim() else 'No description',
          ]),
          _ReviewSection(step: 'venue', title: 'Where & when', lines: [
            '${c.areaCtrl.text.trim()}, ${c.cityCtrl.text.trim()}',
            c.grounds.join(' · '),
            c.startDate.value == c.endDate.value
                ? fmtDate(c.startDate.value)
                : '${fmtDate(c.startDate.value)} to ${fmtDate(c.endDate.value)}',
            '${label(TournamentOptions.matchDays, c.matchDays.value)} · ${label(TournamentOptions.matchTimings, c.matchTiming.value)}',
          ]),
          if (c.multiDivision.value)
            _ReviewSection(step: 'divisions', title: 'Divisions', lines: [c.divisions.map((d) => d.name).join(' · ')]),
          for (var i = 0; i < c.divisions.length; i++)
            _ReviewSection(
              step: 'format@$i',
              also: [for (final k in ['rules', 'points', 'fees']) if (steps.contains('$k@$i')) '$k@$i'],
              title: c.multiDivision.value ? c.divisions[i].name : 'Format, rules & fee',
              lines: divisionLines(c.divisions[i]),
            ),
          if (steps.contains('payment'))
            _ReviewSection(step: 'payment', title: 'Payment', lines: [
              '${c.upiCtrl.text.trim()} (${c.upiNameCtrl.text.trim()})',
              [if (c.qr.isSet) 'QR added', if (c.acceptCash.value) 'Cash accepted'].join(' · '),
            ]),
          _ReviewSection(step: 'extras', title: 'Food & jerseys', lines: [
            c.foodProvided.value
                ? 'Food: ${c.meals.map((m) => label(TournamentOptions.meals, m).toLowerCase()).join(', ')}'
                : 'No food',
            c.jerseyProvided.value
                ? 'Jerseys: ${label(TournamentOptions.jerseyPrints, c.jerseyPrint.value).toLowerCase()}'
                    '${c.jerseyFee > 0 ? ' (${rupees(c.jerseyFee)} of the fee)' : ''}'
                : 'No jerseys',
          ]),
          _ReviewSection(step: 'registration', title: 'Registration', lines: [
            'Closes ${fmtDateTime(c.registrationDeadline.value)}',
            if (c.hasExtras && c.checklistDeadline.value != null) 'Checklist due ${fmtDateTime(c.checklistDeadline.value)}',
          ]),
          _ReviewSection(step: 'media', title: 'Documents & sponsors', lines: [
            c.documents.isEmpty ? 'No documents' : '${c.documents.length} document${c.documents.length == 1 ? '' : 's'}',
            c.sponsors.isEmpty ? 'No sponsors' : c.sponsors.map((s) => s.isTitle ? '${s.name} (title)' : s.name).join(', '),
          ]),
          if (!c.isEditing) ...[
            gapH(8),
            const InfoNote('Your tournament is saved as a draft. Only you can see it until you publish.'),
          ],
        ],
      );
    });
  }
}

class _ReviewSection extends GetView<CreateTournamentController> {
  final String step;
  final List<String> also; // more steps whose errors show on this card
  final String title;
  final List<String> lines;
  const _ReviewSection({required this.step, required this.title, required this.lines, this.also = const []});

  @override
  Widget build(BuildContext context) {
    final error = [step, ...also].map(controller.validate).whereType<String>().firstOrNull;
    return Padding(
      padding: EdgeInsets.only(bottom: SizeConfig.h(10)),
      child: GestureDetector(
        onTap: () => controller.goTo(step),
        child: Container(
          padding: EdgeInsets.all(SizeConfig.r(14)),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(SizeConfig.r(14)),
            border: Border.all(color: error != null ? AppColors.negative : Colors.white.withAlpha(12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(),
                        style: tfStyle(11, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.8)),
                    gapH(6),
                    for (final l in lines.where((l) => l.isNotEmpty))
                      Padding(
                        padding: EdgeInsets.only(bottom: SizeConfig.h(2)),
                        child: Text(l, maxLines: 3, overflow: TextOverflow.ellipsis, style: tfStyle(13.5, color: Colors.white.withAlpha(220), height: 1.35)),
                      ),
                    if (error != null) ...[
                      gapH(4),
                      Text(error, style: tfStyle(12.5, weight: FontWeight.w600, color: AppColors.negative)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, size: SizeConfig.r(16), color: Colors.white.withAlpha(110)),
            ],
          ),
        ),
      ),
    );
  }
}
