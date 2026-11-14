int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
int? _intOrNull(dynamic v) => v == null ? null : _int(v);
String? _str(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

class QuickPlayer {
  final int? userId;
  final String name;
  const QuickPlayer({this.userId, required this.name});

  factory QuickPlayer.fromJson(Map<String, dynamic> j) => QuickPlayer(userId: _intOrNull(j['user_id']), name: j['name']?.toString() ?? 'Player');
}

/// One team of a quick match: HOME or AWAY.
class QuickSide {
  final String side;
  final int entryId;
  final String teamCode;
  final String name;
  final String short;
  final int? captainId;
  final String? captainName;
  final List<QuickPlayer> players;
  final String link; // team link players open to join this side

  const QuickSide({
    required this.side,
    required this.entryId,
    required this.teamCode,
    required this.name,
    required this.short,
    this.captainId,
    this.captainName,
    this.players = const [],
    required this.link,
  });

  factory QuickSide.fromJson(Map<String, dynamic> j) {
    final cap = j['captain'] is Map ? Map<String, dynamic>.from(j['captain'] as Map) : null;
    return QuickSide(
      side: j['side']?.toString() ?? 'HOME',
      entryId: _int(j['entry_id']),
      teamCode: j['team_code']?.toString() ?? '',
      name: j['name']?.toString() ?? 'Team',
      short: j['short']?.toString() ?? '',
      captainId: _intOrNull(cap?['user_id']),
      captainName: _str(cap?['name']),
      players: _maps(j['players']).map(QuickPlayer.fromJson).toList(),
      link: j['link']?.toString() ?? '',
    );
  }
}

/// Someone who tapped "I'm in"; [side] is the team they joined, if any.
class QuickPerson {
  final int userId;
  final String name;
  final String? side;
  const QuickPerson({required this.userId, required this.name, this.side});

  factory QuickPerson.fromJson(Map<String, dynamic> j) =>
      QuickPerson(userId: _int(j['user_id']), name: j['name']?.toString() ?? 'Player', side: _str(j['side']));
}

/// A quick match: a friendly game made by one person and shared as a link (stored as a private 1-match tournament).
class QuickMatch {
  final String code;
  final String sport;
  final String name;
  final String status; // tournament status: REGISTRATION_OPEN, LIVE, COMPLETED, CANCELLED
  final String ground;
  final String? scheduledAt; // India time "YYYY-MM-DD HH:mm"
  final Map<String, dynamic> rules;
  final int squadMax;
  final int creatorId;
  final String creatorName;
  final int matchId;
  final String matchStatus; // SCHEDULED, LIVE, COMPLETED, CANCELLED
  final bool started;
  final String? resultText;
  final int? winnerEntryId;
  final Map<String, String> summary; // entry id → "120/4 (6)" or "2"
  final String link;
  final List<QuickSide> sides;
  final List<QuickPerson> people;
  final int myUserId;
  final bool isCreator;
  final String? mySide;
  final String? captainOf;
  final bool inList;
  final String? scoringPin; // creator and captains only

  const QuickMatch({
    required this.code,
    required this.sport,
    required this.name,
    required this.status,
    required this.ground,
    this.scheduledAt,
    this.rules = const {},
    required this.squadMax,
    required this.creatorId,
    required this.creatorName,
    required this.matchId,
    required this.matchStatus,
    required this.started,
    this.resultText,
    this.winnerEntryId,
    this.summary = const {},
    required this.link,
    this.sides = const [],
    this.people = const [],
    required this.myUserId,
    required this.isCreator,
    this.mySide,
    this.captainOf,
    required this.inList,
    this.scoringPin,
  });

  bool get isCancelled => status == 'CANCELLED' || matchStatus == 'CANCELLED';
  bool get isCompleted => matchStatus == 'COMPLETED';

  /// Before the first ball / kick-off: people can still join and captains can change.
  bool get isOpen => matchStatus == 'SCHEDULED' && !started && !isCancelled;
  bool get isLead => isCreator || captainOf != null;

  /// Badminton / pickleball: 1 or 2 per team. Cricket and football: as many as the creator puts in.
  int? get perSide => sport == 'CRICKET' || sport == 'FOOTBALL' ? null : (rules['event'] == 'SINGLES' ? 1 : 2);

  /// "7 players" (cricket, football) or "1/2" (doubles).
  String countText(QuickSide s) {
    final n = s.players.length, per = perSide;
    return per != null ? '$n/$per' : '$n player${n == 1 ? '' : 's'}';
  }

  /// Players each team needs before the match can start (the server's rule for squads / Playing XI).
  int get minPlayers => sport == 'CRICKET' || sport == 'FOOTBALL' ? 2 : 1;
  bool get canStart => sides.length == 2 && sides.every((s) => s.players.length >= minPlayers);

  QuickSide? sideOf(String side) {
    for (final s in sides) {
      if (s.side == side) return s;
    }
    return null;
  }

  QuickSide? get home => sideOf('HOME');
  QuickSide? get away => sideOf('AWAY');

  String scoreOf(QuickSide s) => summary['${s.entryId}'] ?? '';

  /// Swaps "{12}" placeholders from the scoring engine for team names.
  String fill(String? text) => (text ?? '').replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) {
        final id = int.tryParse(m[1]!);
        for (final s in sides) {
          if (s.entryId == id) return s.name;
        }
        return 'Team';
      });

  /// "6 overs", "6 overs · last man stands", "10 min halves", "Doubles · 3 games to 21".
  String get rulesText {
    int r(String k, int d) => _int(rules[k], d);
    return switch (sport) {
      'CRICKET' => '${r('overs', 6)} overs${rules['last_batter'] == true ? ' · last man stands' : ''}',
      'FOOTBALL' => '${r('half_minutes', 10)} min halves',
      _ =>
        '${rules['event'] == 'SINGLES' ? 'Singles' : 'Doubles'} · ${r('games', 1) == 1 ? '1 game' : '${r('games', 3)} games'} to ${r('points_per_game', 21)}',
    };
  }

  factory QuickMatch.fromJson(Map<String, dynamic> j) {
    final me = j['me'] is Map ? Map<String, dynamic>.from(j['me'] as Map) : const <String, dynamic>{};
    final creator = j['creator'] is Map ? Map<String, dynamic>.from(j['creator'] as Map) : const <String, dynamic>{};
    final summary = j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : const <String, dynamic>{};
    return QuickMatch(
      code: j['code']?.toString() ?? '',
      sport: j['sport']?.toString() ?? 'CRICKET',
      name: j['name']?.toString() ?? '',
      status: j['status']?.toString() ?? '',
      ground: j['ground']?.toString() ?? '',
      scheduledAt: _str(j['scheduled_at']),
      rules: j['rules'] is Map ? Map<String, dynamic>.from(j['rules'] as Map) : const {},
      squadMax: _int(j['squad_max'], 11),
      creatorId: _int(creator['user_id']),
      creatorName: creator['name']?.toString() ?? '',
      matchId: _int(j['match_id']),
      matchStatus: j['match_status']?.toString() ?? 'SCHEDULED',
      started: j['started'] == true,
      resultText: _str(j['result_text']),
      winnerEntryId: _intOrNull(j['winner_entry_id']),
      summary: summary.map((k, v) => MapEntry(k, '$v')),
      link: j['link']?.toString() ?? '',
      sides: _maps(j['sides']).map(QuickSide.fromJson).toList(),
      people: _maps(j['people']).map(QuickPerson.fromJson).toList(),
      myUserId: _int(me['user_id']),
      isCreator: me['is_creator'] == true,
      mySide: _str(me['side']),
      captainOf: _str(me['captain_of']),
      inList: me['in_list'] == true,
      scoringPin: _str(j['scoring_pin']),
    );
  }
}

/// A row in Tournaments → Quick matches.
class MyQuickMatch {
  final String code;
  final String sport;
  final String status;
  final String ground;
  final bool isCreator;
  final String matchStatus;
  final String? scheduledAt;
  final String homeName;
  final String? homeScore;
  final String awayName;
  final String? awayScore;
  final String? resultText;

  const MyQuickMatch({
    required this.code,
    required this.sport,
    required this.status,
    required this.ground,
    required this.isCreator,
    required this.matchStatus,
    this.scheduledAt,
    required this.homeName,
    this.homeScore,
    required this.awayName,
    this.awayScore,
    this.resultText,
  });

  factory MyQuickMatch.fromJson(Map<String, dynamic> j) {
    final h = j['home'] is Map ? Map<String, dynamic>.from(j['home'] as Map) : const <String, dynamic>{};
    final a = j['away'] is Map ? Map<String, dynamic>.from(j['away'] as Map) : const <String, dynamic>{};
    return MyQuickMatch(
      code: j['code']?.toString() ?? '',
      sport: j['sport']?.toString() ?? 'CRICKET',
      status: j['status']?.toString() ?? '',
      ground: j['ground']?.toString() ?? '',
      isCreator: j['is_creator'] == true,
      matchStatus: j['match_status']?.toString() ?? 'SCHEDULED',
      scheduledAt: _str(j['scheduled_at']),
      homeName: h['name']?.toString() ?? 'Team A',
      homeScore: _str(h['score']),
      awayName: a['name']?.toString() ?? 'Team B',
      awayScore: _str(a['score']),
      resultText: _str(j['result_text']),
    );
  }
}
