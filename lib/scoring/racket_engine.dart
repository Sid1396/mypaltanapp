// Badminton and pickleball scoring: point by point, games and match. Pure Dart, works offline.
//
//   START       {server: entryId}        who serves first
//   POINT       {team: entryId}          the team that won the rally
//   SET_SERVER  {team, server_no?}       correct the server (side-out doubles: 1 or 2)
//   END_MATCH   {winner?, text}          retired, walkover, abandoned
//   UNDO        {}
//
// Rally scoring: the rally winner scores and serves. Side-out scoring (pickleball): only the serving team scores;
// in doubles each side gets two servers (server 1, server 2), except the first service turn of a game.

import 'cricket_engine.dart' show MatchEvent, PlayerRef, ScoringError;
import 'match_engine.dart';

class RacketRules {
  final int pointsPerGame;
  final int games; // best of
  final bool winByTwo;
  final bool sideOut;
  final bool doubles;
  final int? cap; // badminton: 30 at 21 points

  const RacketRules({required this.pointsPerGame, required this.games, this.winByTwo = true, this.sideOut = false, this.doubles = true, this.cap});

  int get gamesToWin => games ~/ 2 + 1;

  factory RacketRules.fromJson(String sport, Map<String, dynamic> r) {
    int i(String k, int d) => r[k] is num ? (r[k] as num).toInt() : d;
    final ppg = i('points_per_game', sport == 'BADMINTON' ? 21 : 11);
    return RacketRules(
      pointsPerGame: ppg,
      games: i('games', 3),
      winByTwo: r['win_by_two'] != false,
      sideOut: sport == 'PICKLEBALL' && (r['scoring'] ?? 'SIDE_OUT') == 'SIDE_OUT',
      doubles: (r['event'] ?? 'DOUBLES') != 'SINGLES',
      cap: sport == 'BADMINTON' ? ppg + 9 : null,
    );
  }
}

class RacketSetup {
  final int homeEntry;
  final int awayEntry;
  final Map<int, List<PlayerRef>> players;
  const RacketSetup({required this.homeEntry, required this.awayEntry, required this.players});
}

class RacketState implements EngineState {
  final RacketSetup setup;
  final RacketRules rules;
  final games = <Map<String, int>>[]; // finished games: {home, away}
  int home = 0, away = 0; // current game
  int? server;
  int serverNo = 2; // side-out doubles: the first service turn of a game has one server
  bool started = false;
  bool finished = false;
  int? winner;
  String? result;
  String? outcome;
  final log = <Map<String, dynamic>>[];

  RacketState(this.setup, this.rules);

  int get gamesHome => games.where((g) => g['home']! > g['away']!).length;
  int get gamesAway => games.where((g) => g['away']! > g['home']!).length;
  int other(int e) => e == setup.homeEntry ? setup.awayEntry : setup.homeEntry;

  @override
  String get status => finished ? 'COMPLETED' : (started ? 'IN_PROGRESS' : 'NOT_STARTED');

  /// Pickleball side-out call: server's score, receiver's score, server number (doubles).
  String? get call {
    if (!rules.sideOut || server == null) return null;
    final s = server == setup.homeEntry ? home : away, r = server == setup.homeEntry ? away : home;
    return rules.doubles ? '$s-$r-$serverNo' : '$s-$r';
  }

  @override
  Map<String, dynamic> toJson() => {
        'sport': 'RACKET',
        'status': status,
        'home_entry_id': setup.homeEntry,
        'away_entry_id': setup.awayEntry,
        'games': games,
        'current': finished ? null : {'home': home, 'away': away, 'game': games.length + 1, 'server': server, 'server_no': rules.sideOut && rules.doubles ? serverNo : null, 'call': call},
        'score': {'home': gamesHome, 'away': gamesAway},
        'points_per_game': rules.pointsPerGame,
        'best_of': rules.games,
        'result': result,
        'winner_entry_id': winner,
        'outcome': outcome,
        'log': log.reversed.take(40).toList(),
        'summary': {
          '${setup.homeEntry}': [for (final g in games) '${g['home']}', if (!finished && started) '$home'].join(' · '),
          '${setup.awayEntry}': [for (final g in games) '${g['away']}', if (!finished && started) '$away'].join(' · '),
        },
      };
}

class RacketEngine {
  static RacketState replay(RacketSetup setup, RacketRules rules, List<MatchEvent> events) {
    final s = RacketState(setup, rules);
    for (final e in effectiveEvents(events)) {
      _apply(s, e);
    }
    return s;
  }

  static int? _id(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

  static void _apply(RacketState s, MatchEvent e) {
    final d = e.data;
    if (s.finished) throw const ScoringError('The match is over.');
    final team = _id(d['team'] ?? d['server']);
    switch (e.type) {
      case 'START':
        if (s.started) throw const ScoringError('The match has already started.');
        if (team != s.setup.homeEntry && team != s.setup.awayEntry) throw const ScoringError('Pick who serves first.');
        s.started = true;
        s.server = team;
        s.serverNo = 2;
      case 'SET_SERVER':
        if (team != s.setup.homeEntry && team != s.setup.awayEntry) throw const ScoringError('Pick the serving team.');
        s.server = team;
        s.serverNo = _id(d['server_no']) ?? 1;
      case 'POINT':
        if (!s.started) throw const ScoringError('Pick who serves first.');
        if (team != s.setup.homeEntry && team != s.setup.awayEntry) throw const ScoringError('Pick the team that won the rally.');
        _point(s, team!);
      case 'END_MATCH':
        s.winner = _id(d['winner']);
        s.result = (d['text']?.toString().trim().isNotEmpty ?? false) ? d['text'].toString().trim() : 'Match ended';
        s.outcome = s.winner != null ? 'WIN' : 'NO_RESULT';
        s.finished = true;
      default:
        throw ScoringError('Unknown event ${e.type}.');
    }
  }

  static void _point(RacketState s, int team) {
    final serving = s.server;
    var scored = true;
    if (s.rules.sideOut) {
      if (team == serving) {
        _add(s, team);
      } else {
        scored = false;
        // Lost the rally while serving: second server, or side out.
        if (s.rules.doubles && s.serverNo == 1) {
          s.serverNo = 2;
        } else {
          s.server = team;
          s.serverNo = 1;
        }
      }
    } else {
      _add(s, team);
      s.server = team;
    }
    s.log.add({'game': s.games.length + 1, 'team': team, 'scored': scored, 'score': '${s.home}-${s.away}', if (s.call != null) 'call': s.call});
    _checkGame(s);
  }

  static void _add(RacketState s, int team) {
    if (team == s.setup.homeEntry) {
      s.home++;
    } else {
      s.away++;
    }
  }

  static void _checkGame(RacketState s) {
    final hi = s.home > s.away ? s.home : s.away, lo = s.home > s.away ? s.away : s.home;
    final capped = s.rules.cap != null && hi >= s.rules.cap!;
    final won = hi >= s.rules.pointsPerGame && (!s.rules.winByTwo || hi - lo >= 2 || capped);
    if (!won) return;
    final gameWinner = s.home > s.away ? s.setup.homeEntry : s.setup.awayEntry;
    s.games.add({'home': s.home, 'away': s.away});
    s.home = 0;
    s.away = 0;
    if (s.gamesHome >= s.rules.gamesToWin || s.gamesAway >= s.rules.gamesToWin) {
      s.finished = true;
      s.winner = s.gamesHome > s.gamesAway ? s.setup.homeEntry : s.setup.awayEntry;
      s.outcome = 'WIN';
      final scores = s.games.map((g) => s.winner == s.setup.homeEntry ? '${g['home']}-${g['away']}' : '${g['away']}-${g['home']}').join(', ');
      s.result = '{${s.winner}} won $scores';
      return;
    }
    // Winner of a game serves first in the next one.
    s.server = gameWinner;
    s.serverNo = 2;
  }
}
