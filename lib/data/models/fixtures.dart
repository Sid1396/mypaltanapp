int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
int? _intOrNull(dynamic v) => v == null ? null : _int(v);
String? _str(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

/// '2026-11-20 09:00' → local DateTime (fixture times are the venue's local time).
DateTime? parseFixtureTime(String? s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})').firstMatch(s ?? '');
  return m == null ? null : DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!), int.parse(m[5]!));
}

String fixtureTimeString(DateTime d) {
  String p(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
}

const groupLetters = 'ABCDEFGHIJKLMNOP';

class FixtureTeam {
  final int entryId;
  final String teamCode;
  final String name;
  final String short;
  final String? logoUrl;
  final int? groupNo;
  final int? seed;

  const FixtureTeam({required this.entryId, required this.teamCode, required this.name, required this.short, this.logoUrl, this.groupNo, this.seed});

  factory FixtureTeam.fromJson(Map<String, dynamic> j) => FixtureTeam(
        entryId: _int(j['entry_id']),
        teamCode: j['team_code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        short: j['short']?.toString() ?? '',
        logoUrl: _str(j['logo_url']),
        groupNo: _intOrNull(j['group_no']),
        seed: _intOrNull(j['seed']),
      );
}

/// One team's line in a points table.
class StandingRow {
  final int entryId;
  final int position;
  final int played, won, lost, tied, noResult, points;
  final double nrr;
  final int goalDiff;

  const StandingRow({
    required this.entryId,
    required this.position,
    required this.played,
    required this.won,
    required this.lost,
    required this.tied,
    required this.noResult,
    required this.points,
    required this.nrr,
    required this.goalDiff,
  });

  factory StandingRow.fromJson(Map<String, dynamic> j) => StandingRow(
        entryId: _int(j['entry_id']),
        position: _int(j['position']),
        played: _int(j['played']),
        won: _int(j['won']),
        lost: _int(j['lost']),
        tied: _int(j['tied']),
        noResult: _int(j['no_result']),
        points: _int(j['points']),
        nrr: (j['nrr'] as num?)?.toDouble() ?? 0,
        goalDiff: _int(j['goal_diff']),
      );
}

class GroupStanding {
  final int groupNo;
  final bool complete;
  final List<StandingRow> rows;
  const GroupStanding({required this.groupNo, required this.complete, required this.rows});

  factory GroupStanding.fromJson(Map<String, dynamic> j) => GroupStanding(
        groupNo: _int(j['group_no'], 1),
        complete: j['complete'] == true,
        rows: _maps(j['rows']).map(StandingRow.fromJson).toList(),
      );
}

class FixtureMatch {
  final int id;
  final int divisionId;
  final int matchNo;
  final String stage; // GROUP, KNOCKOUT
  final int? groupNo;
  final int roundNo;
  final String? label;
  final int? homeEntryId;
  final int? awayEntryId;
  final String? homeLabel; // '1st Group A', 'Winner Semi-final 1' while the team is unknown
  final String? awayLabel;
  final int pitch;
  final DateTime at;
  final String status;
  final int? homeScore;
  final int? awayScore;
  final String? resultText;
  final int? winnerEntryId;
  final Map<String, String> summary; // entry id → "124/5 (12.3)"

  const FixtureMatch({
    required this.id,
    required this.divisionId,
    required this.matchNo,
    required this.stage,
    this.groupNo,
    required this.roundNo,
    this.label,
    this.homeEntryId,
    this.awayEntryId,
    this.homeLabel,
    this.awayLabel,
    required this.pitch,
    required this.at,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.resultText,
    this.winnerEntryId,
    this.summary = const {},
  });

  bool get isLive => status == 'LIVE';
  bool get isDone => status == 'COMPLETED';
  String? scoreOf(int? entry) => entry == null ? null : summary['$entry'];

  bool get isKnockout => stage == 'KNOCKOUT';
  bool involves(Set<int> entries) => entries.contains(homeEntryId) || entries.contains(awayEntryId);

  /// 'Group A · Round 2' or 'Final'.
  String stageLabel(int groups) =>
      isKnockout ? (label ?? 'Knockout') : '${groups > 1 && groupNo != null ? 'Group ${groupLetters[groupNo! - 1]} · ' : ''}Round $roundNo';

  factory FixtureMatch.fromJson(Map<String, dynamic> j, int divisionId) => FixtureMatch(
        id: _int(j['id']),
        divisionId: divisionId,
        matchNo: _int(j['match_no']),
        stage: j['stage']?.toString() ?? 'GROUP',
        groupNo: _intOrNull(j['group_no']),
        roundNo: _int(j['round_no'], 1),
        label: _str(j['label']),
        homeEntryId: _intOrNull(j['home_entry_id']),
        awayEntryId: _intOrNull(j['away_entry_id']),
        homeLabel: _str(j['home_label']),
        awayLabel: _str(j['away_label']),
        pitch: _int(j['pitch'], 1),
        at: parseFixtureTime(j['scheduled_at']?.toString()) ?? DateTime(2000),
        status: j['status']?.toString() ?? 'SCHEDULED',
        homeScore: _intOrNull(j['home_score']),
        awayScore: _intOrNull(j['away_score']),
        resultText: _str(j['result_text']),
        winnerEntryId: _intOrNull(j['winner_entry_id']),
        summary: j['summary'] is Map ? (j['summary'] as Map).map((k, v) => MapEntry('$k', '$v')) : const {},
      );
}

/// The organiser's saved schedule settings for a division.
class FixtureSettings {
  final DateTime? start; // null = straight after the previous division
  final int? pitches;
  final int? gapMinutes;
  final String? draw;

  const FixtureSettings({this.start, this.pitches, this.gapMinutes, this.draw});

  factory FixtureSettings.fromJson(Map<String, dynamic> j) => FixtureSettings(
        start: parseFixtureTime(j['start']?.toString()),
        pitches: _intOrNull(j['pitches']),
        gapMinutes: _intOrNull(j['gap_minutes']),
        draw: _str(j['draw']),
      );
}

class FixtureDivision {
  final int id;
  final String name;
  final String format; // LEAGUE, KNOCKOUT, LEAGUE_KNOCKOUT
  final int? groupCount;
  final int? qualifyPerGroup;
  final Map<String, dynamic> matchRules;
  final FixtureSettings? settings;
  final List<FixtureTeam> teams;
  final List<FixtureMatch> matches;
  final List<GroupStanding> standings;

  const FixtureDivision({
    required this.id,
    required this.name,
    required this.format,
    this.groupCount,
    this.qualifyPerGroup,
    required this.matchRules,
    this.settings,
    required this.teams,
    required this.matches,
    this.standings = const [],
  });

  /// Places per group that go through to the knockouts (0 when there are none).
  int get qualifiersPerGroup => matches.any((m) => m.isKnockout) ? (qualifyPerGroup ?? (groupsInSchedule == 1 ? 2 : 1)) : 0;

  /// Groups the server will make for [teamCount] confirmed teams (0 for straight knockouts).
  int groupsFor(int teamCount) => format == 'KNOCKOUT'
      ? 0
      : format == 'LEAGUE'
          ? 1
          : ((groupCount ?? 1).clamp(1, (teamCount ~/ 2).clamp(1, 16)));

  int get groupsInSchedule => matches.map((m) => m.groupNo ?? 0).fold(1, (a, b) => a > b ? a : b);

  factory FixtureDivision.fromJson(Map<String, dynamic> j) {
    final id = _int(j['id']);
    return FixtureDivision(
      id: id,
      name: j['name']?.toString() ?? '',
      format: j['format']?.toString() ?? 'LEAGUE',
      groupCount: _intOrNull(j['group_count']),
      qualifyPerGroup: _intOrNull(j['qualify_per_group']),
      matchRules: j['match_rules'] is Map ? Map<String, dynamic>.from(j['match_rules'] as Map) : const {},
      settings: j['settings'] is Map ? FixtureSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)) : null,
      teams: _maps(j['teams']).map(FixtureTeam.fromJson).toList(),
      matches: _maps(j['matches']).map((m) => FixtureMatch.fromJson(m, id)).toList(),
      standings: _maps(j['standings']).map(GroupStanding.fromJson).toList(),
    );
  }
}

class Fixtures {
  final String code;
  final String name;
  final String status;
  final bool isOwner;
  final bool published;
  final DateTime startDate;
  final DateTime endDate;
  final String? dayStart;
  final String? dayEnd;
  final List<FixtureDivision> divisions;
  final Set<int> myEntryIds;
  final bool teamsChanged;

  const Fixtures({
    required this.code,
    required this.name,
    required this.status,
    required this.isOwner,
    required this.published,
    required this.startDate,
    required this.endDate,
    this.dayStart,
    this.dayEnd,
    required this.divisions,
    required this.myEntryIds,
    required this.teamsChanged,
  });

  bool get hasMatches => divisions.any((d) => d.matches.isNotEmpty);
  List<FixtureMatch> get allMatches => [for (final d in divisions) ...d.matches]..sort((a, b) => a.at.compareTo(b.at) != 0 ? a.at.compareTo(b.at) : a.pitch.compareTo(b.pitch));
  FixtureDivision? divisionOf(FixtureMatch m) => divisions.where((d) => d.id == m.divisionId).firstOrNull;
  FixtureTeam? team(int? entryId) => entryId == null ? null : divisions.expand((d) => d.teams).where((t) => t.entryId == entryId).firstOrNull;

  /// The next match of one of the user's teams that has not been played yet.
  FixtureMatch? get myNextMatch {
    if (myEntryIds.isEmpty) return null;
    final now = DateTime.now().subtract(const Duration(minutes: 30));
    return allMatches.where((m) => m.involves(myEntryIds) && m.status != 'COMPLETED' && m.at.isAfter(now)).firstOrNull;
  }

  factory Fixtures.fromJson(Map<String, dynamic> j) => Fixtures(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        isOwner: j['is_owner'] == true,
        published: j['published'] == true,
        startDate: DateTime.tryParse(j['start_date']?.toString() ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(j['end_date']?.toString() ?? '') ?? DateTime.now(),
        dayStart: _str(j['day_start']),
        dayEnd: _str(j['day_end']),
        divisions: _maps(j['divisions']).map(FixtureDivision.fromJson).toList(),
        myEntryIds: (j['my_entry_ids'] as List? ?? []).map((v) => _int(v)).toSet(),
        teamsChanged: j['teams_changed'] == true,
      );
}
