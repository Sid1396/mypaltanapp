import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../config/tournament_options.dart';
import '../../data/models/tournament.dart';

/// Editable settings for one division (age group / category) in the create-tournament wizard.
/// A simple tournament has exactly one division named "Open".
class DivisionDraft {
  int? id;
  final nameCtrl = TextEditingController();
  final entryFeeCtrl = TextEditingController();
  final prizeCtrl = TextEditingController();
  final tick = 0.obs; // bumps on text changes so validation rebuilds

  // Who can play: ages on the tournament start date (null = no limit).
  final minAge = Rx<int?>(null);
  final maxAge = Rx<int?>(null);

  // Format
  final format = ''.obs;
  final maxTeams = 8.obs;
  final groupCount = 2.obs;
  final qualifyPerGroup = 2.obs;
  final squadMin = 6.obs;
  final squadMax = 25.obs;

  // Cricket
  final matchType = 'LIMITED_OVERS'.obs;
  final ballType = 'TENNIS'.obs;
  final pitchType = ''.obs;
  final playersPerSide = 11.obs;
  final overs = 10.obs;
  final oversPerBowler = 2.obs;
  final powerplayOvers = 0.obs;
  final lastBatter = false.obs;
  // Football
  final footballPlayers = 7.obs;
  final halfMinutes = 20.obs;
  final rollingSubs = true.obs;
  final extraTime = false.obs;
  final penalties = true.obs;
  // Badminton / pickleball
  final racketEvent = 'DOUBLES'.obs;
  final pointsPerGame = 21.obs;
  final games = 3.obs;
  final winByTwo = true.obs;
  final scoring = 'SIDE_OUT'.obs;

  // Points table
  final ptsWin = 2.obs;
  final ptsTie = 1.obs;
  final ptsNoResult = 1.obs;
  final ptsLoss = 0.obs;
  final tiebreakers = <String>[].obs;

  // Fee & prize
  final prizeType = 'NONE'.obs;

  DivisionDraft({String name = 'Open', String? sport}) {
    nameCtrl.text = name;
    for (final c in [nameCtrl, entryFeeCtrl, prizeCtrl]) {
      c.addListener(() => tick.value++);
    }
    if (sport != null && sport.isNotEmpty) applySportDefaults(sport);
    _ageFromName(name);
  }

  void dispose() {
    for (final c in [nameCtrl, entryFeeCtrl, prizeCtrl]) {
      c.dispose();
    }
  }

  String get name => nameCtrl.text.trim();
  int get entryFee => int.tryParse(entryFeeCtrl.text.trim()) ?? 0;

  /// "Under 13" sets the age limit to 12 or younger; "Veterans 40+" to 40 or older.
  void _ageFromName(String name) {
    final under = RegExp(r'^under\s*(\d{1,2})$', caseSensitive: false).firstMatch(name.trim());
    final over = RegExp(r'(\d{2})\s*\+$').firstMatch(name.trim());
    if (under != null) {
      maxAge.value = int.parse(under.group(1)!) - 1;
      minAge.value = null;
    } else if (over != null) {
      minAge.value = int.parse(over.group(1)!);
      maxAge.value = null;
    }
  }

  void applySportDefaults(String sport) {
    final (sMin, sMax) = TournamentOptions.squadDefaults[sport]!;
    squadMin.value = sMin;
    squadMax.value = sMax;
    pointsPerGame.value = sport == 'PICKLEBALL' ? 11 : 21;
    final (w, t, n, l) = TournamentOptions.pointDefaults[sport]!;
    ptsWin.value = w;
    ptsTie.value = t;
    ptsNoResult.value = n;
    ptsLoss.value = l;
    tiebreakers.assignAll(TournamentOptions.tiebreakerDefaults[sport]!);
  }

  void setMatchType(String type) {
    matchType.value = type;
    switch (type) {
      case 'BOX':
        playersPerSide.value = 8;
        overs.value = 6;
      case 'PAIR':
        playersPerSide.value = 8;
        overs.value = 8;
      case 'THE_HUNDRED':
        playersPerSide.value = 11;
        overs.value = 17; // 100 balls, rounded up to overs
      case 'LIMITED_OVERS':
        playersPerSide.value = 11;
        overs.value = 10;
    }
    oversPerBowler.value = (overs.value / 5).ceil();
    if (powerplayOvers.value > overs.value) powerplayOvers.value = 0;
  }

  void setOvers(int v) {
    overs.value = v;
    if (oversPerBowler.value > v) oversPerBowler.value = v;
    if (powerplayOvers.value > v) powerplayOvers.value = v;
  }

  void toggleTiebreaker(String code) => tiebreakers.contains(code) ? tiebreakers.remove(code) : tiebreakers.add(code);

  /// Copies every setting except the name, id and age limit.
  void copyFrom(DivisionDraft o) {
    format.value = o.format.value;
    maxTeams.value = o.maxTeams.value;
    groupCount.value = o.groupCount.value;
    qualifyPerGroup.value = o.qualifyPerGroup.value;
    squadMin.value = o.squadMin.value;
    squadMax.value = o.squadMax.value;
    matchType.value = o.matchType.value;
    ballType.value = o.ballType.value;
    pitchType.value = o.pitchType.value;
    playersPerSide.value = o.playersPerSide.value;
    overs.value = o.overs.value;
    oversPerBowler.value = o.oversPerBowler.value;
    powerplayOvers.value = o.powerplayOvers.value;
    lastBatter.value = o.lastBatter.value;
    footballPlayers.value = o.footballPlayers.value;
    halfMinutes.value = o.halfMinutes.value;
    rollingSubs.value = o.rollingSubs.value;
    extraTime.value = o.extraTime.value;
    penalties.value = o.penalties.value;
    racketEvent.value = o.racketEvent.value;
    pointsPerGame.value = o.pointsPerGame.value;
    games.value = o.games.value;
    winByTwo.value = o.winByTwo.value;
    scoring.value = o.scoring.value;
    ptsWin.value = o.ptsWin.value;
    ptsTie.value = o.ptsTie.value;
    ptsNoResult.value = o.ptsNoResult.value;
    ptsLoss.value = o.ptsLoss.value;
    tiebreakers.assignAll(o.tiebreakers);
    entryFeeCtrl.text = o.entryFeeCtrl.text;
    prizeType.value = o.prizeType.value;
    prizeCtrl.text = o.prizeCtrl.text;
  }

  // ─── Validation (mirrors the server) ──────────────────────────

  String? validate(String kind, String sport) {
    tick.value;
    switch (kind) {
      case 'format':
        if (format.value.isEmpty) return 'Choose a format.';
        if (squadMax.value < squadMin.value) return 'Maximum squad size must be at least the minimum.';
        if (minAge.value != null && maxAge.value != null && minAge.value! > maxAge.value!) return 'The age limit is not valid.';
        if (format.value == 'LEAGUE_KNOCKOUT') {
          if (maxTeams.value / groupCount.value < 2) return 'Each group needs at least 2 teams.';
          if (qualifyPerGroup.value >= (maxTeams.value / groupCount.value).ceil()) return 'Fewer teams must qualify than play in each group.';
        }
        return null;
      case 'rules':
        if (sport == 'CRICKET' && matchType.value != 'TEST') {
          if (oversPerBowler.value > overs.value) return 'Overs per bowler cannot exceed overs per innings.';
          if (powerplayOvers.value > overs.value) return 'Powerplay cannot be longer than the innings.';
        }
        return null;
      case 'points':
        if (tiebreakers.isEmpty) return 'Choose at least one tie-breaker.';
        return null;
      case 'fees':
        final raw = entryFeeCtrl.text.trim();
        if (raw.isNotEmpty && (int.tryParse(raw) == null || entryFee < 0 || entryFee > 100000)) {
          return 'Entry fee must be between ₹0 and ₹1,00,000.';
        }
        if (prizeCtrl.text.trim().length > 255) return 'Prize details must be under 255 characters.';
        return null;
    }
    return null;
  }

  // ─── Server format ────────────────────────────────────────────

  Map<String, dynamic> _matchRules(String sport) => switch (sport) {
        'CRICKET' => {
            'match_type': matchType.value,
            'ball_type': ballType.value,
            if (pitchType.value.isNotEmpty) 'pitch_type': pitchType.value,
            'players_per_side': playersPerSide.value,
            'last_batter': lastBatter.value,
            if (matchType.value != 'TEST') ...{
              'overs': overs.value,
              'overs_per_bowler': oversPerBowler.value,
              'powerplay_overs': powerplayOvers.value,
            },
          },
        'FOOTBALL' => {
            'players_per_side': footballPlayers.value,
            'half_minutes': halfMinutes.value,
            'rolling_subs': rollingSubs.value,
            'extra_time': extraTime.value,
            'penalties': penalties.value,
          },
        _ => {
            'event': racketEvent.value,
            'points_per_game': pointsPerGame.value,
            'games': games.value,
            'win_by_two': winByTwo.value,
            if (sport == 'PICKLEBALL') 'scoring': scoring.value,
          },
      };

  Map<String, dynamic> toJson(String sport) => {
        'id': id,
        'name': name.isEmpty ? 'Open' : name,
        'min_age': minAge.value,
        'max_age': maxAge.value,
        'format': format.value,
        if (format.value == 'LEAGUE_KNOCKOUT') ...{'group_count': groupCount.value, 'qualify_per_group': qualifyPerGroup.value},
        'max_teams': maxTeams.value,
        'squad_min': squadMin.value,
        'squad_max': squadMax.value,
        'entry_fee': entryFee,
        'prize_type': prizeType.value,
        'prize_details': prizeType.value == 'NONE' || prizeCtrl.text.trim().isEmpty ? null : prizeCtrl.text.trim(),
        'match_rules': _matchRules(sport),
        'points': {
          'win': ptsWin.value,
          'tie': ptsTie.value,
          'no_result': ptsNoResult.value,
          'loss': ptsLoss.value,
          'tiebreakers': tiebreakers.toList(),
        },
      };

  void fill(TournamentDivision d, String sport) {
    id = d.id;
    nameCtrl.text = d.name;
    minAge.value = d.minAge;
    maxAge.value = d.maxAge;
    format.value = d.format;
    maxTeams.value = d.maxTeams;
    groupCount.value = d.groupCount ?? 2;
    qualifyPerGroup.value = d.qualifyPerGroup ?? 2;
    squadMin.value = d.squadMin;
    squadMax.value = d.squadMax;
    final r = d.matchRules;
    int ri(String k, int f) => (r[k] as num?)?.toInt() ?? f;
    bool rb(String k, bool f) => r[k] is bool ? r[k] as bool : f;
    if (sport == 'CRICKET') {
      matchType.value = r['match_type']?.toString() ?? 'LIMITED_OVERS';
      ballType.value = r['ball_type']?.toString() ?? 'TENNIS';
      pitchType.value = r['pitch_type']?.toString() ?? '';
      playersPerSide.value = ri('players_per_side', 11);
      overs.value = ri('overs', 10);
      oversPerBowler.value = ri('overs_per_bowler', 2);
      powerplayOvers.value = ri('powerplay_overs', 0);
      lastBatter.value = rb('last_batter', false);
    } else if (sport == 'FOOTBALL') {
      footballPlayers.value = ri('players_per_side', 7);
      halfMinutes.value = ri('half_minutes', 20);
      rollingSubs.value = rb('rolling_subs', true);
      extraTime.value = rb('extra_time', false);
      penalties.value = rb('penalties', true);
    } else {
      racketEvent.value = r['event']?.toString() ?? 'DOUBLES';
      pointsPerGame.value = ri('points_per_game', 21);
      games.value = ri('games', 3);
      winByTwo.value = rb('win_by_two', true);
      scoring.value = r['scoring']?.toString() ?? 'SIDE_OUT';
    }
    final p = d.points;
    ptsWin.value = (p['win'] as num?)?.toInt() ?? ptsWin.value;
    ptsTie.value = (p['tie'] as num?)?.toInt() ?? ptsTie.value;
    ptsNoResult.value = (p['no_result'] as num?)?.toInt() ?? ptsNoResult.value;
    ptsLoss.value = (p['loss'] as num?)?.toInt() ?? ptsLoss.value;
    final tbs = p['tiebreakers'] is List ? (p['tiebreakers'] as List).map((e) => '$e').toList() : [if (p['tiebreaker'] != null) '${p['tiebreaker']}'];
    final allowed = TournamentOptions.tiebreakers[sport]!.map((e) => e.$1).toSet();
    final kept = tbs.where(allowed.contains).toList();
    if (kept.isNotEmpty) tiebreakers.assignAll(kept);
    entryFeeCtrl.text = d.entryFee > 0 ? '${d.entryFee}' : '';
    prizeType.value = d.prizeType;
    prizeCtrl.text = d.prizeDetails ?? '';
  }
}
