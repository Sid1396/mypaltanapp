// Ball-by-ball cricket scoring. Pure Dart: runs on the scorer's phone (works offline) and replays the
// same event list on any other phone, so every device ends up with the same scorecard.
//
// Result texts use {entryId} placeholders (e.g. "{12} won by 4 wickets"); callers swap in team names.
//
// A match is a list of events, applied in order:
//   START_INNINGS {striker, non_striker, bowler}
//   BALL          {runs, extra: NONE|WIDE|NO_BALL|BYE|LEG_BYE, boundary?, nb_byes?, wicket?: {how, out, fielder?}}
//   NEW_BATTER    {id, position: STRIKER|NON_STRIKER}
//   NEW_BOWLER    {id}
//   SWAP_STRIKE   {}
//   RETIRE        {id, out: bool}          retired hurt (can come back) or retired out
//   END_INNINGS   {reason}
//   END_MATCH     {winner?: entryId, text}  ties in knockouts, abandoned matches
//   UNDO          {}                        cancels the latest event that is still in effect

class ScoringError implements Exception {
  final String message;
  const ScoringError(this.message);
  @override
  String toString() => message;
}

class CricketRules {
  final int overs;
  final int playersPerSide;
  final int oversPerBowler;
  final int wideRuns;
  final int noBallRuns;
  final bool freeHit;
  final bool lastManStands;

  const CricketRules({
    required this.overs,
    required this.playersPerSide,
    required this.oversPerBowler,
    this.wideRuns = 1,
    this.noBallRuns = 1,
    this.freeHit = true,
    this.lastManStands = false,
  });

  /// Wickets that end an innings (with last man stands the last batter bats alone).
  int get allOutAt => lastManStands ? playersPerSide : playersPerSide - 1;

  factory CricketRules.fromJson(Map<String, dynamic> r) {
    int i(String k, int d) => r[k] is num ? (r[k] as num).toInt() : int.tryParse('${r[k] ?? ''}') ?? d;
    final overs = i('overs', 10);
    return CricketRules(
      overs: overs,
      playersPerSide: i('players_per_side', 11).clamp(2, 11),
      oversPerBowler: i('overs_per_bowler', (overs / 5).ceil()).clamp(1, overs),
      wideRuns: i('wide_runs', 1).clamp(0, 5),
      noBallRuns: i('no_ball_runs', 1).clamp(0, 5),
      freeHit: r['free_hit'] != false,
      lastManStands: r['last_man_stands'] == true || r['last_batter'] == true,
    );
  }
}

class PlayerRef {
  final int id; // team_members.id
  final String name;
  const PlayerRef(this.id, this.name);
}

class CricketSetup {
  final int homeEntry;
  final int awayEntry;
  final int tossWinner;
  final String tossDecision; // BAT or BOWL
  final Map<int, List<PlayerRef>> players; // entry id → playing XI
  final bool knockout;

  const CricketSetup({
    required this.homeEntry,
    required this.awayEntry,
    required this.tossWinner,
    required this.tossDecision,
    required this.players,
    this.knockout = false,
  });

  int get firstBatting => tossDecision == 'BAT' ? tossWinner : (tossWinner == homeEntry ? awayEntry : homeEntry);
  int other(int entry) => entry == homeEntry ? awayEntry : homeEntry;
}

class MatchEvent {
  final String clientId;
  final String type;
  final Map<String, dynamic> data;
  const MatchEvent(this.clientId, this.type, [this.data = const {}]);

  Map<String, dynamic> toJson() => {'client_id': clientId, 'type': type, 'data': data};
  factory MatchEvent.fromJson(Map<String, dynamic> j) =>
      MatchEvent(j['client_id'].toString(), j['type'].toString(), j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : const {});
}

class BatterCard {
  final int id;
  final String name;
  final int order;
  int runs = 0, balls = 0, fours = 0, sixes = 0;
  bool out = false;
  bool retiredHurt = false;
  String? howOut;
  BatterCard(this.id, this.name, this.order);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'runs': runs,
        'balls': balls,
        'fours': fours,
        'sixes': sixes,
        'out': out,
        'how_out': howOut ?? (retiredHurt ? 'retired hurt' : 'not out'),
        'strike_rate': balls == 0 ? 0 : double.parse((runs * 100 / balls).toStringAsFixed(1)),
      };
}

class BowlerCard {
  final int id;
  final String name;
  int legalBalls = 0, runs = 0, wickets = 0, maidens = 0, wides = 0, noBalls = 0, dots = 0;
  BowlerCard(this.id, this.name);

  String get overs => '${legalBalls ~/ 6}.${legalBalls % 6}';
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'overs': overs,
        'legal_balls': legalBalls,
        'maidens': maidens,
        'runs': runs,
        'wickets': wickets,
        'wides': wides,
        'no_balls': noBalls,
        'dots': dots,
        'economy': legalBalls == 0 ? 0 : double.parse((runs * 6 / legalBalls).toStringAsFixed(2)),
      };
}

class Innings {
  final int no;
  final int batting;
  final int bowling;
  final int? target;
  int runs = 0, wickets = 0, legalBalls = 0;
  int wides = 0, noBalls = 0, byes = 0, legByes = 0;
  final batters = <int, BatterCard>{};
  final bowlers = <int, BowlerCard>{};
  final fallOfWickets = <Map<String, dynamic>>[];
  final log = <Map<String, dynamic>>[]; // ball-by-ball commentary
  int? striker, nonStriker, bowler, lastOverBowler;
  List<String> thisOver = [];
  int overRunsByBowler = 0;
  bool freeHit = false;
  bool complete = false;
  String? endReason;
  int partnershipRuns = 0, partnershipBalls = 0;

  Innings(this.no, this.batting, this.bowling, this.target);

  int get extras => wides + noBalls + byes + legByes;
  String get overs => '${legalBalls ~/ 6}.${legalBalls % 6}';
  bool get needsBowler => !complete && bowler == null;
  int get battersIn => [striker, nonStriker].whereType<int>().length;
}

class CricketState {
  final CricketSetup setup;
  final CricketRules rules;
  final innings = <Innings>[];
  int? winner;
  String? result;
  bool finished = false;
  bool tieNeedsDecision = false;
  String? outcome; // WIN, TIE or NO_RESULT once finished

  CricketState(this.setup, this.rules);

  Innings? get current => innings.isEmpty ? null : innings.last;

  /// NOT_STARTED, IN_PROGRESS, INNINGS_BREAK, TIE_DECISION or COMPLETED.
  String get status {
    if (finished) return 'COMPLETED';
    if (tieNeedsDecision) return 'TIE_DECISION';
    final c = current;
    if (c == null) return 'NOT_STARTED';
    return c.complete ? 'INNINGS_BREAK' : 'IN_PROGRESS';
  }

  /// What the scorer must do before the next ball, or null when a ball can be bowled.
  String? get pending {
    if (status != 'IN_PROGRESS') return null;
    final c = current!;
    if (c.battersIn < (c.wickets >= rules.playersPerSide - 1 && rules.lastManStands ? 1 : 2)) return 'NEW_BATTER';
    if (c.bowler == null) return 'NEW_BOWLER';
    return null;
  }

  String nameOf(int id) {
    for (final l in setup.players.values) {
      for (final p in l) {
        if (p.id == id) return p.name;
      }
    }
    return 'Player';
  }

  List<PlayerRef> playersOf(int entry) => setup.players[entry] ?? const [];

  /// Batters who can come in: in the XI, not out, not at the crease.
  List<PlayerRef> availableBatters() {
    final c = current;
    if (c == null) return const [];
    return playersOf(c.batting).where((p) {
      final b = c.batters[p.id];
      return p.id != c.striker && p.id != c.nonStriker && (b == null || (!b.out && b.retiredHurt));
    }).toList();
  }

  /// Bowlers who can bowl the next over: not the last over's bowler and under their overs limit.
  List<PlayerRef> availableBowlers() {
    final c = current;
    if (c == null) return const [];
    return playersOf(c.bowling).where((p) {
      if (p.id == c.lastOverBowler) return false;
      final b = c.bowlers[p.id];
      return b == null || b.legalBalls < rules.oversPerBowler * 6;
    }).toList();
  }

  Map<String, dynamic> toJson() {
    final c = current;
    Map<String, dynamic> inn(Innings i) => {
          'no': i.no,
          'batting_entry_id': i.batting,
          'bowling_entry_id': i.bowling,
          'runs': i.runs,
          'wickets': i.wickets,
          'overs': i.overs,
          'legal_balls': i.legalBalls,
          'target': i.target,
          'complete': i.complete,
          'end_reason': i.endReason,
          'extras': {'total': i.extras, 'wides': i.wides, 'no_balls': i.noBalls, 'byes': i.byes, 'leg_byes': i.legByes},
          'run_rate': i.legalBalls == 0 ? 0 : double.parse((i.runs * 6 / i.legalBalls).toStringAsFixed(2)),
          'batting': [for (final b in (i.batters.values.toList()..sort((a, b) => a.order.compareTo(b.order)))) b.toJson()],
          'bowling': [for (final b in i.bowlers.values) b.toJson()],
          'fall_of_wickets': i.fallOfWickets,
          'yet_to_bat': [
            for (final p in playersOf(i.batting))
              if (!i.batters.containsKey(p.id)) p.name
          ],
        };
    final out = <String, dynamic>{
      'sport': 'CRICKET',
      'status': status,
      'overs_limit': rules.overs,
      'innings': [for (final i in innings) inn(i)],
      'result': result,
      'winner_entry_id': winner,
      'outcome': outcome,
      // What the points table needs. For net run rate, a team bowled out counts as having faced its full overs.
      'standing': [
        for (final i in innings)
          {'batting': i.batting, 'runs': i.runs, 'balls': i.wickets >= rules.allOutAt ? rules.overs * 6 : i.legalBalls}
      ],
      // Short scores for lists, e.g. {"12": "124/5 (12.3)"}.
      'summary': {for (final i in innings) '${i.batting}': '${i.runs}/${i.wickets} (${i.overs})'},
    };
    if (c != null && !c.complete && !finished) {
      final ballsLeft = rules.overs * 6 - c.legalBalls;
      final need = c.target == null ? null : c.target! - c.runs;
      out['current'] = {
        'innings': c.no,
        'striker': c.striker == null ? null : c.batters[c.striker]!.toJson(),
        'non_striker': c.nonStriker == null ? null : c.batters[c.nonStriker]!.toJson(),
        'bowler': c.bowler == null ? null : c.bowlers[c.bowler]?.toJson() ?? {'id': c.bowler, 'name': nameOf(c.bowler!), 'overs': '0.0', 'runs': 0, 'wickets': 0},
        'this_over': c.thisOver,
        'free_hit': c.freeHit,
        'partnership': {'runs': c.partnershipRuns, 'balls': c.partnershipBalls},
        'balls_left': ballsLeft,
        'need': need,
        'required_rate': need == null || ballsLeft <= 0 ? null : double.parse((need * 6 / ballsLeft).toStringAsFixed(2)),
        'pending': pending,
      };
    }
    out['commentary'] = [
      for (final i in innings.reversed)
        for (final l in i.log.reversed) l
    ].take(60).toList();
    return out;
  }
}

class CricketEngine {
  /// Applies [events] in order (honouring UNDO) and returns the match state. Throws [ScoringError] on an invalid event.
  static CricketState replay(CricketSetup setup, CricketRules rules, List<MatchEvent> events) {
    final s = CricketState(setup, rules);
    for (final e in effective(events)) {
      _apply(s, e);
    }
    return s;
  }

  /// Events still in effect: each UNDO removes the latest one before it.
  static List<MatchEvent> effective(List<MatchEvent> events) {
    final kept = <MatchEvent>[];
    for (final e in events) {
      if (e.type == 'UNDO') {
        if (kept.isNotEmpty) kept.removeLast();
      } else {
        kept.add(e);
      }
    }
    return kept;
  }

  /// Checks [next] against the current events without changing anything. Returns the new state.
  static CricketState tryAdd(CricketSetup setup, CricketRules rules, List<MatchEvent> events, MatchEvent next) =>
      replay(setup, rules, [...events, next]);

  static int _i(Map<String, dynamic> d, String k) {
    final v = d[k];
    if (v is num) return v.toInt();
    final p = int.tryParse('${v ?? ''}');
    if (p == null) throw ScoringError('Missing $k.');
    return p;
  }

  static void _apply(CricketState s, MatchEvent e) {
    final d = e.data;
    switch (e.type) {
      case 'START_INNINGS':
        return _startInnings(s, _i(d, 'striker'), _i(d, 'non_striker'), _i(d, 'bowler'));
      case 'BALL':
        return _ball(s, d);
      case 'NEW_BATTER':
        return _newBatter(s, _i(d, 'id'), d['position']?.toString() ?? 'STRIKER');
      case 'NEW_BOWLER':
        return _newBowler(s, _i(d, 'id'));
      case 'SWAP_STRIKE':
        final c = _live(s);
        final t = c.striker;
        c.striker = c.nonStriker;
        c.nonStriker = t;
        return;
      case 'RETIRE':
        return _retire(s, _i(d, 'id'), d['out'] == true);
      case 'END_INNINGS':
        final c = _live(s);
        _endInnings(s, c, d['reason']?.toString() ?? 'Innings closed');
        return;
      case 'END_MATCH':
        if (s.finished) throw const ScoringError('The match is already over.');
        final w = d['winner'];
        s.winner = w is num ? w.toInt() : int.tryParse('${w ?? ''}');
        s.result = (d['text']?.toString().trim().isNotEmpty ?? false) ? d['text'].toString().trim() : 'Match ended';
        s.finished = true;
        s.outcome = s.winner != null ? 'WIN' : 'NO_RESULT';
        s.tieNeedsDecision = false;
        final c = s.current;
        if (c != null && !c.complete) {
          c.complete = true;
          c.endReason = 'Match ended';
        }
        return;
      default:
        throw ScoringError('Unknown event ${e.type}.');
    }
  }

  static Innings _live(CricketState s) {
    if (s.finished) throw const ScoringError('The match is over.');
    final c = s.current;
    if (c == null || c.complete) throw const ScoringError('Start the innings first.');
    return c;
  }

  static void _startInnings(CricketState s, int striker, int nonStriker, int bowler) {
    if (s.finished || s.tieNeedsDecision) throw const ScoringError('The match is over.');
    if (s.innings.length >= 2) throw const ScoringError('Both innings have been played.');
    if (s.current != null && !s.current!.complete) throw const ScoringError('The current innings is still going on.');
    final batting = s.innings.isEmpty ? s.setup.firstBatting : s.setup.other(s.innings.first.batting);
    final bowling = s.setup.other(batting);
    final ids = {for (final p in s.playersOf(batting)) p.id};
    if (!ids.contains(striker) || !ids.contains(nonStriker) || striker == nonStriker) {
      throw const ScoringError('Pick two different batters from the batting team.');
    }
    if (!s.playersOf(bowling).any((p) => p.id == bowler)) throw const ScoringError('Pick the bowler from the bowling team.');
    final target = s.innings.isEmpty ? null : s.innings.first.runs + 1;
    final inn = Innings(s.innings.length + 1, batting, bowling, target);
    inn.batters[striker] = BatterCard(striker, s.nameOf(striker), 1);
    inn.batters[nonStriker] = BatterCard(nonStriker, s.nameOf(nonStriker), 2);
    inn.striker = striker;
    inn.nonStriker = nonStriker;
    inn.bowler = bowler;
    inn.bowlers[bowler] = BowlerCard(bowler, s.nameOf(bowler));
    s.innings.add(inn);
  }

  static void _newBatter(CricketState s, int id, String position) {
    final c = _live(s);
    if (!s.availableBatters().any((p) => p.id == id)) throw const ScoringError('That batter cannot come in.');
    final existing = c.batters[id];
    if (existing != null) {
      existing.retiredHurt = false; // a retired-hurt batter returning
    } else {
      c.batters[id] = BatterCard(id, s.nameOf(id), c.batters.length + 1);
    }
    if (position == 'NON_STRIKER') {
      if (c.nonStriker != null) throw const ScoringError('Both ends are taken.');
      c.nonStriker = id;
    } else {
      if (c.striker != null) {
        if (c.nonStriker != null) throw const ScoringError('Both ends are taken.');
        c.nonStriker = id;
      } else {
        c.striker = id;
      }
    }
    c.partnershipRuns = 0;
    c.partnershipBalls = 0;
  }

  static void _newBowler(CricketState s, int id) {
    final c = _live(s);
    if (c.bowler != null) throw const ScoringError('Finish the over first.');
    if (id == c.lastOverBowler) throw const ScoringError('A bowler cannot bowl two overs in a row.');
    if (!s.playersOf(c.bowling).any((p) => p.id == id)) throw const ScoringError('Pick the bowler from the bowling team.');
    final b = c.bowlers[id];
    if (b != null && b.legalBalls >= s.rules.oversPerBowler * 6) {
      throw ScoringError('${b.name} has bowled the maximum ${s.rules.oversPerBowler} overs.');
    }
    c.bowler = id;
    c.bowlers.putIfAbsent(id, () => BowlerCard(id, s.nameOf(id)));
  }

  static void _retire(CricketState s, int id, bool out) {
    final c = _live(s);
    if (id != c.striker && id != c.nonStriker) throw const ScoringError('Only a batter at the crease can retire.');
    final b = c.batters[id]!;
    if (out) {
      b.out = true;
      b.howOut = 'retired out';
      c.wickets++;
      c.fallOfWickets.add({'wicket': c.wickets, 'score': c.runs, 'over': c.overs, 'name': b.name});
    } else {
      b.retiredHurt = true;
    }
    if (c.striker == id) c.striker = null;
    if (c.nonStriker == id) c.nonStriker = null;
    _lastManOnStrike(s, c);
    _checkEnd(s, c);
  }

  static const _bowlerWickets = {'BOWLED', 'CAUGHT', 'LBW', 'STUMPED', 'HIT_WICKET'};

  static void _ball(CricketState s, Map<String, dynamic> d) {
    final c = _live(s);
    if (s.pending == 'NEW_BATTER') throw const ScoringError('Pick the new batter first.');
    if (s.pending == 'NEW_BOWLER') throw const ScoringError('Pick the bowler for this over first.');
    _lastManOnStrike(s, c);
    final striker = c.striker;
    if (striker == null) throw const ScoringError('Pick the new batter first.');
    final runs = d['runs'] is num ? (d['runs'] as num).toInt() : 0;
    if (runs < 0 || runs > 7) throw const ScoringError('Runs must be between 0 and 7.');
    final extra = d['extra']?.toString() ?? 'NONE';
    if (!const {'NONE', 'WIDE', 'NO_BALL', 'BYE', 'LEG_BYE'}.contains(extra)) throw const ScoringError('Unknown extra.');
    final w = d['wicket'] is Map ? Map<String, dynamic>.from(d['wicket'] as Map) : null;
    final how = w?['how']?.toString();
    final wasFreeHit = c.freeHit;
    if (w != null) {
      if (!const {'BOWLED', 'CAUGHT', 'LBW', 'RUN_OUT', 'STUMPED', 'HIT_WICKET'}.contains(how)) throw const ScoringError('Unknown way out.');
      if (extra == 'NO_BALL' && how != 'RUN_OUT') throw const ScoringError('On a no-ball a batter can only be run out.');
      if (extra == 'WIDE' && how != 'RUN_OUT' && how != 'STUMPED') throw const ScoringError('On a wide a batter can only be run out or stumped.');
      if (wasFreeHit && how != 'RUN_OUT') throw const ScoringError('On a free hit a batter can only be run out.');
    }
    final bowler = c.bowlers[c.bowler]!;
    final bat = c.batters[striker]!;
    final over = '${c.legalBalls ~/ 6}.${c.legalBalls % 6 + 1}'; // e.g. 3.4 (extras repeat the ball number)
    final legal = extra != 'WIDE' && extra != 'NO_BALL';
    var total = runs;
    var charged = 0; // runs against the bowler
    switch (extra) {
      case 'WIDE':
        total = s.rules.wideRuns + runs;
        c.wides += total;
        charged = total;
        bowler.wides++;
      case 'NO_BALL':
        total = s.rules.noBallRuns + runs;
        c.noBalls += s.rules.noBallRuns;
        bowler.noBalls++;
        bat.balls++;
        if (d['nb_byes'] == true) {
          c.byes += runs;
          charged = s.rules.noBallRuns;
        } else {
          bat.runs += runs;
          charged = total;
          if (runs == 4 && d['boundary'] == true) bat.fours++;
          if (runs == 6) bat.sixes++;
        }
      case 'BYE':
        c.byes += runs;
        bat.balls++;
      case 'LEG_BYE':
        c.legByes += runs;
        bat.balls++;
      default:
        bat.runs += runs;
        bat.balls++;
        charged = runs;
        if (runs == 4 && d['boundary'] == true) bat.fours++;
        if (runs == 6) bat.sixes++;
    }
    c.runs += total;
    bowler.runs += charged;
    c.overRunsByBowler += charged;
    c.partnershipRuns += total;
    if (legal) {
      c.legalBalls++;
      bowler.legalBalls++;
      c.partnershipBalls++;
      if (total == 0 && w == null) bowler.dots++;
    }

    // Free hit: the ball after a no-ball, and it carries over a wide.
    if (extra == 'NO_BALL' && s.rules.freeHit) {
      c.freeHit = true;
    } else if (legal) {
      c.freeHit = false;
    }

    final symbol = _symbol(extra, runs, total, w != null, d['boundary'] == true);
    c.thisOver = [...c.thisOver, symbol];

    // Odd runs completed between the wickets change ends.
    if (runs.isOdd && c.nonStriker != null) {
      final t = c.striker;
      c.striker = c.nonStriker;
      c.nonStriker = t;
    }

    String? outText;
    if (w != null) {
      final outId = w['out'] is num ? (w['out'] as num).toInt() : striker;
      if (outId != c.striker && outId != c.nonStriker) throw const ScoringError('The dismissed batter must be at the crease.');
      final o = c.batters[outId]!;
      final fielder = w['fielder'] is num ? s.nameOf((w['fielder'] as num).toInt()) : null;
      o.out = true;
      o.howOut = switch (how) {
        'BOWLED' => 'b ${bowler.name}',
        'CAUGHT' => fielder == null || w['fielder'] == bowler.id ? 'c & b ${bowler.name}' : 'c $fielder b ${bowler.name}',
        'LBW' => 'lbw b ${bowler.name}',
        'STUMPED' => 'st ${fielder ?? 'keeper'} b ${bowler.name}',
        'HIT_WICKET' => 'hit wicket b ${bowler.name}',
        _ => 'run out${fielder == null ? '' : ' ($fielder)'}',
      };
      if (_bowlerWickets.contains(how)) bowler.wickets++;
      c.wickets++;
      c.fallOfWickets.add({'wicket': c.wickets, 'score': c.runs, 'over': c.overs, 'name': o.name});
      if (c.striker == outId) c.striker = null;
      if (c.nonStriker == outId) c.nonStriker = null;
      outText = '${o.name} ${o.howOut}';
      _lastManOnStrike(s, c);
    }

    c.log.add({
      'innings': c.no,
      'over': over,
      'bowler': bowler.name,
      'batter': bat.name,
      'symbol': symbol,
      'runs': total,
      'text': outText != null ? 'OUT! $outText' : _describe(extra, runs, d['boundary'] == true),
      'score': '${c.runs}/${c.wickets}',
      if (wasFreeHit) 'free_hit': true,
    });

    // End of the over: batters change ends, a new bowler is needed.
    if (legal && c.legalBalls % 6 == 0) {
      if (c.overRunsByBowler == 0) bowler.maidens++;
      c.overRunsByBowler = 0;
      c.lastOverBowler = c.bowler;
      c.bowler = null;
      c.thisOver = [];
      if (c.striker != null && c.nonStriker != null) {
        final t = c.striker;
        c.striker = c.nonStriker;
        c.nonStriker = t;
      } else if (!(s.rules.lastManStands && c.wickets >= s.rules.playersPerSide - 1)) {
        // One end is empty after a wicket: the remaining batter changes ends, the new batter faces.
        if (c.striker != null && c.nonStriker == null) {
          c.nonStriker = c.striker;
          c.striker = null;
        } else if (c.striker == null && c.nonStriker != null) {
          c.striker = c.nonStriker;
          c.nonStriker = null;
        }
      }
    }
    _checkEnd(s, c);
  }

  static String _symbol(String extra, int runs, int total, bool wicket, bool boundary) {
    final w = wicket ? 'W' : '';
    switch (extra) {
      case 'WIDE':
        return '${total > 1 ? total : ''}Wd$w';
      case 'NO_BALL':
        return '${runs > 0 ? runs : ''}Nb$w';
      case 'BYE':
        return '${runs}B$w';
      case 'LEG_BYE':
        return '${runs}Lb$w';
      default:
        return wicket ? (runs > 0 ? '${runs}W' : 'W') : '$runs';
    }
  }

  static String _describe(String extra, int runs, bool boundary) {
    switch (extra) {
      case 'WIDE':
        return runs > 0 ? 'Wide, $runs more' : 'Wide';
      case 'NO_BALL':
        return runs > 0 ? 'No ball, $runs off the bat' : 'No ball';
      case 'BYE':
        return '$runs bye${runs == 1 ? '' : 's'}';
      case 'LEG_BYE':
        return '$runs leg bye${runs == 1 ? '' : 's'}';
      default:
        if (runs == 6) return 'SIX!';
        if (runs == 4 && boundary) return 'FOUR!';
        return runs == 0 ? 'No run' : '$runs run${runs == 1 ? '' : 's'}';
    }
  }

  /// Last man stands: when one batter is left, they face every ball.
  static void _lastManOnStrike(CricketState s, Innings c) {
    if (s.rules.lastManStands && c.wickets >= s.rules.playersPerSide - 1 && c.striker == null && c.nonStriker != null) {
      c.striker = c.nonStriker;
      c.nonStriker = null;
    }
  }

  static void _checkEnd(CricketState s, Innings c) {
    if (c.wickets >= s.rules.allOutAt) {
      _endInnings(s, c, 'All out');
    } else if (c.legalBalls >= s.rules.overs * 6) {
      _endInnings(s, c, 'Overs complete');
    } else if (c.target != null && c.runs >= c.target!) {
      _endInnings(s, c, 'Target reached');
    }
  }

  static void _endInnings(CricketState s, Innings c, String reason) {
    c.complete = true;
    c.endReason = reason;
    c.striker = null;
    c.nonStriker = null;
    c.bowler = null;
    c.thisOver = [];
    if (c.no == 2) _result(s);
  }

  static void _result(CricketState s) {
    final first = s.innings[0], second = s.innings[1];
    final target = second.target!;
    if (second.runs >= target) {
      final left = s.rules.allOutAt - second.wickets;
      final balls = s.rules.overs * 6 - second.legalBalls;
      s.winner = second.batting;
      s.result = '{${second.batting}} won by $left wicket${left == 1 ? '' : 's'}${balls > 0 ? ' with $balls ball${balls == 1 ? '' : 's'} left' : ''}';
      s.finished = true;
      s.outcome = 'WIN';
    } else if (second.runs == target - 1) {
      if (s.setup.knockout) {
        s.tieNeedsDecision = true;
        s.result = 'Scores level. Play a super over and record the winner.';
      } else {
        s.winner = null;
        s.result = 'Match tied';
        s.finished = true;
        s.outcome = 'TIE';
      }
    } else {
      final by = target - 1 - second.runs;
      s.winner = first.batting;
      s.result = '{${first.batting}} won by $by run${by == 1 ? '' : 's'}';
      s.finished = true;
      s.outcome = 'WIN';
    }
  }
}
