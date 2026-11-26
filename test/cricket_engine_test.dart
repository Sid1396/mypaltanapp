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
    final s =
        play([start(11, 12, 21), ball(0, extra: 'WIDE'), ball(2, extra: 'WIDE'), ball(1, extra: 'NO_BALL'), ball(2, extra: 'BYE'), ball(1, extra: 'LEG_BYE')]);
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
    expect(
        () => play([
              ...events,
              ball(0, wicket: {'how': 'BOWLED'})
            ]),
        throwsA(isA<ScoringError>()));
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

  test('the other batter was facing: the wicket screen swaps strike first, so the ball and wicket are his', () {
    // A1 is on strike in the app, but A2 was the one bowled. The wicket screen sends SWAP_STRIKE, then the wicket.
    final s = play([start(11, 12, 21), ball(0), ev('SWAP_STRIKE'), ball(0, wicket: {'how': 'BOWLED', 'out': 12})]);
    final i = s.current!;
    expect(i.batters[12]!.out, true);
    expect(i.batters[12]!.balls, 1); // the ball he was bowled by is his
    expect(i.batters[11]!.out, false);
    expect(i.batters[11]!.balls, 1);
    expect(i.bowlers[21]!.wickets, 1);
    expect(i.striker, isNull); // the new batter comes in on strike
    expect(i.nonStriker, 11);
  });

  test('retired hurt: not a wicket and not a ball; he can come back later; retired out is a wicket', () {
    final events = [start(11, 12, 21), ball(1), ev('RETIRE', {'id': 11, 'out': false})];
    var s = play(events);
    var i = s.current!;
    expect(i.wickets, 0);
    expect(i.legalBalls, 1);
    expect(i.batters[11]!.retiredHurt, true);
    expect(i.batters[11]!.out, false);
    expect(s.pending, 'NEW_BATTER');
    expect(s.availableBatters().map((p) => p.id), contains(11)); // he can return
    expect(s.toJson()['innings'][0]['batting'][0]['how_out'], 'retired hurt');
    // A3 comes in; later A2 is out and A1 returns with his score kept.
    s = play([
      ...events,
      ev('NEW_BATTER', {'id': 13, 'position': 'NON_STRIKER'}),
      ball(0, wicket: {'how': 'BOWLED', 'out': 12}),
      ev('NEW_BATTER', {'id': 11, 'position': 'STRIKER'}),
      ball(2),
    ]);
    i = s.current!;
    expect(i.batters[11]!.retiredHurt, false);
    expect(i.batters[11]!.runs, 1 + 2);
    expect(i.wickets, 1);
    // Retired out counts as a wicket, with no bowler credit.
    i = play([start(11, 12, 21), ev('RETIRE', {'id': 11, 'out': true})]).current!;
    expect(i.wickets, 1);
    expect(i.batters[11]!.howOut, 'retired out');
    expect(i.bowlers[21]?.wickets ?? 0, 0);
  });

  test('1D on a no-ball: the run is the batter\'s, not a legal ball, strike stays; byes off a no-ball are never declared', () {
    final s = play([start(11, 12, 21), ev('BALL', {'runs': 1, 'extra': 'NO_BALL', 'declared': true})]);
    final i = s.current!;
    expect(i.runs, 2); // no-ball run + the declared run
    expect(i.noBalls, 1);
    expect(i.legalBalls, 0);
    expect(i.batters[11]!.runs, 1);
    expect(i.batters[11]!.balls, 1);
    expect(i.bowlers[21]!.runs, 2);
    expect(i.striker, 11); // declared: they did not run, so no change of ends
    expect(i.thisOver, ['1DNb']);
    // A normal 1 off a no-ball does change ends.
    expect(play([start(11, 12, 21), ball(1, extra: 'NO_BALL')]).current!.striker, 12);
    // "Declared" on no-ball byes is ignored: byes are run.
    final b = play([start(11, 12, 21), ev('BALL', {'runs': 1, 'extra': 'NO_BALL', 'nb_byes': true, 'declared': true})]).current!;
    expect(b.striker, 12);
    expect(b.byes, 1);
  });

  test('a bowler cannot bowl consecutive overs or more than the limit', () {
    final over = [ball(0), ball(0), ball(0), ball(0), ball(0), ball(0)];
    final events = [start(11, 12, 21), ...over];
    expect(play(events).current!.bowlers[21]!.maidens, 1);
    expect(
        () => play([
              ...events,
              ev('NEW_BOWLER', {'id': 21})
            ]),
        throwsA(isA<ScoringError>()));
    expect(play(events).availableBowlers().map((p) => p.id), isNot(contains(21)));
    expect(
        play([
          ...events,
          ev('NEW_BOWLER', {'id': 22})
        ]).current!.bowler,
        22);
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
    final j = s.toJson();
    expect(j['outcome'], 'WIN');
    expect(j['standing'], [
      {'batting': 1, 'runs': 12, 'balls': 12},
      {'batting': 2, 'runs': 13, 'balls': 3},
    ]);
  });

  test('net run rate counts the full overs for a team bowled out', () {
    MatchEvent out(int id) => ball(0, wicket: {'how': 'BOWLED', 'out': id});
    final s = play([
      start(11, 12, 21),
      ball(4, four: true),
      out(11),
      ev('NEW_BATTER', {'id': 13}),
      out(13),
      ev('NEW_BATTER', {'id': 14}),
      out(14),
      ev('NEW_BATTER', {'id': 15}),
      out(15),
      ev('NEW_BATTER', {'id': 16}),
      out(16),
    ]);
    expect((s.toJson()['standing'] as List).first, {'batting': 1, 'runs': 4, 'balls': 12});
  });

  test('defending: won by runs, and a tie in a league', () {
    final over = [ball(1), ball(1), ball(1), ball(1), ball(1), ball(1)];
    final first = [
      start(11, 12, 21),
      ...over,
      ev('NEW_BOWLER', {'id': 22}),
      ...over
    ]; // 12
    final short = play([
      ...first,
      start(21, 22, 11),
      ...over,
      ev('NEW_BOWLER', {'id': 12}),
      ball(0),
      ball(0),
      ball(0),
      ball(0),
      ball(0),
      ball(0)
    ]);
    expect(short.result, '{1} won by 6 runs');
    final tie = play([
      ...first,
      start(21, 22, 11),
      ...over,
      ev('NEW_BOWLER', {'id': 12}),
      ...over
    ]);
    expect(tie.result, 'Match tied');
    expect(tie.outcome, 'TIE');
    expect(tie.winner, isNull);
  });

  test('a tie in a knockout waits for the winner of the super over', () {
    const ko = CricketSetup(homeEntry: 1, awayEntry: 2, tossWinner: 1, tossDecision: 'BAT', players: {1: a, 2: b}, knockout: true);
    final over = [ball(1), ball(1), ball(1), ball(1), ball(1), ball(1)];
    final events = [
      start(11, 12, 21),
      ...over,
      ev('NEW_BOWLER', {'id': 22}),
      ...over,
      start(21, 22, 11),
      ...over,
      ev('NEW_BOWLER', {'id': 12}),
      ...over
    ];
    final s = play(events, st: ko);
    expect(s.status, 'TIE_DECISION');
    final done = play([
      ...events,
      ev('END_MATCH', {'winner': 2, 'text': '{2} won the super over'})
    ], st: ko);
    expect(done.status, 'COMPLETED');
    expect(done.winner, 2);
  });

  test('all out, and last man stands lets the last batter bat alone', () {
    MatchEvent out(int id) => ball(0, wicket: {'how': 'BOWLED', 'out': id});
    final normal = play([
      start(11, 12, 21),
      out(11),
      ev('NEW_BATTER', {'id': 13}),
      out(13),
      ev('NEW_BATTER', {'id': 14}),
      out(14),
      ev('NEW_BATTER', {'id': 15}),
      out(15),
      ev('NEW_BATTER', {'id': 16}),
      out(16),
    ]);
    expect(normal.innings.first.endReason, 'All out');
    const lms = CricketRules(overs: 2, playersPerSide: 6, oversPerBowler: 1, lastManStands: true);
    final s = play([
      start(11, 12, 21),
      out(11),
      ev('NEW_BATTER', {'id': 13}),
      out(13),
      ev('NEW_BATTER', {'id': 14}),
      out(14),
      ev('NEW_BATTER', {'id': 15}),
      out(15),
      ev('NEW_BATTER', {'id': 16}),
      out(16),
      ball(1),
    ], r: lms);
    expect(s.current!.complete, false);
    expect(s.current!.wickets, 5);
    expect(s.current!.runs, 1);
    expect(s.pending, 'NEW_BOWLER'); // over ended, A2 still batting alone
  });

  test('uneven teams (friendly): each team is all out by its own number of players', () {
    // Quick match: up to 11 a side, Team A has 3 players, Team B has 2.
    const uneven = CricketSetup(homeEntry: 1, awayEntry: 2, tossWinner: 1, tossDecision: 'BAT', players: {
      1: [PlayerRef(11, 'A1'), PlayerRef(12, 'A2'), PlayerRef(13, 'A3')],
      2: [PlayerRef(21, 'B1'), PlayerRef(22, 'B2')],
    });
    const up11 = CricketRules(overs: 2, playersPerSide: 11, oversPerBowler: 1);
    MatchEvent out(int id) => ball(0, wicket: {'how': 'BOWLED', 'out': id});
    // Team A (3 players) is all out after 2 wickets, not 10.
    final first = [
      start(11, 12, 21),
      ball(4, four: true),
      out(11),
      ev('NEW_BATTER', {'id': 13}),
      out(13)
    ];
    final s1 = play(first, r: up11, st: uneven);
    expect(s1.innings.first.endReason, 'All out');
    expect(s1.status, 'INNINGS_BREAK');
    // Team B (2 players) chases 5: all out after 1 wicket.
    final s2 = play([...first, start(21, 22, 11), ball(1), out(22)], r: up11, st: uneven);
    expect(s2.innings[1].endReason, 'All out');
    expect(s2.result, '{1} won by 3 runs');
    // Team B wins with 1 wicket in hand: "won by 1 wicket" counts its own 2 players.
    final s3 = play([...first, start(21, 22, 11), ball(6)], r: up11, st: uneven);
    expect(s3.result, startsWith('{2} won by 1 wicket'));
    // Last man stands: Team A's last batter carries on alone after 2 wickets, all out at 3.
    const lms = CricketRules(overs: 2, playersPerSide: 11, oversPerBowler: 1, lastManStands: true);
    final s4 = play(first, r: lms, st: uneven);
    expect(s4.current!.complete, false);
    expect(s4.pending, isNull); // A2 bats alone, no new batter needed
    final s5 = play([...first, out(12)], r: lms, st: uneven);
    expect(s5.innings.first.endReason, 'All out');
  });

  test('player of the match: runs, wickets and catches; only once the match is over', () {
    MatchEvent outC(int id, int f) => ball(0, wicket: {'how': 'CAUGHT', 'out': id, 'fielder': f});
    const one = CricketRules(overs: 1, playersPerSide: 6, oversPerBowler: 1);
    // A1 hits 10 and is caught by B2 off B1; Team B makes 1 in reply.
    final first = [
      start(11, 12, 21),
      ball(6),
      ball(4, four: true),
      outC(11, 22),
      ev('NEW_BATTER', {'id': 13}),
      ball(1),
      ball(0),
      ball(0)
    ];
    expect(play(first, r: one).toJson().containsKey('potm'), false);
    final done = play([...first, start(21, 22, 11), ball(1), ball(0), ball(0), ball(0), ball(0), ball(0)], r: one);
    expect(done.finished, true);
    expect(done.catches[22], 1);
    final potm = done.toJson()['potm'] as Map;
    // Team A won, so it goes to A1 (10 runs) even though B1 (1 run + 1 wicket, 21 points) has more.
    expect(done.winner, 1);
    expect(potm['name'], 'A1');
    expect(potm['reason'], '10 (3)');
    expect(potm['team'], 1);
    // Same again in a 1-over match: A1's 10 beats B1's 20 because Team A won.
    final s2 = play([
      ...first.take(3),
      outC(11, 22),
      ev('NEW_BATTER', {'id': 13}),
      ball(0),
      ball(0),
      ball(0),
      start(21, 22, 12),
      ball(0),
      ball(0),
      ball(0),
      ball(0),
      ball(0),
      ball(0)
    ], r: const CricketRules(overs: 1, playersPerSide: 6, oversPerBowler: 1));
    final p2 = s2.toJson()['potm'] as Map;
    expect(s2.winner, 1);
    expect(p2['name'], 'A1');
    expect(p2['points'], 12); // formula E: 10 runs + a quarter of the 7.5 above par (10 runs in 12 balls) for 10 off 3
  });

  test('player of the match, formula E: a fast match-winning innings beats three wickets', () {
    MatchEvent bowled(int id) => ball(0, wicket: {'how': 'BOWLED', 'out': id});
    const one = CricketRules(overs: 1, playersPerSide: 6, oversPerBowler: 1);
    // A1 makes 24 off 6; A2 then takes 3 wickets for 3. The old 20-a-wicket points gave it to A2 (60 vs 24).
    final s = play([
      start(11, 12, 21),
      ball(6), ball(6), ball(6), ball(6), ball(0), ball(0),
      start(21, 22, 12),
      ball(1), bowled(22), ev('NEW_BATTER', {'id': 23}), ball(1), bowled(21), ev('NEW_BATTER', {'id': 24}), ball(1), bowled(23),
    ], r: one);
    expect(s.finished, true);
    expect(s.winner, 1);
    final potm = s.toJson()['potm'] as Map;
    // Par is 27 runs in 12 balls: A1 24 + ¼ × (24 − 13.5) ≈ 27; A2 4 × 3 + ¾ × (13.5 − 3) ≈ 20.
    expect(potm['name'], 'A1');
    expect(potm['points'], 27);
  });

  test('box out: only when the match has it on; the bowler\'s wicket, like bowled', () {
    final boxOut = ball(0, wicket: {'how': 'BOX_OUT', 'out': 11});
    expect(() => play([start(11, 12, 21), boxOut]), throwsA(isA<ScoringError>()));
    const box = CricketRules(overs: 2, playersPerSide: 6, oversPerBowler: 1, boxOut: true, freeHit: false);
    final s = play([start(11, 12, 21), ball(2), boxOut], r: box);
    expect(s.current!.wickets, 1);
    expect(s.current!.batters[11]!.howOut, 'box out b B1');
    expect(s.current!.bowlers[21]!.wickets, 1);
    expect(s.pending, 'NEW_BATTER');
    // Not on a wide (only run out or stumped there).
    expect(
        () => play([
              start(11, 12, 21),
              ball(0, extra: 'WIDE', wicket: {'how': 'BOX_OUT', 'out': 11})
            ], r: box),
        throwsA(isA<ScoringError>()));
    expect(CricketRules.fromJson({'box_out': true, 'free_hit': false}).boxOut, true);
    expect(CricketRules.fromJson({'box_out': true, 'free_hit': false}).freeHit, false);
  });

  test('wickets off a wide or no-ball: only a run out off a no-ball counts as a ball; stumped off a no-ball is not the bowler\'s', () {
    const box = CricketRules(overs: 2, playersPerSide: 6, oversPerBowler: 1, boxOut: true, freeHit: false);
    // No-ball, 1 run, then the striker is run out: the over moves on, 1 no-ball + 1 run, no wicket for the bowler.
    var s = play([
      start(11, 12, 21),
      ball(1, extra: 'NO_BALL', wicket: {'how': 'RUN_OUT', 'out': 11, 'fielder': 22})
    ], r: box);
    var i = s.current!;
    expect(i.legalBalls, 1);
    expect(i.noBalls, 1);
    expect(i.runs, 2);
    expect(i.wickets, 1);
    expect(i.bowlers[21]!.wickets, 0);
    expect(i.bowlers[21]!.legalBalls, 1);
    expect(s.runOuts[22], 1);
    // Wide, run out: bowled again, the wide still added.
    s = play([
      start(11, 12, 21),
      ball(0, extra: 'WIDE', wicket: {'how': 'RUN_OUT', 'out': 12})
    ], r: box);
    expect(s.current!.legalBalls, 0);
    expect(s.current!.wides, 1);
    // Stumped off a wide: bowled again, the bowler's wicket and the keeper's stumping.
    s = play([
      start(11, 12, 21),
      ball(0, extra: 'WIDE', wicket: {'how': 'STUMPED', 'out': 11, 'fielder': 23})
    ], r: box);
    i = s.current!;
    expect(i.legalBalls, 0);
    expect(i.wides, 1);
    expect(i.wickets, 1);
    expect(i.bowlers[21]!.wickets, 1);
    expect(s.runOuts[23], 1);
    // Stumped off a no-ball: bowled again, not the bowler's.
    s = play([
      start(11, 12, 21),
      ball(0, extra: 'NO_BALL', wicket: {'how': 'STUMPED', 'out': 11, 'fielder': 23})
    ], r: box);
    expect(s.current!.legalBalls, 0);
    expect(s.current!.bowlers[21]!.wickets, 0);
    // Box out off a no-ball: bowled again, the bowler's wicket.
    s = play([
      start(11, 12, 21),
      ball(0, extra: 'NO_BALL', wicket: {'how': 'BOX_OUT', 'out': 11})
    ], r: box);
    i = s.current!;
    expect(i.legalBalls, 0);
    expect(i.noBalls, 1);
    expect(i.wickets, 1);
    expect(i.bowlers[21]!.wickets, 1);
    // Still nothing but a run out on a no-ball other than these.
    expect(
        () => play([
              start(11, 12, 21),
              ball(0, extra: 'NO_BALL', wicket: {'how': 'BOWLED', 'out': 11})
            ], r: box),
        throwsA(isA<ScoringError>()));
  });

  test('overs cut before the match: both innings, result, balls left and NRR use it', () {
    final four = CricketRules(overs: 4, playersPerSide: 6, oversPerBowler: 1);
    MatchEvent startOvers(int s, int n, int bw, int overs) => ev('START_INNINGS', {'striker': s, 'non_striker': n, 'bowler': bw, 'overs': overs});
    List<MatchEvent> over(int bowler, [int r = 1]) => [
          ev('NEW_BOWLER', {'id': bowler}),
          for (var k = 0; k < 6; k++) ball(r)
        ];
    final first = [startOvers(11, 12, 21, 3), for (var k = 0; k < 6; k++) ball(1), ...over(22), ...over(23)];
    final s1 = play(first, r: four);
    expect(s1.rules.overs, 3);
    expect(s1.innings.first.complete, true); // 18 balls, not 24
    expect(s1.toJson()['overs_limit'], 3);
    final s2 = play([...first, start(21, 22, 11), ball(2)], r: four);
    expect((s2.toJson()['current'] as Map)['balls_left'], 17);
    // A different overs value on the second innings is ignored: the match is already 3 overs.
    expect(play([...first, startOvers(21, 22, 11, 4)], r: four).rules.overs, 3);
    expect(() => play([startOvers(11, 12, 21, 0)], r: four), throwsA(isA<ScoringError>()));
    // More overs than the tournament's works too.
    expect(play([startOvers(11, 12, 21, 6)], r: four).toJson()['overs_limit'], 6);
  });

  test('declared run: the batter\'s run and a ball, strike stays', () {
    final s = play([
      start(11, 12, 21),
      ev('BALL', {'runs': 1, 'extra': 'NONE', 'declared': true})
    ]);
    final i = s.current!;
    expect(i.runs, 1);
    expect(i.legalBalls, 1);
    expect(i.batters[11]!.runs, 1);
    expect(i.batters[11]!.balls, 1);
    expect(i.striker, 11);
    expect(i.thisOver, ['1D']);
  });

  test('over log: each over\'s bowler, balls, runs and wickets', () {
    final s = play([
      start(11, 12, 21),
      ball(1),
      ball(0, extra: 'WIDE'),
      ball(4, four: true),
      ball(0, wicket: {'how': 'BOWLED'}),
      ev('NEW_BATTER', {'id': 13, 'position': 'STRIKER'}),
      ball(0),
      ball(2),
      ball(1),
      ev('NEW_BOWLER', {'id': 22}),
      ball(6)
    ]);
    final log = s.current!.overLog;
    expect(log.length, 2);
    expect(log[0]['bowler'], 'B1');
    expect(log[0]['balls'], ['1', 'Wd', '4', 'W', '0', '2', '1']);
    expect(log[0]['runs'], 9);
    expect(log[0]['wickets'], 1);
    expect(log[1]['bowler'], 'B2');
    expect(log[1]['balls'], ['6']);
  });

  test('all out shows as "45 all out"; no-tie rule sends a league tie to a super over', () {
    final s = play([
      start(11, 12, 21),
      for (var k = 0; k < 5; k++) ...[
        ball(0, wicket: {'how': 'BOWLED'}),
        if (k < 4) ev('NEW_BATTER', {'id': 13 + k, 'position': 'STRIKER'})
      ]
    ]);
    expect(s.innings.first.wickets, 5);
    expect(s.scoreOf(s.innings.first), '0 all out');
    expect((s.toJson()['innings'] as List).first['all_out'], true);
    const noTie = CricketRules(overs: 1, playersPerSide: 6, oversPerBowler: 1, noTie: true);
    final t = play(
        [start(11, 12, 21), ball(1), ball(0), ball(0), ball(0), ball(0), ball(0), start(21, 22, 11), ball(1), ball(0), ball(0), ball(0), ball(0), ball(0)],
        r: noTie);
    expect(t.status, 'TIE_DECISION');
    expect(CricketRules.fromJson({'no_tie': true}).noTie, true);
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
