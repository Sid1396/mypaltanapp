// Football scoring: replays the match's events into the score, timeline and result. Pure Dart, works offline.
//
//   KICK_OFF       {at}                                         first half starts (at = phone time, ms)
//   GOAL           {team, scorer?, assist?, own_goal?, penalty?, minute}
//   CARD           {team, player, color: YELLOW|RED, minute}   a second yellow also shows red
//   PERIOD_END     {}                                           half-time, full time, end of an extra-time half
//   START_PERIOD   {at}                                         second half / extra time
//   SHOOTOUT_KICK  {team, taker?, scored}
//   END_MATCH      {winner?, text}                              organiser's decision, abandoned matches
//   UNDO           {}
// Result texts use {entryId} placeholders, like the cricket engine.

import 'cricket_engine.dart' show MatchEvent, PlayerRef, ScoringError;
import 'match_engine.dart';

class FootballRules {
  final int halfMinutes;
  final bool extraTime;
  final bool penalties;
  const FootballRules({required this.halfMinutes, this.extraTime = false, this.penalties = true});

  factory FootballRules.fromJson(Map<String, dynamic> r) => FootballRules(
        halfMinutes: r['half_minutes'] is num ? (r['half_minutes'] as num).toInt() : 20,
        extraTime: r['extra_time'] == true,
        penalties: r['penalties'] != false,
      );

  /// Extra time halves are a third of a half, at least 5 minutes (e.g. 20-minute halves → 2 × 7).
  int get extraHalfMinutes => (halfMinutes / 3).ceil().clamp(5, 15);
}

class FootballSetup {
  final int homeEntry;
  final int awayEntry;
  final Map<int, List<PlayerRef>> players;
  final bool knockout;
  final Map<int, int> keepers; // entry → goalkeeper (team_members.id), for clean sheets
  const FootballSetup({required this.homeEntry, required this.awayEntry, required this.players, this.knockout = false, this.keepers = const {}});
}

/// MVP points used for Player of the Match and Player of the Tournament.
class FootballPoints {
  static const goal = 3, assist = 2, cleanSheet = 3, playerOfMatch = 3, yellow = -1, red = -3;
}

/// NOT_STARTED, FIRST_HALF, HALF_TIME, SECOND_HALF, ET_BREAK, ET_FIRST, ET_HALF, ET_SECOND, PENALTIES, TIE_DECISION, COMPLETED
class FootballState implements EngineState {
  final FootballSetup setup;
  final FootballRules rules;
  String phase = 'NOT_STARTED';
  int home = 0, away = 0;
  int? periodStartedAt;
  final timeline = <Map<String, dynamic>>[];
  final yellows = <int>{};
  final sentOff = <int>{};
  final shootoutHome = <bool>[], shootoutAway = <bool>[];
  int? shootoutFirst;
  int? winner;
  String? result;
  String? outcome;

  FootballState(this.setup, this.rules);

  @override
  String get status => phase == 'COMPLETED' || phase == 'TIE_DECISION' ? phase : (phase == 'NOT_STARTED' ? 'NOT_STARTED' : 'IN_PROGRESS');

  bool get running => const {'FIRST_HALF', 'SECOND_HALF', 'ET_FIRST', 'ET_SECOND'}.contains(phase);

  /// Minutes already played before the current period (for the match clock).
  int get periodOffset => switch (phase) {
        'SECOND_HALF' || 'HALF_TIME' => rules.halfMinutes,
        'ET_FIRST' || 'ET_BREAK' => rules.halfMinutes * 2,
        'ET_SECOND' || 'ET_HALF' => rules.halfMinutes * 2 + rules.extraHalfMinutes,
        _ => 0,
      };

  int get periodLength => phase.startsWith('ET') ? rules.extraHalfMinutes : rules.halfMinutes;

  String nameOf(int? id) {
    if (id == null) return '';
    for (final l in setup.players.values) {
      for (final p in l) {
        if (p.id == id) return p.name;
      }
    }
    return 'Player';
  }

  List<PlayerRef> playersOf(int entry) => setup.players[entry] ?? const [];
  int other(int entry) => entry == setup.homeEntry ? setup.awayEntry : setup.homeEntry;

  /// Goals, assists, cards and clean sheets per player in this match (only players who did something).
  List<Map<String, dynamic>> playerStats() {
    final rows = <int, Map<String, dynamic>>{};
    Map<String, dynamic> row(int id, int team) =>
        rows.putIfAbsent(id, () => {'id': id, 'name': nameOf(id), 'team': team, 'goals': 0, 'assists': 0, 'yellow': 0, 'red': 0, 'clean_sheet': 0});
    for (final e in timeline) {
      final team = e['team'] as int?;
      if (team == null) continue;
      if (e['type'] == 'GOAL' && e['own_goal'] != true) {
        if (e['player_id'] != null) row(e['player_id'] as int, team)['goals']++;
        if (e['assist_id'] != null) row(e['assist_id'] as int, team)['assists']++;
      } else if (e['type'] == 'CARD' && e['player_id'] != null) {
        row(e['player_id'] as int, team)[e['color'] == 'RED' ? 'red' : 'yellow']++;
      }
    }
    // A second yellow is shown as a red; count it once as a red, like a referee's report.
    for (final r in rows.values) {
      if (r['red'] > 0 && r['yellow'] > 1) r['yellow'] = 1;
    }
    if (phase == 'COMPLETED' && outcome != 'NO_RESULT') {
      for (final entry in [setup.homeEntry, setup.awayEntry]) {
        final keeper = setup.keepers[entry];
        final conceded = entry == setup.homeEntry ? away : home;
        if (keeper != null && conceded == 0) row(keeper, entry)['clean_sheet'] = 1;
      }
    }
    for (final r in rows.values) {
      r['points'] = r['goals'] * FootballPoints.goal + r['assists'] * FootballPoints.assist + r['clean_sheet'] * FootballPoints.cleanSheet +
          r['yellow'] * FootballPoints.yellow + r['red'] * FootballPoints.red;
    }
    return rows.values.toList();
  }

  /// Highest MVP points; ties go to the winning team, then more goals. Null when nobody earned points.
  Map<String, dynamic>? playerOfMatch() {
    final rows = playerStats().where((r) => (r['points'] as int) > 0).toList();
    if (rows.isEmpty) return null;
    rows.sort((a, b) {
      final p = (b['points'] as int).compareTo(a['points'] as int);
      if (p != 0) return p;
      final w = (b['team'] == winner ? 1 : 0).compareTo(a['team'] == winner ? 1 : 0);
      if (w != 0) return w;
      return (b['goals'] as int).compareTo(a['goals'] as int);
    });
    final top = rows.first;
    final why = [
      if (top['goals'] > 0) '${top['goals']} goal${top['goals'] == 1 ? '' : 's'}',
      if (top['assists'] > 0) '${top['assists']} assist${top['assists'] == 1 ? '' : 's'}',
      if (top['clean_sheet'] > 0) 'clean sheet',
    ].join(', ');
    return {'id': top['id'], 'name': top['name'], 'team': top['team'], 'points': top['points'], 'reason': why};
  }

  int get shootoutGoalsHome => shootoutHome.where((x) => x).length;
  int get shootoutGoalsAway => shootoutAway.where((x) => x).length;

  /// Team to take the next penalty in the shootout.
  int? get nextKicker {
    if (phase != 'PENALTIES' || shootoutFirst == null) return null;
    final first = shootoutFirst!, second = other(first);
    final a = first == setup.homeEntry ? shootoutHome : shootoutAway;
    final b = first == setup.homeEntry ? shootoutAway : shootoutHome;
    return a.length <= b.length ? first : second;
  }

  @override
  Map<String, dynamic> toJson() => {
        'sport': 'FOOTBALL',
        'status': status,
        'phase': phase,
        'score': {'home': home, 'away': away},
        'home_entry_id': setup.homeEntry,
        'away_entry_id': setup.awayEntry,
        'period_started_at': running ? periodStartedAt : null,
        'period_offset': periodOffset,
        'period_minutes': periodLength,
        'half_minutes': rules.halfMinutes,
        'timeline': timeline.reversed.toList(),
        if (shootoutHome.isNotEmpty || shootoutAway.isNotEmpty || phase == 'PENALTIES')
          'shootout': {'home': shootoutHome, 'away': shootoutAway, 'first': shootoutFirst, 'next': nextKicker},
        'result': result,
        'winner_entry_id': winner,
        'outcome': outcome,
        'player_stats': playerStats(),
        if (phase == 'COMPLETED') 'potm': playerOfMatch(),
        'summary': {
          '${setup.homeEntry}': shootoutHome.isEmpty ? '$home' : '$home ($shootoutGoalsHome)',
          '${setup.awayEntry}': shootoutAway.isEmpty ? '$away' : '$away ($shootoutGoalsAway)',
        },
      };
}

class FootballEngine {
  static FootballState replay(FootballSetup setup, FootballRules rules, List<MatchEvent> events) {
    final s = FootballState(setup, rules);
    for (final e in effectiveEvents(events)) {
      _apply(s, e);
    }
    return s;
  }

  static int? _id(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

  static void _team(FootballState s, int? team) {
    if (team != s.setup.homeEntry && team != s.setup.awayEntry) throw const ScoringError('Pick a team.');
  }

  static void _apply(FootballState s, MatchEvent e) {
    final d = e.data;
    if (s.phase == 'COMPLETED' && e.type != 'END_MATCH') throw const ScoringError('The match is over.');
    switch (e.type) {
      case 'KICK_OFF':
        if (s.phase != 'NOT_STARTED') throw const ScoringError('The match has already started.');
        s.phase = 'FIRST_HALF';
        s.periodStartedAt = _id(d['at']);
        s.timeline.add({'minute': 0, 'type': 'KICK_OFF', 'text': 'Kick-off'});
      case 'GOAL':
        if (!s.running) throw const ScoringError('Goals can only be scored while the ball is in play.');
        final team = _id(d['team']);
        _team(s, team);
        final own = d['own_goal'] == true;
        // An own goal counts for the team that benefits ("team" is the team credited with the goal).
        if (team == s.setup.homeEntry) {
          s.home++;
        } else {
          s.away++;
        }
        final scorer = _id(d['scorer']);
        final assist = _id(d['assist']);
        if (scorer != null && s.sentOff.contains(scorer)) throw const ScoringError('That player has been sent off.');
        s.timeline.add({
          'minute': _id(d['minute']) ?? 0,
          'type': 'GOAL',
          'team': team,
          'player': scorer == null ? null : s.nameOf(scorer),
          'player_id': scorer,
          if (assist != null) 'assist': s.nameOf(assist),
          if (assist != null) 'assist_id': assist,
          if (own) 'own_goal': true,
          if (d['penalty'] == true) 'penalty': true,
          'score': '${s.home}-${s.away}',
          'text': '${own ? 'Own goal' : 'GOAL'}${scorer == null ? '' : ' · ${s.nameOf(scorer)}'}${d['penalty'] == true ? ' (pen)' : ''}',
        });
      case 'CARD':
        if (s.phase == 'NOT_STARTED' || s.phase == 'PENALTIES') throw const ScoringError('Cards can be given during the match.');
        final team = _id(d['team']);
        _team(s, team);
        final player = _id(d['player']);
        if (player == null || !s.playersOf(team!).any((p) => p.id == player)) throw const ScoringError('Pick the player.');
        if (s.sentOff.contains(player)) throw const ScoringError('That player has already been sent off.');
        final red = d['color'] == 'RED';
        final second = !red && s.yellows.contains(player);
        if (red || second) {
          s.sentOff.add(player);
        } else {
          s.yellows.add(player);
        }
        s.timeline.add({
          'minute': _id(d['minute']) ?? 0,
          'type': 'CARD',
          'team': team,
          'player': s.nameOf(player),
          'player_id': player,
          'color': red || second ? 'RED' : 'YELLOW',
          'text': red ? 'Red card' : (second ? 'Second yellow, sent off' : 'Yellow card'),
        });
      case 'PERIOD_END':
        _periodEnd(s);
      case 'START_PERIOD':
        final next = {'HALF_TIME': 'SECOND_HALF', 'ET_BREAK': 'ET_FIRST', 'ET_HALF': 'ET_SECOND'}[s.phase];
        if (next == null) throw const ScoringError('No period to start now.');
        s.phase = next;
        s.periodStartedAt = _id(d['at']);
        s.timeline.add({'minute': s.periodOffset, 'type': 'PERIOD', 'text': next == 'SECOND_HALF' ? 'Second half' : 'Extra time'});
      case 'SHOOTOUT_KICK':
        if (s.phase != 'PENALTIES') throw const ScoringError('There is no penalty shootout.');
        final team = _id(d['team']);
        _team(s, team);
        s.shootoutFirst ??= team;
        if (team != s.nextKicker) throw const ScoringError('The other team takes this penalty.');
        final scored = d['scored'] == true;
        (team == s.setup.homeEntry ? s.shootoutHome : s.shootoutAway).add(scored);
        final taker = _id(d['taker']);
        s.timeline.add({'type': 'SHOOTOUT', 'team': team, 'player': taker == null ? null : s.nameOf(taker), 'scored': scored, 'text': scored ? 'Penalty scored' : 'Penalty missed'});
        _checkShootout(s);
      case 'END_MATCH':
        if (s.phase == 'COMPLETED') throw const ScoringError('The match is already over.');
        s.winner = _id(d['winner']);
        s.result = (d['text']?.toString().trim().isNotEmpty ?? false) ? d['text'].toString().trim() : 'Match ended';
        s.outcome = s.winner != null ? 'WIN' : (s.phase == 'NOT_STARTED' ? 'NO_RESULT' : (s.home == s.away ? 'TIE' : 'NO_RESULT'));
        s.phase = 'COMPLETED';
      default:
        throw ScoringError('Unknown event ${e.type}.');
    }
  }

  static void _periodEnd(FootballState s) {
    switch (s.phase) {
      case 'FIRST_HALF':
        s.phase = 'HALF_TIME';
        s.timeline.add({'minute': s.rules.halfMinutes, 'type': 'PERIOD', 'text': 'Half-time'});
      case 'SECOND_HALF':
        s.timeline.add({'minute': s.rules.halfMinutes * 2, 'type': 'PERIOD', 'text': 'Full time'});
        _afterRegularTime(s, extraTimeAllowed: true);
      case 'ET_FIRST':
        s.phase = 'ET_HALF';
        s.timeline.add({'minute': s.periodOffset, 'type': 'PERIOD', 'text': 'Extra time half-time'});
      case 'ET_SECOND':
        s.timeline.add({'minute': s.periodOffset + s.rules.extraHalfMinutes, 'type': 'PERIOD', 'text': 'End of extra time'});
        _afterRegularTime(s, extraTimeAllowed: false);
      default:
        throw const ScoringError('The ball is not in play.');
    }
  }

  static void _afterRegularTime(FootballState s, {required bool extraTimeAllowed}) {
    if (s.home != s.away) return _finish(s, s.home > s.away ? s.setup.homeEntry : s.setup.awayEntry, 'WIN');
    if (!s.setup.knockout) {
      s.phase = 'COMPLETED';
      s.result = 'Match drawn ${s.home}-${s.away}';
      s.outcome = 'TIE';
      return;
    }
    if (extraTimeAllowed && s.rules.extraTime) {
      s.phase = 'ET_BREAK';
    } else if (s.rules.penalties) {
      s.phase = 'PENALTIES';
    } else {
      s.phase = 'TIE_DECISION';
      s.result = 'Scores level. Record the winner.';
    }
  }

  static void _finish(FootballState s, int winner, String outcome) {
    final loser = s.other(winner);
    final w = winner == s.setup.homeEntry ? s.home : s.away, l = loser == s.setup.homeEntry ? s.home : s.away;
    s.winner = winner;
    s.outcome = outcome;
    s.phase = 'COMPLETED';
    s.result = '{$winner} won $w-$l';
  }

  /// Best of five each, then sudden death; decided as soon as one side cannot catch up.
  static void _checkShootout(FootballState s) {
    final h = s.shootoutGoalsHome, a = s.shootoutGoalsAway;
    final hk = s.shootoutHome.length, ak = s.shootoutAway.length;
    int? winner;
    if (hk <= 5 && ak <= 5) {
      if (h > a + (5 - ak)) winner = s.setup.homeEntry;
      if (a > h + (5 - hk)) winner = s.setup.awayEntry;
    } else if (hk == ak && h != a) {
      winner = h > a ? s.setup.homeEntry : s.setup.awayEntry;
    }
    if (hk == 5 && ak == 5 && h != a) winner = h > a ? s.setup.homeEntry : s.setup.awayEntry;
    if (winner == null) return;
    s.winner = winner;
    s.outcome = 'WIN';
    s.phase = 'COMPLETED';
    final wp = winner == s.setup.homeEntry ? h : a, lp = winner == s.setup.homeEntry ? a : h;
    s.result = '{$winner} won $wp-$lp on penalties (${s.home}-${s.away})';
  }
}
