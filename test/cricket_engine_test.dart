import 'package:flutter_test/flutter_test.dart';
import 'package:mypaltan/scoring/cricket_engine.dart';

// Team A (entry 1): players 11-16, Team B (entry 2): players 21-26. 6-a-side box cricket, 2 overs.
const a = [PlayerRef(11, 'A1'), PlayerRef(12, 'A2'), PlayerRef(13, 'A3'), PlayerRef(14, 'A4'), PlayerRef(15, 'A5'), PlayerRef(16, 'A6')];
const b = [PlayerRef(21, 'B1'), PlayerRef(22, 'B2'), PlayerRef(23, 'B3'), PlayerRef(24, 'B4'), PlayerRef(25, 'B5'), PlayerRef(26, 'B6')];
const setup = CricketSetup(homeEntry: 1, awayEntry: 2, tossWinner: 1, tossDecision: 'BAT', players: {1: a, 2: b});
const rules = CricketRules(overs: 2, playersPerSide: 6, oversPerBowler: 1);

var _n = 0;
MatchEvent ev(String type, [Map<String, dynamic> data = const {}]) => MatchEvent('e${_n++}', type, data);
MatchEvent ball(int runs, {String extra = 'NONE', bool four = false, Map<String, dynamic>? wicket, bool nbByes = false}) => ev('BALL', {
      'runs': runs,
      'extra': extra,
      if (four) 'boundary': true,
      if (wicket != null) 'wicket': wicket,
      if (nbByes) 'nb_byes': true,
    });
MatchEvent start(int s, int n, int bw) => ev('START_INNINGS', {'striker': s, 'non_striker': n, 'bowler': bw});

CricketState play(List<MatchEvent> events, {CricketRules r = rules, CricketSetup st = setup}) => CricketEngine.replay(st, r, events);

void main() {
  test('runs, boundaries, strike rotation and end of over', () {
    final s = play([start(11, 12, 21), ball(1), ball(4, four: true), ball(0), ball(6), ball(2), ball(3)]);
    final i = s.current!;
    expect(i.runs, 16);
    expect(i.overs, '1.0');
    expect(i.batters[11]!.runs, 1);
    expect(i.batters[12]!.runs, 4 + 0 + 6 + 2 + 3);
    expect(i.batters[12]!.fours, 1);
    expect(i.batters[12]!.sixes, 1);
    // 3 off the last ball moved A2 to the non-striker's end, then the over ended and they swapped back.
    expect(i.striker, 12);
    expect(i.bowler, isNull);
    expect(s.pending, 'NEW_BOWLER');
    expect(i.bowlers[21]!.runs, 16);
  });

  test('extras: wide and no-ball are not legal balls; byes do not count against the bowler', () {
    final s = play([start(11, 12, 21), ball(0, extra: 'WIDE'), ball(2, extra: 'WIDE'), ball(1, extra: 'NO_BALL'), ball(2, extra: 'BYE'), ball(1, extra: 'LEG_BYE')]);
    final i = s.current!;
    expect(i.legalBalls, 2);
    expect(i.wides, 1 + 3);
    expect(i.noBalls, 1);
    expect(i.byes, 2);
    expect(i.legByes, 1);
    expect(i.runs, 4 + 2 + 2 + 1);
    expect(i.bowlers[21]!.runs, 4 + 2); // wides + no-ball and the run off it
    expect(i.batters[11]!.runs, 1); // run off the no-ball
    expect(i.batters[11]!.balls, 1); // the no-ball counts as faced, wides do not
    expect(i.batters[12]!.balls, 2); // they crossed for the run, so A2 faced the bye and the leg bye
  });

  test('free hit after a no-ball: only run out allowed, carries over a wide', () {
    final events = [start(11, 12, 21), ball(0, extra: 'NO_BALL')];
    expect(play(events).current!.freeHit, true);
    expect(() => play([...events, ball(0, wicket: {'how': 'BOWLED'})]), throwsA(isA<ScoringError>()));
    final s = play([...events, ball(0, extra: 'WIDE')]);
    expect(s.current!.freeHit, true);
    expect(play([...events, ball(0, extra: 'WIDE'), ball(1)]).current!.freeHit, false);
  });

  test('wicket, new batter, fall of wickets and bowler credit', () {
    final events = [
      start(11, 12, 21),
      ball(0, wicket: {'how': 'CAUGHT', 'out': 11, 'fielder': 23}),
      ev('NEW_BATTER', {'id': 13, 'position': 'STRIKER'}),
      ball(1, wicket: {'how': 'RUN_OUT', 'out': 12, 'fielder': 24}),
    ];
    final s = play(events);
    final i = s.current!;
    expect(i.wickets, 2);
    expect(i.batters[11]!.howOut, 'c B3 b B1');
    expect(i.batters[12]!.howOut, 'run out (B4)');
    expect(i.bowlers[21]!.wickets, 1); // run out is not the bowler's
    expect(i.fallOfWickets.length, 2);
    expect(i.fallOfWickets[1]['score'], 1);
    // They ran 1 (ends changed), then A2 was run out at the striker's end; A3 is at the non-striker's end.
    expect(i.striker, null);
    expect(i.nonStriker, 13);
    expect(s.pending, 'NEW_BATTER');
    expect(() => play([...events, ball(0)]), throwsA(isA<ScoringError>()));
  });

  test('a bowler cannot bowl consecutive overs or more than the limit', () {
    final over = [ball(0), ball(0), ball(0), ball(0), ball(0), ball(0)];
    final events = [start(11, 12, 21), ...over];
    expect(play(events).current!.bowlers[21]!.maidens, 1);
    expect(() => play([...events, ev('NEW_BOWLER', {'id': 21})]), throwsA(isA<ScoringError>()));
    expect(play(events).availableBowlers().map((p) => p.id), isNot(contains(21)));
    expect(play([...events, ev('NEW_BOWLER', {'id': 22})]).current!.bowler, 22);
  });

  test('undo removes the latest event, repeatedly', () {
    final s = play([start(11, 12, 21), ball(4, four: true), ball(6), ev('UNDO'), ev('UNDO'), ball(1)]);
    expect(s.current!.runs, 1);
    expect(s.current!.batters[11]!.fours, 0);
  });

  test('innings ends after the overs, second innings chases and wins by wickets', () {
    final over = [ball(1), ball(1), ball(1), ball(1), ball(1), ball(1)];
    final s = play([
      start(11, 12, 21), ...over, ev('NEW_BOWLER', {'id': 22}), ...over,
      // Team A made 12. Team B needs 13.
      start(21, 22, 11), ball(6), ball(6), ball(1),
    ]);
    expect(s.innings.first.complete, true);
    expect(s.innings.first.endReason, 'Overs complete');
    expect(s.innings[1].target, 13);
    expect(s.status, 'COMPLETED');
    expect(s.winner, 2);
    expect(s.result, '{2} won by 5 wickets with 9 balls left');
  });

  test('defending: won by runs, and a tie in a league', () {
    final over = [ball(1), ball(1), ball(1), ball(1), ball(1), ball(1)];
    final first = [start(11, 12, 21), ...over, ev('NEW_BOWLER', {'id': 22}), ...over]; // 12
    final short = play([...first, start(21, 22, 11), ...over, ev('NEW_BOWLER', {'id': 12}), ball(0), ball(0), ball(0), ball(0), ball(0), ball(0)]);
    expect(short.result, '{1} won by 6 runs');
    final tie = play([...first, start(21, 22, 11), ...over, ev('NEW_BOWLER', {'id': 12}), ...over]);
    expect(tie.result, 'Match tied');
    expect(tie.winner, isNull);
  });

  test('a tie in a knockout waits for the winner of the super over', () {
    const ko = CricketSetup(homeEntry: 1, awayEntry: 2, tossWinner: 1, tossDecision: 'BAT', players: {1: a, 2: b}, knockout: true);
    final over = [ball(1), ball(1), ball(1), ball(1), ball(1), ball(1)];
    final events = [start(11, 12, 21), ...over, ev('NEW_BOWLER', {'id': 22}), ...over, start(21, 22, 11), ...over, ev('NEW_BOWLER', {'id': 12}), ...over];
    final s = play(events, st: ko);
    expect(s.status, 'TIE_DECISION');
    final done = play([...events, ev('END_MATCH', {'winner': 2, 'text': '{2} won the super over'})], st: ko);
    expect(done.status, 'COMPLETED');
    expect(done.winner, 2);
  });

  test('all out, and last man stands lets the last batter bat alone', () {
    MatchEvent out(int id) => ball(0, wicket: {'how': 'BOWLED', 'out': id});
    final normal = play([
      start(11, 12, 21), out(11), ev('NEW_BATTER', {'id': 13}), out(13), ev('NEW_BATTER', {'id': 14}),
      out(14), ev('NEW_BATTER', {'id': 15}), out(15), ev('NEW_BATTER', {'id': 16}), out(16),
    ]);
    expect(normal.innings.first.endReason, 'All out');
    const lms = CricketRules(overs: 2, playersPerSide: 6, oversPerBowler: 1, lastManStands: true);
    final s = play([
      start(11, 12, 21), out(11), ev('NEW_BATTER', {'id': 13}), out(13), ev('NEW_BATTER', {'id': 14}),
      out(14), ev('NEW_BATTER', {'id': 15}), out(15), ev('NEW_BATTER', {'id': 16}), out(16), ball(1),
    ], r: lms);
    expect(s.current!.complete, false);
    expect(s.current!.wickets, 5);
    expect(s.current!.runs, 1);
    expect(s.pending, 'NEW_BOWLER'); // over ended, A2 still batting alone
  });

  test('scoring after the match or before the innings is refused', () {
    expect(() => play([ball(1)]), throwsA(isA<ScoringError>()));
    expect(() => play([start(11, 21, 21)]), throwsA(isA<ScoringError>()));
  });

  test('live JSON has the scorecard and current state', () {
    final j = play([start(11, 12, 21), ball(4, four: true), ball(0, extra: 'WIDE')]).toJson();
    expect(j['status'], 'IN_PROGRESS');
    expect(j['current']['this_over'], ['4', 'Wd']);
    expect(j['innings'][0]['batting'][0]['name'], 'A1');
    expect(j['innings'][0]['yet_to_bat'], ['A3', 'A4', 'A5', 'A6']);
    expect((j['commentary'] as List).first['text'], 'Wide');
  });
}
