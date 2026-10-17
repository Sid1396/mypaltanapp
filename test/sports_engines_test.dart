import 'package:flutter_test/flutter_test.dart';
import 'package:mypaltan/scoring/cricket_engine.dart';
import 'package:mypaltan/scoring/football_engine.dart';
import 'package:mypaltan/scoring/racket_engine.dart';

var _n = 0;
MatchEvent ev(String type, [Map<String, dynamic> data = const {}]) => MatchEvent('e${_n++}', type, data);

const fPlayers = {
  1: [PlayerRef(11, 'H1'), PlayerRef(12, 'H2')],
  2: [PlayerRef(21, 'A1'), PlayerRef(22, 'A2')],
};
const league = FootballSetup(homeEntry: 1, awayEntry: 2, players: fPlayers);
const ko = FootballSetup(homeEntry: 1, awayEntry: 2, players: fPlayers, knockout: true);
const fRules = FootballRules(halfMinutes: 20, extraTime: true, penalties: true);
FootballState fb(List<MatchEvent> e, {FootballSetup s = league, FootballRules r = fRules}) => FootballEngine.replay(s, r, e);
MatchEvent goal(int team, [int? scorer]) => ev('GOAL', {'team': team, if (scorer != null) 'scorer': scorer, 'minute': 10});
MatchEvent pen(int team, bool scored) => ev('SHOOTOUT_KICK', {'team': team, 'scored': scored});

const rs = RacketSetup(homeEntry: 1, awayEntry: 2, players: {1: [PlayerRef(11, 'H')], 2: [PlayerRef(21, 'A')]});
RacketState rk(RacketRules r, List<MatchEvent> e) => RacketEngine.replay(rs, r, e);
List<MatchEvent> points(int team, int n) => [for (var i = 0; i < n; i++) ev('POINT', {'team': team})];

void main() {
  group('football', () {
    test('two halves, goals, result', () {
      final s = fb([ev('KICK_OFF', {'at': 1}), goal(1, 11), ev('PERIOD_END'), ev('START_PERIOD', {'at': 2}), goal(2, 21), goal(1, 12), ev('PERIOD_END')]);
      expect(s.phase, 'COMPLETED');
      expect(s.toJson()['score'], {'home': 2, 'away': 1});
      expect(s.result, '{1} won 2-1');
      expect(s.outcome, 'WIN');
      expect((s.toJson()['timeline'] as List).first['text'], 'Full time');
    });

    test('no goals outside play, draw in a league', () {
      expect(() => fb([goal(1)]), throwsA(isA<ScoringError>()));
      expect(() => fb([ev('KICK_OFF'), ev('PERIOD_END'), goal(1)]), throwsA(isA<ScoringError>()));
      final s = fb([ev('KICK_OFF'), ev('PERIOD_END'), ev('START_PERIOD'), ev('PERIOD_END')]);
      expect(s.result, 'Match drawn 0-0');
      expect(s.outcome, 'TIE');
    });

    test('knockout draw: extra time, then penalties decided early', () {
      final reg = [ev('KICK_OFF'), goal(1), ev('PERIOD_END'), ev('START_PERIOD'), goal(2), ev('PERIOD_END')];
      expect(fb(reg, s: ko).phase, 'ET_BREAK');
      final et = [...reg, ev('START_PERIOD'), ev('PERIOD_END'), ev('START_PERIOD'), ev('PERIOD_END')];
      expect(fb(et, s: ko).phase, 'PENALTIES');
      // Home 3/3, away 0/3: away cannot catch up.
      final s = fb([...et, pen(1, true), pen(2, false), pen(1, true), pen(2, false), pen(1, true), pen(2, false)], s: ko);
      expect(s.phase, 'COMPLETED');
      expect(s.result, '{1} won 3-0 on penalties (1-1)');
      expect(s.toJson()['summary'], {'1': '1 (3)', '2': '1 (0)'});
      expect(() => fb([...et, pen(1, true), pen(1, true)], s: ko), throwsA(isA<ScoringError>()), reason: 'teams alternate');
    });

    test('penalties go to sudden death after five each', () {
      final reg = [ev('KICK_OFF'), ev('PERIOD_END'), ev('START_PERIOD'), ev('PERIOD_END')];
      final level = [for (var i = 0; i < 5; i++) ...[pen(1, true), pen(2, true)]];
      const noEt = FootballRules(halfMinutes: 20, extraTime: false, penalties: true);
      expect(fb([...reg, ...level], s: ko, r: noEt).phase, 'PENALTIES');
      expect(fb([...reg, ...level, pen(1, true), pen(2, false)], s: ko, r: noEt).result, '{1} won 6-5 on penalties (0-0)');
    });

    test('second yellow is a red; sent-off players cannot score', () {
      final s = fb([ev('KICK_OFF'), ev('CARD', {'team': 1, 'player': 11, 'color': 'YELLOW'}), ev('CARD', {'team': 1, 'player': 11, 'color': 'YELLOW'})]);
      expect((s.toJson()['timeline'] as List).first['color'], 'RED');
      expect(s.sentOff, contains(11));
      expect(() => fb([ev('KICK_OFF'), ev('CARD', {'team': 1, 'player': 11, 'color': 'RED'}), goal(1, 11)]), throwsA(isA<ScoringError>()));
    });

    test('undo', () {
      final s = fb([ev('KICK_OFF'), goal(1), goal(1), ev('UNDO')]);
      expect(s.home, 1);
    });
  });

  group('racket', () {
    const badminton = RacketRules(pointsPerGame: 21, games: 3, cap: 30, doubles: false);
    test('badminton: rally scoring, win by two, best of three', () {
      final s = rk(badminton, [ev('START', {'server': 1}), ...points(1, 21), ...points(2, 19)]);
      expect(s.games, [{'home': 21, 'away': 0}]);
      expect(s.home, 0);
      expect(s.away, 19, reason: 'game 2 in progress after game 1 ended at 21-0');
      final s2 = rk(badminton, [ev('START', {'server': 1}), ...points(1, 21), ...points(2, 21), ...points(1, 21)]);
      expect(s2.status, 'COMPLETED');
      expect(s2.result, '{1} won 21-0, 0-21, 21-0');
    });

    test('badminton: deuce needs two clear points, 30 caps it', () {
      final events = [ev('START', {'server': 1}), for (var i = 0; i < 20; i++) ...[...points(1, 1), ...points(2, 1)]];
      final at20 = rk(badminton, [...events, ...points(1, 1)]);
      expect(at20.games, isEmpty, reason: '21-20 is not enough');
      final won = rk(badminton, [...events, ...points(1, 2)]);
      expect(won.games, [{'home': 22, 'away': 20}]);
      final deuce = [ev('START', {'server': 1}), for (var i = 0; i < 29; i++) ...[...points(1, 1), ...points(2, 1)]];
      expect(rk(badminton, [...deuce, ...points(2, 1)]).games, [{'home': 29, 'away': 30}]);
    });

    test('pickleball side-out doubles: only the server scores, 0-0-2 start, two servers', () {
      const pb = RacketRules(pointsPerGame: 11, games: 3, sideOut: true, doubles: true);
      var s = rk(pb, [ev('START', {'server': 1})]);
      expect(s.call, '0-0-2');
      s = rk(pb, [ev('START', {'server': 1}), ...points(1, 2)]);
      expect(s.call, '2-0-2');
      s = rk(pb, [ev('START', {'server': 1}), ...points(1, 2), ...points(2, 1)]);
      expect(s.server, 2, reason: 'first service turn has one server: side out');
      expect(s.call, '0-2-1');
      expect(s.toJson()['current']['home'], 2);
      s = rk(pb, [ev('START', {'server': 1}), ...points(1, 2), ...points(2, 1), ...points(1, 1)]);
      expect(s.call, '0-2-2', reason: 'server 1 lost the rally: server 2');
      s = rk(pb, [ev('START', {'server': 1}), ...points(1, 2), ...points(2, 1), ...points(1, 2)]);
      expect(s.server, 1);
      expect(s.call, '2-0-1');
    });

    test('pickleball rally scoring to 11', () {
      const pb = RacketRules(pointsPerGame: 11, games: 1, sideOut: false, doubles: true);
      final s = rk(pb, [ev('START', {'server': 2}), ...points(2, 11)]);
      expect(s.status, 'COMPLETED');
      expect(s.winner, 2);
      expect(s.toJson()['summary'], {'1': '0', '2': '11'});
    });
  });
}
