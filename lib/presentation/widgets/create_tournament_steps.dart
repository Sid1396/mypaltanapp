import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../config/tournament_options.dart';
import '../../utils/helpers/image_prep.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/create_tournament_controller.dart';
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

Widget stepFor(String step) => switch (step) {
      'sport' => const SportStep(),
      'basics' => const BasicsStep(),
      'venue' => const VenueStep(),
      'format' => const FormatStep(),
      'rules' => const RulesStep(),
      'points' => const PointsStep(),
      'fees' => const FeesStep(),
      'payment' => const PaymentStep(),
      'extras' => const ExtrasStep(),
      'registration' => const RegistrationStep(),
      'media' => const MediaStep(),
      _ => const ReviewStep(),
    };

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

// ─── 4. Format ──────────────────────────────────────────────────

class FormatStep extends GetView<CreateTournamentController> {
  const FormatStep({super.key});

  static const _icons = {'LEAGUE': Icons.table_rows_rounded, 'KNOCKOUT': Icons.account_tree_rounded, 'LEAGUE_KNOCKOUT': Icons.grid_view_rounded};

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final isRacket = c.sport.value == 'BADMINTON' || c.sport.value == 'PICKLEBALL';
    return _StepBody(
      title: 'Format',
      subtitle: 'How teams progress and how many can take part.',
      children: [
        Obx(() => Column(
              children: [
                for (final (code, title, desc) in TournamentOptions.formats) ...[
                  OptionCard(
                    key: ValueKey('format-$code'),
                    title: title,
                    subtitle: desc,
                    icon: _icons[code]!,
                    selected: c.format.value == code,
                    onTap: () => c.format.value = code,
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
                    value: c.maxTeams.value,
                    min: 2,
                    max: 128,
                    onChanged: (v) => c.maxTeams.value = v,
                  ),
                  if (c.format.value == 'LEAGUE_KNOCKOUT') ...[
                    NumberStepper(label: 'Groups', value: c.groupCount.value, min: 1, max: 16, onChanged: (v) => c.groupCount.value = v),
                    NumberStepper(
                      label: 'Qualify from each group',
                      value: c.qualifyPerGroup.value,
                      min: 1,
                      max: 8,
                      onChanged: (v) => c.qualifyPerGroup.value = v,
                    ),
                  ],
                  Divider(color: Colors.white.withAlpha(15)),
                  NumberStepper(
                    label: 'Min players per squad',
                    value: c.squadMin.value,
                    min: 1,
                    max: 40,
                    onChanged: (v) => c.squadMin.value = v,
                  ),
                  NumberStepper(
                    label: 'Max players per squad',
                    hint: 'Including substitutes',
                    value: c.squadMax.value,
                    min: 1,
                    max: 40,
                    onChanged: (v) => c.squadMax.value = v,
                  ),
                ],
              )),
        ),
        Obx(() {
          if (c.format.value != 'LEAGUE_KNOCKOUT') return const SizedBox.shrink();
          final per = (c.maxTeams.value / c.groupCount.value).ceil();
          return Padding(
            padding: EdgeInsets.only(top: SizeConfig.h(12)),
            child: InfoNote('${c.groupCount.value} groups of about $per teams. '
                'Top ${c.qualifyPerGroup.value} from each group go through: ${c.groupCount.value * c.qualifyPerGroup.value} teams in the knockouts.'),
          );
        }),
      ],
    );
  }
}

// ─── 5. Match rules ─────────────────────────────────────────────

class RulesStep extends GetView<CreateTournamentController> {
  const RulesStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'Match rules',
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
        Obx(() => ChoiceChips(options: TournamentOptions.cricketMatchTypes, selected: c.matchType.value, onSelected: c.setMatchType)),
        gapH(20),
        const FormLabel('Ball'),
        Obx(() => ChoiceChips(options: TournamentOptions.ballTypes, selected: c.ballType.value, onSelected: (v) => c.ballType.value = v)),
        gapH(20),
        const FormLabel('Pitch', optional: true),
        Obx(() => ChoiceChips(
              options: TournamentOptions.pitchTypes,
              selected: c.pitchType.value,
              allowDeselect: true,
              onSelected: (v) => c.pitchType.value = v,
            )),
        gapH(20),
        FormCard(
          child: Obx(() => Column(
                children: [
                  NumberStepper(
                    label: 'Players per side',
                    value: c.playersPerSide.value,
                    min: 2,
                    max: 11,
                    onChanged: (v) => c.playersPerSide.value = v,
                  ),
                  if (c.matchType.value != 'TEST') ...[
                    NumberStepper(label: 'Overs per innings', value: c.overs.value, min: 1, max: 90, onChanged: c.setOvers),
                    NumberStepper(
                      label: 'Overs per bowler',
                      value: c.oversPerBowler.value,
                      min: 1,
                      max: c.overs.value,
                      onChanged: (v) => c.oversPerBowler.value = v,
                    ),
                    NumberStepper(
                      label: 'Powerplay overs',
                      value: c.powerplayOvers.value,
                      min: 0,
                      max: c.overs.value,
                      onChanged: (v) => c.powerplayOvers.value = v,
                      display: (v) => v == 0 ? 'None' : '$v',
                    ),
                  ],
                  SwitchRow(
                    label: 'Last batter can bat alone',
                    hint: 'The innings continues until every batter is out.',
                    value: c.lastBatter.value,
                    onChanged: (v) => c.lastBatter.value = v,
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
                    value: c.footballPlayers.value,
                    min: 3,
                    max: 11,
                    onChanged: (v) => c.footballPlayers.value = v,
                  ),
                  NumberStepper(
                    label: 'Minutes per half',
                    value: c.halfMinutes.value,
                    min: 5,
                    max: 45,
                    onChanged: (v) => c.halfMinutes.value = v,
                  ),
                  SwitchRow(
                    label: 'Rolling substitutions',
                    hint: 'Players can come off and go back on.',
                    value: c.rollingSubs.value,
                    onChanged: (v) => c.rollingSubs.value = v,
                  ),
                  SwitchRow(label: 'Extra time in knockouts', value: c.extraTime.value, onChanged: (v) => c.extraTime.value = v),
                  SwitchRow(label: 'Penalty shootout if tied', value: c.penalties.value, onChanged: (v) => c.penalties.value = v),
                ],
              )),
        ),
      ];

  List<Widget> _racket(CreateTournamentController c) => [
        const FormLabel('Event'),
        Obx(() => ChoiceChips(options: TournamentOptions.racketEvents, selected: c.racketEvent.value, onSelected: (v) => c.racketEvent.value = v)),
        gapH(20),
        const FormLabel('Match length'),
        Obx(() => ChoiceChips(
              options: const [('1', 'Best of 1'), ('3', 'Best of 3'), ('5', 'Best of 5')],
              selected: '${c.games.value}',
              onSelected: (v) => c.games.value = int.parse(v),
            )),
        if (c.sport.value == 'PICKLEBALL') ...[
          gapH(20),
          const FormLabel('Scoring'),
          Obx(() => ChoiceChips(options: TournamentOptions.pickleballScoring, selected: c.scoring.value, onSelected: (v) => c.scoring.value = v)),
        ],
        gapH(20),
        FormCard(
          child: Obx(() => Column(
                children: [
                  NumberStepper(
                    label: 'Points per game',
                    value: c.pointsPerGame.value,
                    min: 5,
                    max: 30,
                    onChanged: (v) => c.pointsPerGame.value = v,
                  ),
                  SwitchRow(
                    label: 'Win by 2 points',
                    hint: 'A game at deuce continues until one side leads by 2.',
                    value: c.winByTwo.value,
                    onChanged: (v) => c.winByTwo.value = v,
                  ),
                ],
              )),
        ),
      ];
}

// ─── 6. Points ──────────────────────────────────────────────────

class PointsStep extends GetView<CreateTournamentController> {
  const PointsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'Points table',
      subtitle: 'Points for each result in the league stage.',
      children: [
        FormCard(
          child: Obx(() => Column(
                children: [
                  NumberStepper(label: 'Win', value: c.ptsWin.value, min: 0, max: 10, onChanged: (v) => c.ptsWin.value = v),
                  NumberStepper(label: 'Tie', value: c.ptsTie.value, min: 0, max: 10, onChanged: (v) => c.ptsTie.value = v),
                  NumberStepper(
                    label: 'No result',
                    hint: 'Abandoned or washed out',
                    value: c.ptsNoResult.value,
                    min: 0,
                    max: 10,
                    onChanged: (v) => c.ptsNoResult.value = v,
                  ),
                  NumberStepper(label: 'Loss', value: c.ptsLoss.value, min: 0, max: 10, onChanged: (v) => c.ptsLoss.value = v),
                ],
              )),
        ),
        gapH(20),
        const FormLabel('If teams are level on points', hint: 'Used to decide who ranks higher.'),
        Obx(() => ChoiceChips(
              options: TournamentOptions.tiebreakers[c.sport.value] ?? const [],
              selected: c.tiebreaker.value,
              onSelected: (v) => c.tiebreaker.value = v,
            )),
      ],
    );
  }
}

// ─── 7. Fees & prize ────────────────────────────────────────────

class FeesStep extends GetView<CreateTournamentController> {
  const FeesStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _StepBody(
      title: 'Entry fee & prize',
      subtitle: 'Leave the fee empty for a free tournament.',
      children: [
        const FormLabel('Entry fee per team', optional: true),
        FieldTextInput(
          key: const ValueKey('t-fee'),
          controller: c.entryFeeCtrl,
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
        Obx(() => ChoiceChips(options: TournamentOptions.prizeTypes, selected: c.prizeType.value, onSelected: (v) => c.prizeType.value = v)),
        Obx(() => c.prizeType.value == 'NONE'
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsets.only(top: SizeConfig.h(12)),
                child: FieldTextInput(
                  controller: c.prizeCtrl,
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
    final format = TournamentOptions.formats.where((f) => f.$1 == c.format.value).firstOrNull?.$2 ?? '';

    String rulesSummary() {
      switch (c.sport.value) {
        case 'CRICKET':
          final t = label(TournamentOptions.cricketMatchTypes, c.matchType.value);
          final o = c.matchType.value == 'TEST' ? '' : ', ${c.overs.value} overs';
          return '$t$o, ${label(TournamentOptions.ballTypes, c.ballType.value).toLowerCase()} ball, ${c.playersPerSide.value} a side';
        case 'FOOTBALL':
          return '${c.footballPlayers.value} a side, 2 × ${c.halfMinutes.value} min';
        default:
          return '${label(TournamentOptions.racketEvents, c.racketEvent.value)}, best of ${c.games.value}, ${c.pointsPerGame.value} points';
      }
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
          _ReviewSection(step: 'format', title: 'Format', lines: [
            '$format · ${c.maxTeams.value} ${c.sport.value == 'BADMINTON' || c.sport.value == 'PICKLEBALL' ? 'entries' : 'teams'}',
            if (c.format.value == 'LEAGUE_KNOCKOUT') '${c.groupCount.value} groups, top ${c.qualifyPerGroup.value} qualify',
            'Squad of ${c.squadMin.value} to ${c.squadMax.value} players',
          ]),
          _ReviewSection(step: 'rules', title: 'Match rules', lines: [rulesSummary()]),
          if (steps.contains('points'))
            _ReviewSection(step: 'points', title: 'Points', lines: [
              'Win ${c.ptsWin.value} · Tie ${c.ptsTie.value} · No result ${c.ptsNoResult.value} · Loss ${c.ptsLoss.value}',
              'Tie-breaker: ${label(TournamentOptions.tiebreakers[c.sport.value] ?? const [], c.tiebreaker.value)}',
            ]),
          _ReviewSection(step: 'fees', title: 'Entry fee & prize', lines: [
            c.entryFee > 0 ? '${rupees(c.entryFee)} per team' : 'Free entry',
            c.prizeType.value == 'NONE'
                ? 'No prize'
                : (c.prizeCtrl.text.trim().isEmpty ? label(TournamentOptions.prizeTypes, c.prizeType.value) : c.prizeCtrl.text.trim()),
          ]),
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
  final String title;
  final List<String> lines;
  const _ReviewSection({required this.step, required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    final error = controller.validate(step);
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
