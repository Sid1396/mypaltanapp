import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/sports.dart';
import '../../config/tournament_options.dart';
import '../../data/models/tournament.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/tournament_controller.dart';
import '../widgets/create_tournament_steps.dart' show fmtDate, fmtDateTime, rupees;
import '../widgets/form_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/tournament_form_widgets.dart';
import '../widgets/tournament_media_editors.dart' show fileSizeLabel;
import '../widgets/tournament_share.dart';

String _l(List<(String, String)> o, String? c) => Sports.labelOf(o, c);

/// Shown when a signed image link fails to load (expired link or dropped connection).
Widget _imgError(BuildContext context, Object error, StackTrace? stack) =>
    Container(color: const Color(0xFF2A2A2A), child: Icon(Icons.image_not_supported_outlined, color: Colors.white.withAlpha(60), size: SizeConfig.r(18)));

String rulesSummary(Tournament t) => rulesSummaryFor(t.sport, t.matchRules);

String rulesSummaryFor(String sport, Map<String, dynamic> r) {
  switch (sport) {
    case 'CRICKET':
      final type = _l(TournamentOptions.cricketMatchTypes, r['match_type']?.toString());
      final overs = r['overs'] != null ? ', ${r['overs']} overs' : '';
      return '$type$overs, ${_l(TournamentOptions.ballTypes, r['ball_type']?.toString()).toLowerCase()} ball, ${r['players_per_side']} a side';
    case 'FOOTBALL':
      return '${r['players_per_side']} a side, 2 × ${r['half_minutes']} min';
    default:
      return '${_l(TournamentOptions.racketEvents, r['event']?.toString())}, best of ${r['games']}, ${r['points_per_game']} points';
  }
}

class TournamentPage extends GetView<TournamentController> {
  const TournamentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Obx(() {
        final t = controller.tournament.value;
        if (controller.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (t == null) return _ErrorView(message: controller.error.value ?? 'Tournament not found.', onRetry: controller.load);
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: controller.load,
                child: CustomScrollView(
                  slivers: [
                    _Hero(t: t),
                    SliverToBoxAdapter(child: _Header(t: t)),
                    SliverToBoxAdapter(child: _Tabs(t: t)),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(16), SizeConfig.w(20), SizeConfig.h(30)),
                      sliver: SliverToBoxAdapter(
                        child: switch (controller.tab.value) {
                          0 => _AboutTab(t: t),
                          1 => _TeamsTab(t: t),
                          2 => _SponsorsTab(t: t),
                          _ => _DocumentsTab(t: t),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _BottomBar(t: t),
          ],
        );
      }),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: Get.back, icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white))),
          const Spacer(),
          EmptyCard(icon: Icons.emoji_events_outlined, title: 'Could not open tournament', message: message, actions: [SmallButton(label: 'Try again', onTap: onRetry)]),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Tournament t;
  const _Hero({required this.t});

  @override
  Widget build(BuildContext context) {
    final image = t.bannerUrl ?? t.logoUrl;
    return SliverAppBar(
      pinned: true,
      expandedHeight: t.bannerUrl != null ? SizeConfig.w(375) * 9 / 16 : SizeConfig.h(170),
      backgroundColor: AppColors.secondary,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: EdgeInsets.only(left: SizeConfig.w(12)),
        child: Center(
          child: GestureDetector(
            key: const ValueKey('tournament-back'),
            onTap: Get.back,
            child: Container(
              width: SizeConfig.r(40),
              height: SizeConfig.r(40),
              decoration: BoxDecoration(color: Colors.black.withAlpha(170), shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(40))),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: SizeConfig.r(18)),
            ),
          ),
        ),
      ),
      actions: [
        if (!t.isDraft)
          Padding(
            padding: EdgeInsets.only(right: SizeConfig.w(12)),
            child: Center(
              child: GestureDetector(
                key: const ValueKey('tournament-share'),
                onTap: () => showTournamentShareSheet(t),
                child: Container(
                  width: SizeConfig.r(40),
                  height: SizeConfig.r(40),
                  decoration: BoxDecoration(color: Colors.black.withAlpha(170), shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(40))),
                  child: Icon(Icons.ios_share_rounded, color: Colors.white, size: SizeConfig.r(18)),
                ),
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1A1A)))
            else
              const ColoredBox(color: Color(0xFF1A1A1A)),
            if (t.bannerUrl == null) ColoredBox(color: Colors.black.withAlpha(150)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xFF121212)],
                  stops: [0, 0.35, 0.7, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends GetView<TournamentController> {
  final Tournament t;
  const _Header({required this.t});

  @override
  Widget build(BuildContext context) {
    final sport = Sports.byCode(t.sport);
    final title = t.titleSponsor;
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(20), 0, SizeConfig.w(20), 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: SizeConfig.r(76),
                height: SizeConfig.r(76),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(SizeConfig.r(18)),
                  border: Border.all(color: AppColors.secondary, width: 3),
                ),
                child: t.logoUrl != null ? Image.network(t.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()) : null,
              ),
              SizedBox(width: SizeConfig.w(12)),
              Expanded(
                child: Wrap(
                  spacing: SizeConfig.w(6),
                  runSpacing: SizeConfig.h(6),
                  children: [
                    _Pill(t.statusLabel.toUpperCase(), color: t.isDraft ? Colors.white.withAlpha(160) : AppColors.primary),
                    if (!t.isDraft && t.visibility == 'PRIVATE') _Pill('PRIVATE', color: Colors.white.withAlpha(160)),
                  ],
                ),
              ),
            ],
          ),
          gapH(12),
          Text(t.name, style: tfStyle(24, weight: FontWeight.w900, height: 1.15)),
          gapH(6),
          Text('${sport?.label ?? t.sport} · ${_l(TournamentOptions.categories, t.category)} · ${t.location}',
              style: tfStyle(13, color: Colors.white.withAlpha(150))),
          if (title != null) ...[
            gapH(14),
            Builder(builder: (_) {
              controller.sponsorSeen(title.id);
              return GestureDetector(
                onTap: () => controller.openSponsor(title),
                child: Container(
                  padding: EdgeInsets.all(SizeConfig.r(10)),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(SizeConfig.r(12))),
                  child: Row(
                    children: [
                      Text('PRESENTED BY', style: tfStyle(10.5, weight: FontWeight.w800, color: Colors.white.withAlpha(130)).copyWith(letterSpacing: 1)),
                      SizedBox(width: SizeConfig.w(10)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(SizeConfig.r(6)),
                        child: SizedBox(
                          width: SizeConfig.r(28),
                          height: SizeConfig.r(28),
                          child: title.logoUrl != null ? Image.network(title.logoUrl!, fit: BoxFit.cover, errorBuilder: _imgError) : null,
                        ),
                      ),
                      SizedBox(width: SizeConfig.w(8)),
                      Expanded(child: Text(title.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w800))),
                      if (title.linkUrl != null) Icon(Icons.open_in_new_rounded, size: SizeConfig.r(16), color: Colors.white.withAlpha(120)),
                    ],
                  ),
                ),
              );
            }),
          ],
          gapH(14),
          _OrganizerRow(t: t),
          if (t.isOwner) ...[gapH(14), _OwnerCard(t: t)],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(5)),
      decoration: BoxDecoration(color: color.withAlpha(35), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
      child: Text(text, style: tfStyle(11, weight: FontWeight.w800, color: color)),
    );
  }
}

class _OrganizerRow extends StatelessWidget {
  final Tournament t;
  const _OrganizerRow({required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: SizeConfig.r(17),
          backgroundColor: const Color(0xFF2A2A2A),
          backgroundImage: t.organizerPhotoUrl != null ? NetworkImage(t.organizerPhotoUrl!) : null,
          onBackgroundImageError: t.organizerPhotoUrl != null ? (_, __) {} : null,
          child: t.organizerPhotoUrl == null ? Icon(Icons.person_rounded, size: SizeConfig.r(18), color: Colors.white.withAlpha(120)) : null,
        ),
        SizedBox(width: SizeConfig.w(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(t.organizerName ?? 'Organiser', maxLines: 1, overflow: TextOverflow.ellipsis, style: tfStyle(14, weight: FontWeight.w700))),
                  if (t.organizerVerified) ...[
                    SizedBox(width: SizeConfig.w(4)),
                    Icon(Icons.verified_rounded, size: SizeConfig.r(16), color: AppColors.primary),
                  ],
                ],
              ),
              Text(
                t.organizerVerified
                    ? 'Verified organiser${t.organizerCompleted > 0 ? ' · ${t.organizerCompleted} tournaments run' : ''}'
                    : 'Organiser',
                style: tfStyle(12, color: Colors.white.withAlpha(130)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Status and actions only the organiser sees.
class _OwnerCard extends GetView<TournamentController> {
  final Tournament t;
  const _OwnerCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String body;
    if (t.isDraft) {
      title = 'Draft';
      body = 'Only you can see this tournament. Publish it to open registration and get a link to share.';
    } else if (t.visibility == 'PUBLIC_PENDING') {
      title = 'Waiting for approval';
      body = 'The MyPaltan team will list it publicly within 24 hours. Captains can already join with the code.';
    } else if (t.visibility == 'PRIVATE') {
      title = 'Private tournament';
      body = 'Not listed publicly. Share the code with captains so they can register.';
    } else {
      title = 'Live on MyPaltan';
      body = 'Your tournament is listed for everyone in ${t.city}.';
    }
    return Container(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tfStyle(15, weight: FontWeight.w800)),
          gapH(4),
          Text(body, style: tfStyle(12.5, color: Colors.white.withAlpha(180), height: 1.4)),
          gapH(12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: controller.copyCode,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(12), vertical: SizeConfig.h(10)),
                    decoration: BoxDecoration(color: Colors.black.withAlpha(90), borderRadius: BorderRadius.circular(SizeConfig.r(10))),
                    child: Row(
                      children: [
                        Text('Code ', style: tfStyle(12.5, color: Colors.white.withAlpha(150))),
                        Text(t.code, style: tfStyle(15, weight: FontWeight.w900).copyWith(letterSpacing: 2)),
                        const Spacer(),
                        Icon(Icons.copy_rounded, size: SizeConfig.r(16), color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: SizeConfig.w(8)),
              GestureDetector(
                key: const ValueKey('tournament-edit'),
                onTap: controller.edit,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(10)),
                  decoration: BoxDecoration(border: Border.all(color: Colors.white.withAlpha(50)), borderRadius: BorderRadius.circular(SizeConfig.r(10))),
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: SizeConfig.r(15), color: Colors.white),
                      SizedBox(width: SizeConfig.w(6)),
                      Text('Edit', style: tfStyle(13, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (t.isDraft) ...[
            gapH(10),
            Obx(() => GestureDetector(
                  key: const ValueKey('delete-draft'),
                  onTap: controller.isDeleting.value ? null : controller.confirmDeleteDraft,
                  child: Row(
                    children: [
                      controller.isDeleting.value
                          ? SizedBox(width: SizeConfig.r(15), height: SizeConfig.r(15), child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.negative))
                          : Icon(Icons.delete_outline_rounded, size: SizeConfig.r(17), color: AppColors.negative),
                      SizedBox(width: SizeConfig.w(6)),
                      Text('Delete draft', style: tfStyle(13, weight: FontWeight.w700, color: AppColors.negative)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _Tabs extends GetView<TournamentController> {
  final Tournament t;
  const _Tabs({required this.t});

  @override
  Widget build(BuildContext context) {
    final labels = ['About', 'Teams', 'Sponsors${t.sponsors.isEmpty ? '' : ' ${t.sponsors.length}'}', 'Documents${t.documents.isEmpty ? '' : ' ${t.documents.length}'}'];
    return Padding(
      padding: EdgeInsets.only(top: SizeConfig.h(18)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: EdgeInsets.only(right: SizeConfig.w(8)),
                child: GestureDetector(
                  key: ValueKey('tournament-tab-$i'),
                  onTap: () => controller.tab.value = i,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(16), vertical: SizeConfig.h(9)),
                    decoration: BoxDecoration(
                      color: controller.tab.value == i ? AppColors.primary : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(SizeConfig.r(100)),
                    ),
                    child: Text(labels[i],
                        style: tfStyle(13, weight: FontWeight.w700, color: controller.tab.value == i ? Colors.white : Colors.white.withAlpha(150))),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── About ──────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SizeConfig.h(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: SizeConfig.r(36),
            height: SizeConfig.r(36),
            decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(SizeConfig.r(10))),
            child: Icon(icon, color: AppColors.primary, size: SizeConfig.r(18)),
          ),
          SizedBox(width: SizeConfig.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tfStyle(12, color: Colors.white.withAlpha(130))),
                gapH(1),
                Text(value, style: tfStyle(14.5, weight: FontWeight.w700, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  final Tournament t;
  const _AboutTab({required this.t});

  @override
  Widget build(BuildContext context) {
    final isRacket = t.sport == 'BADMINTON' || t.sport == 'PICKLEBALL';
    final dates = t.startDate == t.endDate ? fmtDate(t.startDate) : '${fmtDate(t.startDate)} to ${fmtDate(t.endDate)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (t.description != null) ...[
          Text(t.description!, style: tfStyle(14, color: Colors.white.withAlpha(200), height: 1.5)),
          gapH(12),
        ],
        _InfoRow(Icons.calendar_today_rounded, 'Dates', '$dates\n${_l(TournamentOptions.matchDays, t.matchDays)} · ${_l(TournamentOptions.matchTimings, t.matchTiming)}'),
        _InfoRow(Icons.place_rounded, 'Grounds', '${t.grounds.join(', ')}\n${t.location}'),
        if (t.hasDivisions) ...[
          gapH(8),
          Text('${t.divisions.length} DIVISIONS', style: tfStyle(11, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.8)),
          gapH(8),
          for (final d in t.divisions) ...[_DivisionCard(d: d, sport: t.sport), gapH(10)],
          gapH(4),
        ] else
          ..._divisionRows(t.divisions.isNotEmpty ? t.divisions.first : null, t, isRacket),
        if (t.foodProvided || t.jerseyProvided)
          _InfoRow(Icons.restaurant_rounded, 'Included', [
            if (t.foodProvided) 'Food (${t.meals.map((m) => _l(TournamentOptions.meals, m).toLowerCase()).join(', ')})',
            if (t.jerseyProvided) 'Jerseys${t.jerseyPrint != null ? ', ${_l(TournamentOptions.jerseyPrints, t.jerseyPrint).toLowerCase()}' : ''}',
          ].join(' · ')),
        _InfoRow(Icons.schedule_rounded, 'Registration closes', fmtDateTime(t.registrationDeadline)),
        if (t.isOwner && t.payment != null) ...[gapH(12), _PaymentCard(p: t.payment!)],
      ],
    );
  }
}

String _formatLine(String format, int? groups, int? qualify) {
  final f = TournamentOptions.formats.where((x) => x.$1 == format).firstOrNull?.$2 ?? format;
  return '$f${format == 'LEAGUE_KNOCKOUT' ? ', $groups ${groups == 1 ? 'group' : 'groups'}, top $qualify qualify' : ''}';
}

String _pointsLine(String sport, Map<String, dynamic> p) {
  if (p.isEmpty) return '';
  final tbs = (p['tiebreakers'] is List ? (p['tiebreakers'] as List) : [if (p['tiebreaker'] != null) p['tiebreaker']])
      .map((x) => _l(TournamentOptions.tiebreakers[sport] ?? const [], '$x').toLowerCase())
      .join(', then ');
  return 'Win ${p['win']} · ${sport == 'FOOTBALL' ? 'Draw' : 'Tie'} ${p['tie']} · Loss ${p['loss']}${tbs.isEmpty ? '' : '\nLevel on points: $tbs'}';
}

/// Rows for a tournament with a single division (same layout as before divisions existed).
List<Widget> _divisionRows(TournamentDivision? d, Tournament t, bool isRacket) {
  final format = d?.format ?? t.format;
  final points = d?.points ?? t.points;
  final prizeType = d?.prizeType ?? t.prizeType;
  final prizeDetails = d?.prizeDetails ?? t.prizeDetails;
  return [
    _InfoRow(Icons.account_tree_rounded, 'Format', _formatLine(format, d?.groupCount ?? t.groupCount, d?.qualifyPerGroup ?? t.qualifyPerGroup)),
    _InfoRow(Icons.groups_rounded, isRacket ? 'Entries' : 'Teams',
        '${t.approvedTeams} of ${d?.maxTeams ?? t.maxTeams} confirmed · squads of ${d?.squadMin ?? t.squadMin} to ${d?.squadMax ?? t.squadMax}'),
    if (d?.ageLabel != null) _InfoRow(Icons.cake_rounded, 'Who can play', d!.ageLabel!),
    _InfoRow(Icons.rule_rounded, 'Match rules', rulesSummaryFor(t.sport, d?.matchRules ?? t.matchRules)),
    if (format != 'KNOCKOUT' && points.isNotEmpty) _InfoRow(Icons.leaderboard_rounded, 'Points', _pointsLine(t.sport, points)),
    _InfoRow(Icons.currency_rupee_rounded, 'Entry fee', (d?.entryFee ?? t.entryFee) > 0 ? '${rupees(d?.entryFee ?? t.entryFee)} per team' : 'Free'),
    if (prizeType != 'NONE') _InfoRow(Icons.emoji_events_rounded, 'Prize', prizeDetails ?? _l(TournamentOptions.prizeTypes, prizeType)),
  ];
}

class _DivisionCard extends StatelessWidget {
  final TournamentDivision d;
  final String sport;
  const _DivisionCard({required this.d, required this.sport});

  @override
  Widget build(BuildContext context) {
    final isRacket = sport == 'BADMINTON' || sport == 'PICKLEBALL';
    Widget line(IconData icon, String text) => Padding(
          padding: EdgeInsets.only(top: SizeConfig.h(6)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: SizeConfig.r(15), color: AppColors.primary),
              SizedBox(width: SizeConfig.w(8)),
              Expanded(child: Text(text, style: tfStyle(13, color: Colors.white.withAlpha(210), height: 1.35))),
            ],
          ),
        );
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(d.name, style: tfStyle(17, weight: FontWeight.w900))),
              Container(
                padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(10), vertical: SizeConfig.h(4)),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(100))),
                child: Text(d.entryFee > 0 ? rupees(d.entryFee) : 'Free', style: tfStyle(12, weight: FontWeight.w800, color: AppColors.primary)),
              ),
            ],
          ),
          if (d.ageLabel != null && d.ageLabel!.toLowerCase() != d.name.toLowerCase()) line(Icons.cake_rounded, d.ageLabel!),
          line(Icons.account_tree_rounded, _formatLine(d.format, d.groupCount, d.qualifyPerGroup)),
          line(Icons.groups_rounded, '${d.approvedTeams} of ${d.maxTeams} ${isRacket ? 'entries' : 'teams'} · squads of ${d.squadMin} to ${d.squadMax}'),
          line(Icons.rule_rounded, rulesSummaryFor(sport, d.matchRules)),
          if (d.format != 'KNOCKOUT' && d.points.isNotEmpty) line(Icons.leaderboard_rounded, _pointsLine(sport, d.points)),
          if (d.prizeType != 'NONE') line(Icons.emoji_events_rounded, d.prizeDetails ?? _l(TournamentOptions.prizeTypes, d.prizeType)),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final TournamentPayment p;
  const _PaymentCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR PAYMENT DETAILS', style: tfStyle(11, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.8)),
                gapH(6),
                Text(p.upiId, style: tfStyle(15, weight: FontWeight.w800)),
                Text(p.upiName, style: tfStyle(12.5, color: Colors.white.withAlpha(150))),
                if (p.acceptCash) Text('Cash accepted', style: tfStyle(12.5, color: Colors.white.withAlpha(150))),
                gapH(4),
                Text('Captains see this after registering.', style: tfStyle(11.5, color: Colors.white.withAlpha(110))),
              ],
            ),
          ),
          if (p.qrUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(SizeConfig.r(8)),
              child: Image.network(p.qrUrl!, width: SizeConfig.r(72), height: SizeConfig.r(72), fit: BoxFit.cover, errorBuilder: _imgError),
            ),
        ],
      ),
    );
  }
}

// ─── Teams ──────────────────────────────────────────────────────

class _TeamsTab extends StatelessWidget {
  final Tournament t;
  const _TeamsTab({required this.t});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      padding: EdgeInsets.all(SizeConfig.r(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.white.withAlpha(140), size: SizeConfig.r(20)),
              SizedBox(width: SizeConfig.w(10)),
              Text(t.approvedTeams == 0 ? 'No teams yet' : '${t.approvedTeams} teams confirmed', style: tfStyle(15, weight: FontWeight.w700)),
            ],
          ),
          gapH(8),
          Text(
            t.isDraft
                ? 'Publish the tournament to start taking team registrations.'
                : 'Teams that register appear here.${t.isOwner ? ' You approve each team once you receive its entry fee.' : ''}',
            style: tfStyle(13, color: Colors.white.withAlpha(140), height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ─── Sponsors ───────────────────────────────────────────────────

class _SponsorsTab extends GetView<TournamentController> {
  final Tournament t;
  const _SponsorsTab({required this.t});

  @override
  Widget build(BuildContext context) {
    if (t.sponsors.isEmpty) {
      return Text(t.isOwner ? 'No sponsors yet. Add them from Edit.' : 'No sponsors for this tournament.',
          style: tfStyle(14, color: Colors.white.withAlpha(140)));
    }
    return Column(
      children: [
        for (final s in t.sponsors) ...[
          Builder(builder: (_) {
            controller.sponsorSeen(s.id);
            return _SponsorCard(s: s, owner: t.isOwner, onTap: () => controller.openSponsor(s));
          }),
          gapH(12),
        ],
      ],
    );
  }
}

class _SponsorCard extends StatelessWidget {
  final TournamentSponsor s;
  final bool owner;
  final VoidCallback onTap;
  const _SponsorCard({required this.s, required this.owner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: s.linkUrl != null ? onTap : null,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(SizeConfig.r(16)),
          border: Border.all(color: s.isTitle ? AppColors.primary.withAlpha(120) : Colors.white.withAlpha(12)),
        ),
        child: Column(
          children: [
            if (s.bannerUrl != null) AspectRatio(aspectRatio: 16 / 9, child: Image.network(s.bannerUrl!, fit: BoxFit.cover, errorBuilder: _imgError)),
            Padding(
              padding: EdgeInsets.all(SizeConfig.r(12)),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(SizeConfig.r(10)),
                    child: SizedBox(
                      width: SizeConfig.r(46),
                      height: SizeConfig.r(46),
                      child: s.logoUrl != null ? Image.network(s.logoUrl!, fit: BoxFit.cover, errorBuilder: _imgError) : const ColoredBox(color: Color(0xFF2A2A2A)),
                    ),
                  ),
                  SizedBox(width: SizeConfig.w(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label.toUpperCase(), style: tfStyle(10.5, weight: FontWeight.w800, color: AppColors.primary).copyWith(letterSpacing: 0.8)),
                        Text(s.name, style: tfStyle(15, weight: FontWeight.w800)),
                        if (s.tagline != null) Text(s.tagline!, style: tfStyle(12, color: Colors.white.withAlpha(140))),
                        if (owner) ...[
                          gapH(4),
                          Text('${s.views} views · ${s.taps} taps', style: tfStyle(11.5, weight: FontWeight.w700, color: Colors.white.withAlpha(170))),
                        ],
                      ],
                    ),
                  ),
                  if (s.linkUrl != null) Icon(Icons.open_in_new_rounded, size: SizeConfig.r(18), color: Colors.white.withAlpha(130)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Documents ──────────────────────────────────────────────────

class _DocumentsTab extends GetView<TournamentController> {
  final Tournament t;
  const _DocumentsTab({required this.t});

  @override
  Widget build(BuildContext context) {
    if (t.documents.isEmpty) {
      return Text(t.isOwner ? 'No documents yet. Add a flyer or rule book from Edit.' : 'No documents for this tournament.',
          style: tfStyle(14, color: Colors.white.withAlpha(140)));
    }
    return Column(
      children: [
        for (final d in t.documents) ...[
          GestureDetector(
            onTap: () => controller.openDocument(d),
            child: Container(
              padding: EdgeInsets.all(SizeConfig.r(12)),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                border: Border.all(color: Colors.white.withAlpha(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: SizeConfig.r(44),
                    height: SizeConfig.r(44),
                    decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(SizeConfig.r(10))),
                    child: Icon(d.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: AppColors.primary, size: SizeConfig.r(22)),
                  ),
                  SizedBox(width: SizeConfig.w(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.title, style: tfStyle(14.5, weight: FontWeight.w700)),
                        Text('${_l(TournamentOptions.docTypes, d.docType)} · ${fileSizeLabel(d.sizeBytes)}',
                            style: tfStyle(12, color: Colors.white.withAlpha(130))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(110)),
                ],
              ),
            ),
          ),
          gapH(10),
        ],
      ],
    );
  }
}

// ─── Bottom bar ─────────────────────────────────────────────────

class _BottomBar extends GetView<TournamentController> {
  final Tournament t;
  const _BottomBar({required this.t});

  @override
  Widget build(BuildContext context) {
    final String label;
    final VoidCallback onTap;
    if (t.isOwner && t.isDraft) {
      label = 'Publish tournament';
      onTap = controller.showPublishSheet;
    } else if (t.isOwner) {
      label = 'Share tournament';
      onTap = () => showTournamentShareSheet(t);
    } else if (t.status == 'REGISTRATION_OPEN') {
      label = 'Register my team';
      onTap = () => showComingSoon('Team registration', detail: 'Captains will be able to register for ${t.name} here very soon.');
    } else {
      label = t.statusLabel;
      onTap = () {};
    }
    return Container(
      padding: EdgeInsets.only(top: SizeConfig.h(12)),
      decoration: BoxDecoration(color: AppColors.secondary, border: Border(top: BorderSide(color: Colors.white.withAlpha(12)))),
      child: SafeArea(
        top: false,
        child: StepBottomButton(key: const ValueKey('tournament-cta'), label: label, onPressed: onTap, loading: controller.isPublishing.value),
      ),
    );
  }
}
