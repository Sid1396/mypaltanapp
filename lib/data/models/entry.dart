int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
int? _intOrNull(dynamic v) => v == null ? null : _int(v);
String? _str(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';
List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

/// A division as seen when registering: limits, fee and how many places are confirmed.
class RegDivision {
  final int id;
  final String name;
  final int? minAge;
  final int? maxAge;
  final int squadMin;
  final int squadMax;
  final int maxTeams;
  final int entryFee;
  final int approved;

  const RegDivision({
    required this.id,
    required this.name,
    this.minAge,
    this.maxAge,
    required this.squadMin,
    required this.squadMax,
    required this.maxTeams,
    required this.entryFee,
    required this.approved,
  });

  bool get isFull => approved >= maxTeams;
  int get placesLeft => (maxTeams - approved).clamp(0, maxTeams);
  String? get ageLabel => minAge == null && maxAge == null
      ? null
      : minAge == null
          ? 'Under ${maxAge! + 1}'
          : maxAge == null
              ? '$minAge and over'
              : 'Ages $minAge to $maxAge';

  /// Why a player of this age cannot play in this division, or null if they can.
  String? ageProblem(int? age) {
    if (age == null) return 'No date of birth';
    if (maxAge != null && age > maxAge!) return 'Will be $age, too old';
    if (minAge != null && age < minAge!) return 'Will be $age, too young';
    return null;
  }

  factory RegDivision.fromJson(Map<String, dynamic> j) => RegDivision(
        id: _int(j['id']),
        name: j['name']?.toString() ?? '',
        minAge: _intOrNull(j['min_age']),
        maxAge: _intOrNull(j['max_age']),
        squadMin: _int(j['squad_min'], 1),
        squadMax: _int(j['squad_max'], 1),
        maxTeams: _int(j['max_teams'], 2),
        entryFee: _int(j['entry_fee']),
        approved: _int(j['approved']),
      );
}

class RegPlayer {
  final int memberId;
  final int? userId;
  final String name;
  final String? photoUrl;
  final String? position;
  final bool isGuest;
  final int? age; // on the tournament's first day
  final int? jerseyNumber;

  const RegPlayer({
    required this.memberId,
    this.userId,
    required this.name,
    this.photoUrl,
    this.position,
    required this.isGuest,
    this.age,
    this.jerseyNumber,
  });

  factory RegPlayer.fromJson(Map<String, dynamic> j) => RegPlayer(
        memberId: _int(j['member_id']),
        userId: _intOrNull(j['user_id']),
        name: j['name']?.toString() ?? '',
        photoUrl: _str(j['photo_url']),
        position: _str(j['position']),
        isGuest: j['is_guest'] == true,
        age: _intOrNull(j['age']),
        jerseyNumber: _intOrNull(j['jersey_number']),
      );
}

class RegTeam {
  final String code;
  final String name;
  final String? logoUrl;
  final String myRole;
  final List<RegPlayer> players;

  const RegTeam({required this.code, required this.name, this.logoUrl, required this.myRole, required this.players});

  factory RegTeam.fromJson(Map<String, dynamic> j) => RegTeam(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        logoUrl: _str(j['logo_url']),
        myRole: j['my_role']?.toString() ?? 'PLAYER',
        players: _maps(j['players']).map(RegPlayer.fromJson).toList(),
      );
}

/// A registration by one of the teams the user manages.
class MyEntry {
  final int id;
  final String teamCode;
  final String teamName;
  final int? divisionId;
  final String status; // PENDING, APPROVED, REJECTED, WAITLISTED, WITHDRAWN
  final int amount;
  final String paymentMethod;
  final String? rejectReason;
  final int players;
  final List<int> memberIds; // team member ids in the squad

  const MyEntry({
    required this.id,
    required this.teamCode,
    required this.teamName,
    this.divisionId,
    required this.status,
    required this.amount,
    required this.paymentMethod,
    this.rejectReason,
    required this.players,
    this.memberIds = const [],
  });

  bool get isActive => status == 'PENDING' || status == 'WAITLISTED' || status == 'APPROVED';

  factory MyEntry.fromJson(Map<String, dynamic> j) => MyEntry(
        id: _int(j['id']),
        teamCode: j['team_code']?.toString() ?? '',
        teamName: j['team_name']?.toString() ?? '',
        divisionId: _intOrNull(j['division_id']),
        status: j['status']?.toString() ?? 'PENDING',
        amount: _int(j['amount']),
        paymentMethod: j['payment_method']?.toString() ?? 'NONE',
        rejectReason: _str(j['reject_reason']),
        players: _int(j['players']),
        memberIds: (j['member_ids'] as List? ?? []).map((v) => _int(v)).toList(),
      );
}

class RegPayment {
  final String upiId;
  final String upiName;
  final String? qrUrl;
  final bool acceptCash;
  final String? note;

  const RegPayment({required this.upiId, required this.upiName, this.qrUrl, required this.acceptCash, this.note});

  factory RegPayment.fromJson(Map<String, dynamic> j) => RegPayment(
        upiId: j['upi_id']?.toString() ?? '',
        upiName: j['upi_name']?.toString() ?? '',
        qrUrl: _str(j['qr_url']),
        acceptCash: j['accept_cash'] == true,
        note: _str(j['note']),
      );
}

/// Everything needed to register a team: divisions, the user's teams and players, existing registrations.
class RegOptions {
  final String code;
  final String name;
  final String sport;
  final String? startDate;
  final String? registrationDeadline;
  final bool open;
  final bool isOwner;
  final List<RegDivision> divisions;
  final List<RegTeam> teams;
  final List<MyEntry> myEntries;
  final List<({int userId, String teamCode, String teamName})> taken; // players already in another squad
  final RegPayment? payment;

  const RegOptions({
    required this.code,
    required this.name,
    required this.sport,
    this.startDate,
    this.registrationDeadline,
    required this.open,
    required this.isOwner,
    required this.divisions,
    required this.teams,
    required this.myEntries,
    required this.taken,
    this.payment,
  });

  factory RegOptions.fromJson(Map<String, dynamic> j) => RegOptions(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        sport: j['sport']?.toString() ?? '',
        startDate: _str(j['start_date']),
        registrationDeadline: _str(j['registration_deadline']),
        open: j['open'] == true,
        isOwner: j['is_owner'] == true,
        divisions: _maps(j['divisions']).map(RegDivision.fromJson).toList(),
        teams: _maps(j['teams']).map(RegTeam.fromJson).toList(),
        myEntries: _maps(j['my_entries']).map(MyEntry.fromJson).toList(),
        taken: [
          for (final t in _maps(j['taken']))
            (userId: _int(t['user_id']), teamCode: t['team_code']?.toString() ?? '', teamName: t['team_name']?.toString() ?? 'another team'),
        ],
        payment: j['payment'] is Map ? RegPayment.fromJson(Map<String, dynamic>.from(j['payment'] as Map)) : null,
      );
}

/// Why a player cannot be in [teamCode]'s squad for division [d], or null if they can.
String? squadBlockReason(RegPlayer p, RegDivision? d, RegOptions o, String teamCode) {
  if (d != null && (d.minAge != null || d.maxAge != null)) {
    final age = d.ageProblem(p.age);
    if (age != null) return age;
  }
  if (p.userId != null) {
    final other = o.taken.where((t) => t.userId == p.userId && t.teamCode != teamCode).firstOrNull;
    if (other != null) return "In ${other.teamName}'s squad";
  }
  return null;
}

/// A registration as the organiser (or, when confirmed, anyone) sees it.
class TournamentEntry {
  final int id;
  final String status;
  final int? divisionId;
  final String? division;
  final int squadMin;
  final int squadMax;
  final String teamCode;
  final String teamName;
  final String? logoUrl;
  final List<EntryPlayer> squad;
  // Organiser only
  final String? paymentMethod;
  final int amount;
  final String? utr;
  final String? proofUrl;
  final String? rejectReason;
  final String? registeredBy;
  final String? registeredPhone;
  final String? createdAt;

  const TournamentEntry({
    required this.id,
    required this.status,
    this.divisionId,
    this.division,
    this.squadMin = 0,
    this.squadMax = 0,
    required this.teamCode,
    required this.teamName,
    this.logoUrl,
    required this.squad,
    this.paymentMethod,
    this.amount = 0,
    this.utr,
    this.proofUrl,
    this.rejectReason,
    this.registeredBy,
    this.registeredPhone,
    this.createdAt,
  });

  factory TournamentEntry.fromJson(Map<String, dynamic> j) => TournamentEntry(
        id: _int(j['id']),
        status: j['status']?.toString() ?? 'PENDING',
        divisionId: _intOrNull(j['division_id']),
        division: _str(j['division']),
        squadMin: _int(j['squad_min']),
        squadMax: _int(j['squad_max']),
        teamCode: j['team_code']?.toString() ?? '',
        teamName: j['team_name']?.toString() ?? '',
        logoUrl: _str(j['logo_url']),
        squad: _maps(j['squad']).map(EntryPlayer.fromJson).toList(),
        paymentMethod: _str(j['payment_method']),
        amount: _int(j['amount']),
        utr: _str(j['utr']),
        proofUrl: _str(j['proof_url']),
        rejectReason: _str(j['reject_reason']),
        registeredBy: _str(j['registered_by']),
        registeredPhone: _str(j['registered_phone']),
        createdAt: _str(j['created_at']),
      );
}

class EntryPlayer {
  final String name;
  final String? photoUrl;
  final int? jerseyNumber;
  final bool isGuest;
  final int? age;

  const EntryPlayer({required this.name, this.photoUrl, this.jerseyNumber, required this.isGuest, this.age});

  factory EntryPlayer.fromJson(Map<String, dynamic> j) => EntryPlayer(
        name: j['name']?.toString() ?? '',
        photoUrl: _str(j['photo_url']),
        jerseyNumber: _intOrNull(j['jersey_number']),
        isGuest: j['is_guest'] == true,
        age: _intOrNull(j['age']),
      );
}
