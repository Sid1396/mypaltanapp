import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../data/models/fixtures.dart';
import '../../data/models/tournament.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/tournament_controller.dart';
import 'tournament_form_widgets.dart';
import 'tournament_media_editors.dart' show SmallButtonLarge;

const _amber = Color(0xFFFFB74D);
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtFixtureDay(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
String fmtFixtureTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

Widget fixturePickerTheme(BuildContext ctx, Widget? child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: AppColors.primary, onPrimary: Colors.white, surface: AppColors.darkSurface, onSurface: Colors.white),
        dialogTheme: const DialogThemeData(backgroundColor: AppColors.darkSurface),
      ),
      child: child!,
    );

Widget _logo(String? url, double size) => ClipRRect(
      borderRadius: BorderRadius.circular(SizeConfig.r(8)),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2A2A)))
            : ColoredBox(color: const Color(0xFF2A2A2A), child: Icon(Icons.shield_rounded, size: size * 0.5, color: Colors.white.withAlpha(60))),
      ),
    );

// ─── Your next match (About tab) ────────────────────────────────

class NextMatchCard extends GetView<TournamentController> {
  const NextMatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final f = controller.fixtures.value;
      final m = f != null && f.published ? f.myNextMatch : null;
      if (f == null || m == null) return const SizedBox.shrink();
      final mine = f.myEntryIds.contains(m.homeEntryId) ? m.homeEntryId : m.awayEntryId;
      final otherId = mine == m.homeEntryId ? m.awayEntryId : m.homeEntryId;
      final other = f.team(otherId)?.name ?? (mine == m.homeEntryId ? m.awayLabel : m.homeLabel) ?? 'To be decided';
      final d = f.divisionOf(m);
      return Padding(
        padding: EdgeInsets.only(bottom: SizeConfig.h(16)),
        child: GestureDetector(
          onTap: () => controller.tab.value = 2,
          child: Container(
            key: const ValueKey('next-match-card'),
            padding: EdgeInsets.all(SizeConfig.r(14)),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withAlpha(60), AppColors.primary.withAlpha(15)]),
              borderRadius: BorderRadius.circular(SizeConfig.r(14)),
              border: Border.all(color: AppColors.primary.withAlpha(90)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('YOUR NEXT MATCH', style: tfStyle(11, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.8)),
                  gapH(4),
                  Text('${f.team(mine)?.name ?? 'Your team'} v $other', style: tfStyle(15.5, weight: FontWeight.w800)),
                  gapH(2),
                  Text('${fmtFixtureDay(m.at)} · ${fmtFixtureTime(m.at)} · Pitch ${m.pitch}${d != null && f.divisions.length > 1 ? ' · ${d.name}' : ''}',
                      style: tfStyle(12.5, color: Colors.white.withAlpha(190))),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(150)),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── Fixtures tab ───────────────────────────────────────────────

class FixturesTabBody extends GetView<TournamentController> {
  final Tournament t;
  const FixturesTabBody({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (t.isDraft) return _empty('Publish the tournament first. Fixtures are made once teams are confirmed.');
      if (!controller.fixturesLoaded.value) {
        return Padding(padding: EdgeInsets.only(top: SizeConfig.h(30)), child: const Center(child: CircularProgressIndicator(color: AppColors.primary)));
      }
      final f = controller.fixtures.value;
      if (f == null || !f.hasMatches) {
        if (!t.isOwner) return _empty('The organiser has not published the fixtures yet. You will get a notification when they are out.');
        final ready = f?.divisions.where((d) => d.teams.length >= 2).length ?? 0;
        return FormCard(
          padding: EdgeInsets.all(SizeConfig.r(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Make the match schedule', style: tfStyle(16, weight: FontWeight.w800)),
            gapH(6),
            Text(
              ready == 0
                  ? 'Confirm at least 2 teams in a division first (Teams tab). Then MyPaltan makes the fixtures for you.'
                  : 'Pick start times and pitches. MyPaltan makes the groups, rounds and finals, with a time and pitch for every match.',
              style: tfStyle(13, color: Colors.white.withAlpha(160), height: 1.45),
            ),
            if (f != null)
              for (final d in f.divisions) ...[
                gapH(8),
                Text('${d.name}: ${d.teams.length} confirmed ${d.teams.length == 1 ? 'team' : 'teams'}', style: tfStyle(12.5, color: Colors.white.withAlpha(140))),
              ],
            gapH(14),
            SizedBox(
              width: double.infinity,
              child: SmallButtonLarge(key: const ValueKey('fixtures-make'), label: 'Make fixtures', onTap: ready == 0 ? null : controller.openFixturesSetup),
            ),
          ]),
        );
      }
      final filter = controller.fixtureFilter.value; // 0 = all, -1 = my matches, else division id
      final divisions = filter > 0 ? f.divisions.where((d) => d.id == filter).toList() : f.divisions;
      var matches = f.allMatches.where((m) => filter <= 0 || m.divisionId == filter).toList();
      if (filter == -1) matches = matches.where((m) => m.involves(f.myEntryIds)).toList();
      final byDay = <String, List<FixtureMatch>>{};
      for (final m in matches) {
        byDay.putIfAbsent(fmtFixtureDay(m.at), () => []).add(m);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (f.isOwner) ...[_OwnerBar(f: f), gapH(16)],
          if (f.divisions.length > 1 || f.myEntryIds.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip(label: 'All', selected: filter == 0, onTap: () => controller.fixtureFilter.value = 0),
                if (f.myEntryIds.isNotEmpty)
                  _FilterChip(key: const ValueKey('fixtures-mine'), label: 'My matches', selected: filter == -1, onTap: () => controller.fixtureFilter.value = -1),
                if (f.divisions.length > 1)
                  for (final d in f.divisions.where((d) => d.matches.isNotEmpty))
                    _FilterChip(label: d.name, selected: filter == d.id, onTap: () => controller.fixtureFilter.value = d.id),
              ]),
            ),
            gapH(14),
          ],
          if (filter != -1)
            for (final d in divisions.where((d) => d.groupsInSchedule >= 1 && d.matches.any((m) => !m.isKnockout))) ...[_GroupsCard(d: d, showName: f.divisions.length > 1), gapH(14)],
          if (matches.isEmpty) Text('No matches here.', style: tfStyle(13, color: Colors.white.withAlpha(130))),
          for (final e in byDay.entries) ...[
            Padding(
              padding: EdgeInsets.only(top: SizeConfig.h(6), bottom: SizeConfig.h(8)),
              child: Text(e.key.toUpperCase(), style: tfStyle(12, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.6)),
            ),
            for (final m in e.value) _MatchRow(m: m, f: f, showDivision: f.divisions.length > 1 && filter <= 0),
          ],
        ],
      );
    });
  }

  Widget _empty(String message) => FormCard(
        padding: EdgeInsets.all(SizeConfig.r(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_note_rounded, color: Colors.white.withAlpha(140), size: SizeConfig.r(20)),
            SizedBox(width: SizeConfig.w(10)),
            Text('No fixtures yet', style: tfStyle(15, weight: FontWeight.w700)),
          ]),
          gapH(8),
          Text(message, style: tfStyle(13, color: Colors.white.withAlpha(140), height: 1.45)),
        ]),
      );
}

class _OwnerBar extends GetView<TournamentController> {
  final Fixtures f;
  const _OwnerBar({required this.f});

  @override
  Widget build(BuildContext context) {
    final color = f.published ? AppColors.positive : _amber;
    return Container(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.published ? 'Published' : 'Draft', style: tfStyle(15, weight: FontWeight.w800)),
        gapH(4),
        Text(
          f.published
              ? 'Every team can see these. Tap a match to change its time, pitch or teams, then publish again to tell them.'
              : 'Only you can see these. Tap a match to change it. Publish to tell every team.',
          style: tfStyle(12.5, color: Colors.white.withAlpha(185), height: 1.4),
        ),
        if (f.teamsChanged) ...[
          gapH(8),
          Text('Confirmed teams changed since these were made. Make the fixtures again to include them.',
              style: tfStyle(12.5, weight: FontWeight.w700, color: _amber, height: 1.4)),
        ],
        gapH(12),
        Obx(() => Row(children: [
              Expanded(
                child: _Button(
                  key: const ValueKey('fixtures-remake'),
                  label: 'Make again',
                  onTap: controller.openFixturesSetup,
                ),
              ),
              SizedBox(width: SizeConfig.w(10)),
              Expanded(
                child: _Button(
                  key: const ValueKey('fixtures-publish'),
                  label: controller.isPublishingFixtures.value ? 'Publishing…' : (f.published ? 'Publish again' : 'Publish'),
                  filled: true,
                  onTap: controller.isPublishingFixtures.value ? null : controller.confirmPublishFixtures,
                ),
              ),
            ])),
      ]),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  const _Button({super.key, required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: SizeConfig.h(10)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(SizeConfig.r(10)),
            border: Border.all(color: filled ? AppColors.primary : Colors.white.withAlpha(45)),
          ),
          child: Text(label, style: tfStyle(13.5, weight: FontWeight.w700)),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(right: SizeConfig.w(8)),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(7)),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withAlpha(40) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(SizeConfig.r(100)),
              border: Border.all(color: selected ? AppColors.primary : Colors.white.withAlpha(20)),
            ),
            child: Text(label, style: tfStyle(12.5, weight: FontWeight.w700, color: selected ? Colors.white : Colors.white.withAlpha(160))),
          ),
        ),
      );
}

class _GroupsCard extends StatelessWidget {
  final FixtureDivision d;
  final bool showName;
  const _GroupsCard({required this.d, required this.showName});

  @override
  Widget build(BuildContext context) {
    final groups = d.groupsInSchedule;
    final knockout = d.matches.any((m) => m.isKnockout);
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${showName ? '${d.name.toUpperCase()} · ' : ''}${groups > 1 ? '$groups GROUPS' : (knockout ? 'GROUP' : 'LEAGUE')}',
          style: tfStyle(11.5, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.6),
        ),
        gapH(8),
        for (var k = 1; k <= groups; k++) ...[
          if (groups > 1) Padding(padding: EdgeInsets.only(top: SizeConfig.h(4)), child: Text('Group ${groupLetters[k - 1]}', style: tfStyle(12.5, weight: FontWeight.w800))),
          Wrap(
            spacing: SizeConfig.w(6),
            runSpacing: SizeConfig.h(6),
            children: [
              for (final t in d.teams.where((t) => (t.groupNo ?? 1) == k))
                Container(
                  padding: EdgeInsets.fromLTRB(SizeConfig.w(4), SizeConfig.h(4), SizeConfig.w(10), SizeConfig.h(4)),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ClipOval(child: _logo(t.logoUrl, SizeConfig.r(22))),
                    SizedBox(width: SizeConfig.w(6)),
                    Text(t.name, style: tfStyle(12.5, weight: FontWeight.w600)),
                  ]),
                ),
            ],
          ),
          gapH(6),
        ],
        if (knockout)
          Text(
            d.matches.where((m) => m.isKnockout).length == 1
                ? 'The top two play the final.'
                : groups == 1
                    ? 'The top ${d.qualifyPerGroup ?? 2} go to the knockouts.'
                    : 'The top ${d.qualifyPerGroup ?? 1} of each group go to the knockouts.',
            style: tfStyle(12, color: Colors.white.withAlpha(140)),
          ),
      ]),
    );
  }
}

class _MatchRow extends GetView<TournamentController> {
  final FixtureMatch m;
  final Fixtures f;
  final bool showDivision;
  const _MatchRow({required this.m, required this.f, required this.showDivision});

  @override
  Widget build(BuildContext context) {
    final d = f.divisionOf(m);
    final home = f.team(m.homeEntryId), away = f.team(m.awayEntryId);
    final mine = m.involves(f.myEntryIds);
    Widget side(FixtureTeam? t, String? label, {bool right = false}) => Expanded(
          child: Row(
            mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!right) ...[_logo(t?.logoUrl, SizeConfig.r(24)), SizedBox(width: SizeConfig.w(6))],
              Flexible(
                child: Text(
                  t?.name ?? label ?? 'To be decided',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: right ? TextAlign.right : TextAlign.left,
                  style: tfStyle(13, weight: FontWeight.w700, color: t == null ? Colors.white.withAlpha(140) : Colors.white),
                ),
              ),
              if (right) ...[SizedBox(width: SizeConfig.w(6)), _logo(t?.logoUrl, SizeConfig.r(24))],
            ],
          ),
        );
    return GestureDetector(
      key: ValueKey('match-${m.divisionId}-${m.matchNo}'),
      onTap: f.isOwner && m.status == 'SCHEDULED' ? () => showEditMatchSheet(m) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: SizeConfig.h(8)),
        padding: EdgeInsets.all(SizeConfig.r(12)),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary.withAlpha(22) : (m.isKnockout ? const Color(0xFF221A16) : const Color(0xFF1A1A1A)),
          borderRadius: BorderRadius.circular(SizeConfig.r(12)),
          border: Border.all(color: mine ? AppColors.primary.withAlpha(120) : Colors.white.withAlpha(12)),
        ),
        child: Row(children: [
          SizedBox(
            width: SizeConfig.w(62),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fmtFixtureTime(m.at), style: tfStyle(13, weight: FontWeight.w800)),
              Text('Pitch ${m.pitch}', style: tfStyle(11, color: Colors.white.withAlpha(130))),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${showDivision && d != null ? '${d.name} · ' : ''}${m.stageLabel(d?.groupsInSchedule ?? 1)}',
                style: tfStyle(10.5, weight: FontWeight.w800, color: m.isKnockout ? AppColors.primary : Colors.white.withAlpha(120)),
              ),
              gapH(4),
              Row(children: [
                side(home, m.homeLabel),
                Padding(padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(6)), child: Text('v', style: tfStyle(12, color: Colors.white.withAlpha(110)))),
                side(away, m.awayLabel, right: true),
              ]),
            ]),
          ),
          if (f.isOwner && m.status == 'SCHEDULED') ...[
            SizedBox(width: SizeConfig.w(6)),
            Icon(Icons.edit_rounded, size: SizeConfig.r(14), color: Colors.white.withAlpha(80)),
          ],
        ]),
      ),
    );
  }
}

// ─── Edit one match (organiser) ─────────────────────────────────

void showEditMatchSheet(FixtureMatch m) {
  final c = Get.find<TournamentController>();
  final f = c.fixtures.value!;
  final d = f.divisionOf(m)!;
  final at = m.at.obs, pitch = m.pitch.obs;
  final home = Rx<int?>(m.homeEntryId), away = Rx<int?>(m.awayEntryId);
  final saving = false.obs;

  Widget teamPicker(String label, Rx<int?> v, String? placeholder, Key key) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormLabel(label),
          Wrap(spacing: SizeConfig.w(6), runSpacing: SizeConfig.h(6), children: [
            if (placeholder != null)
              _FilterChip(label: placeholder, selected: v.value == null, onTap: () => v.value = null),
            for (final t in d.teams) _FilterChip(key: ValueKey('$key-${t.entryId}'), label: t.name, selected: v.value == t.entryId, onTap: () => v.value = t.entryId),
          ]),
        ],
      );

  Get.bottomSheet(
    Builder(builder: (sheet) => Obx(() => SheetFrame(title: '${d.name} · ${m.stageLabel(d.groupsInSchedule)}', children: [
          GestureDetector(
            key: const ValueKey('match-edit-time'),
            onTap: () async {
              final day = await showDatePicker(
                context: sheet,
                initialDate: at.value,
                firstDate: f.startDate,
                lastDate: f.endDate,
                builder: fixturePickerTheme,
              );
              if (day == null || !sheet.mounted) return;
              final t = await showTimePicker(context: sheet, initialTime: TimeOfDay.fromDateTime(at.value), builder: fixturePickerTheme);
              if (t != null) at.value = DateTime(day.year, day.month, day.day, t.hour, t.minute);
            },
            child: FormCard(
              padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(12)),
              child: Row(children: [
                Icon(Icons.schedule_rounded, size: SizeConfig.r(18), color: AppColors.primary),
                SizedBox(width: SizeConfig.w(10)),
                Expanded(child: Text('${fmtFixtureDay(at.value)} · ${fmtFixtureTime(at.value)}', style: tfStyle(14.5, weight: FontWeight.w700))),
                Icon(Icons.edit_rounded, size: SizeConfig.r(14), color: Colors.white.withAlpha(110)),
              ]),
            ),
          ),
          NumberStepper(label: 'Pitch', value: pitch.value, min: 1, max: 8, onChanged: (v) => pitch.value = v),
          gapH(8),
          teamPicker('Home team', home, m.homeLabel, const ValueKey('match-home')),
          gapH(12),
          teamPicker('Away team', away, m.awayLabel, const ValueKey('match-away')),
          gapH(18),
          SizedBox(
            width: double.infinity,
            child: SmallButtonLarge(
              key: const ValueKey('match-edit-save'),
              label: saving.value ? 'Saving…' : 'Save match',
              onTap: saving.value
                  ? null
                  : () async {
                      saving.value = true;
                      final message = await c.updateMatch(m, at.value, pitch.value, home.value, away.value);
                      saving.value = false;
                      if (message != null && sheet.mounted) {
                        Navigator.of(sheet).pop();
                        c.showMessage('Saved', message);
                      }
                    },
            ),
          ),
          if (f.published) ...[
            gapH(8),
            Center(child: Text('Teams see changes after you publish again.', style: tfStyle(12, color: Colors.white.withAlpha(130)))),
          ],
        ]))),
    isScrollControlled: true,
  );
}
