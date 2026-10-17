import '../../scoring/cricket_engine.dart';
import '../../scoring/football_engine.dart';
import '../../scoring/match_engine.dart';
import '../../scoring/racket_engine.dart';

int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
int? _intOrNull(dynamic v) => v == null ? null : _int(v);
String? _str(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

class SquadPlayer {
  final int memberId;
  final int? userId;
  final String name;
  final int? jerseyNumber;
  const SquadPlayer({required this.memberId, this.userId, required this.name, this.jerseyNumber});

  factory SquadPlayer.fromJson(Map<String, dynamic> j) =>
      SquadPlayer(memberId: _int(j['member_id']), userId: _intOrNull(j['user_id']), name: j['name']?.toString() ?? 'Player', jerseyNumber: _intOrNull(j['jersey_number']));
}

class MatchTeam {
  final int entryId;
  final String name;
  final String short;
  final String? logoUrl;
  final List<SquadPlayer> squad;
  const MatchTeam({required this.entryId, required this.name, required this.short, this.logoUrl, this.squad = const []});

  factory MatchTeam.fromJson(Map<String, dynamic> j) => MatchTeam(
        entryId: _int(j['entry_id']),
        name: j['name']?.toString() ?? 'Team',
        short: j['short']?.toString() ?? '',
        logoUrl: _str(j['logo_url']),
        squad: _maps(j['squad']).map(SquadPlayer.fromJson).toList(),
      );
}

class LineupPlayer {
  final int entryId;
  final int memberId;
  final String name;
  final bool captain;
  final bool keeper;
  const LineupPlayer({required this.entryId, required this.memberId, required this.name, this.captain = false, this.keeper = false});

  factory LineupPlayer.fromJson(Map<String, dynamic> j) => LineupPlayer(
        entryId: _int(j['entry_id']),
        memberId: _int(j['member_id']),
        name: j['name']?.toString() ?? 'Player',
        captain: j['captain'] == true,
        keeper: j['keeper'] == true,
      );
}

/// One match with what is needed to watch it, set it up and score it.
class MatchDetail {
  final int id;
  final String tournamentCode;
  final String tournamentName;
  final String sport;
  final String division;
  final Map<String, dynamic> matchRules;
  final String stage;
  final String? label;
  final int? groupNo;
  final int roundNo;
  final int pitch;
  final DateTime? scheduledAt;
  final String status; // SCHEDULED, LIVE, COMPLETED
  final int? tossWinner;
  final String? tossDecision;
  final String? resultText;
  final int? winnerEntryId;
  final MatchTeam? home;
  final MatchTeam? away;
  final List<LineupPlayer> lineups;
  final Map<String, dynamic>? live;
  final int eventCount;
  final bool isOwner;
  final bool canScore;
  final String? lockedBy;
  final List<MatchEvent> events;

  const MatchDetail({
    required this.id,
    required this.tournamentCode,
    required this.tournamentName,
    required this.sport,
    required this.division,
    required this.matchRules,
    required this.stage,
    this.label,
    this.groupNo,
    required this.roundNo,
    required this.pitch,
    this.scheduledAt,
    required this.status,
    this.tossWinner,
    this.tossDecision,
    this.resultText,
    this.winnerEntryId,
    this.home,
    this.away,
    this.lineups = const [],
    this.live,
    required this.eventCount,
    required this.isOwner,
    required this.canScore,
    this.lockedBy,
    this.events = const [],
  });

  bool get isCricket => sport == 'CRICKET';
  bool get isFootball => sport == 'FOOTBALL';
  bool get isRacket => sport == 'BADMINTON' || sport == 'PICKLEBALL';

  /// Cricket needs the toss too; other sports only the players.
  bool get hasSetup => lineups.isNotEmpty && (!isCricket || tossWinner != null);

  Map<int, List<PlayerRef>> get _players => {
        for (final t in [home!, away!])
          t.entryId: [for (final p in lineups.where((p) => p.entryId == t.entryId)) PlayerRef(p.memberId, p.name)],
      };

  /// Replays [events] with this sport's engine.
  EngineState replay(List<MatchEvent> events) {
    if (isFootball) {
      return FootballEngine.replay(
          FootballSetup(homeEntry: home!.entryId, awayEntry: away!.entryId, players: _players, knockout: isKnockout), FootballRules.fromJson(matchRules), events);
    }
    if (isRacket) {
      return RacketEngine.replay(RacketSetup(homeEntry: home!.entryId, awayEntry: away!.entryId, players: _players), RacketRules.fromJson(sport, matchRules), events);
    }
    return CricketEngine.replay(cricketSetup(), cricketRules(), events);
  }
  bool get isKnockout => stage == 'KNOCKOUT';
  String get liveStatus => live?['status']?.toString() ?? 'NOT_STARTED';
  MatchTeam? team(int? entryId) => entryId == null ? null : (home?.entryId == entryId ? home : (away?.entryId == entryId ? away : null));
  String teamName(int? entryId) => team(entryId)?.name ?? 'Team';

  /// Swaps "{12}" placeholders from the scoring engine for team names.
  String fill(String? text) => (text ?? '').replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) => teamName(int.tryParse(m[1]!)));

  CricketSetup cricketSetup() => CricketSetup(
        homeEntry: home!.entryId,
        awayEntry: away!.entryId,
        tossWinner: tossWinner!,
        tossDecision: tossDecision ?? 'BAT',
        players: {
          for (final t in [home!, away!])
            t.entryId: [for (final p in lineups.where((p) => p.entryId == t.entryId)) PlayerRef(p.memberId, p.name)],
        },
        knockout: isKnockout,
      );

  CricketRules cricketRules() => CricketRules.fromJson(matchRules);

  factory MatchDetail.fromJson(Map<String, dynamic> j) => MatchDetail(
        id: _int(j['id']),
        tournamentCode: j['tournament_code']?.toString() ?? '',
        tournamentName: j['tournament_name']?.toString() ?? '',
        sport: j['sport']?.toString() ?? 'CRICKET',
        division: j['division']?.toString() ?? '',
        matchRules: j['match_rules'] is Map ? Map<String, dynamic>.from(j['match_rules'] as Map) : const {},
        stage: j['stage']?.toString() ?? 'GROUP',
        label: _str(j['label']),
        groupNo: _intOrNull(j['group_no']),
        roundNo: _int(j['round_no'], 1),
        pitch: _int(j['pitch'], 1),
        scheduledAt: DateTime.tryParse((j['scheduled_at']?.toString() ?? '').replaceFirst(' ', 'T')),
        status: j['status']?.toString() ?? 'SCHEDULED',
        tossWinner: _intOrNull(j['toss_winner_entry_id']),
        tossDecision: _str(j['toss_decision']),
        resultText: _str(j['result_text']),
        winnerEntryId: _intOrNull(j['winner_entry_id']),
        home: j['home'] is Map ? MatchTeam.fromJson(Map<String, dynamic>.from(j['home'] as Map)) : null,
        away: j['away'] is Map ? MatchTeam.fromJson(Map<String, dynamic>.from(j['away'] as Map)) : null,
        lineups: _maps(j['lineups']).map(LineupPlayer.fromJson).toList(),
        live: j['live'] is Map ? Map<String, dynamic>.from(j['live'] as Map) : null,
        eventCount: _int(j['event_count']),
        isOwner: j['is_owner'] == true,
        canScore: j['can_score'] == true,
        lockedBy: _str(j['scoring_locked_by']),
        events: _maps(j['events']).map(MatchEvent.fromJson).toList(),
      );
}
