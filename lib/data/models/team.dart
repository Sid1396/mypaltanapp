int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
String? _str(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';

/// A player on a team: either someone with a MyPaltan account, or a child added by the coach.
class TeamMember {
  final int id;
  final String role; // CAPTAIN, VICE_CAPTAIN, PLAYER
  final String? position;
  final String? jerseyName;
  final int? jerseyNumber;
  final String name;
  final String? photoUrl;
  final int? age;
  final bool isGuest;
  final bool isMe;
  // Coach-added players only, visible to the captain and vice-captain.
  final String? birthdate;
  final String? gender;
  final String? parentPhone;

  const TeamMember({
    required this.id,
    required this.role,
    this.position,
    this.jerseyName,
    this.jerseyNumber,
    required this.name,
    this.photoUrl,
    this.age,
    required this.isGuest,
    required this.isMe,
    this.birthdate,
    this.gender,
    this.parentPhone,
  });

  bool get isCoach => role == 'COACH';
  bool get isCaptain => role == 'CAPTAIN';
  bool get isVice => role == 'VICE_CAPTAIN';

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        id: _int(j['id']),
        role: j['role']?.toString() ?? 'PLAYER',
        position: _str(j['position']),
        jerseyName: _str(j['jersey_name']),
        jerseyNumber: j['jersey_number'] == null ? null : _int(j['jersey_number']),
        name: j['name']?.toString() ?? '',
        photoUrl: _str(j['photo_url']),
        age: j['age'] == null ? null : _int(j['age']),
        isGuest: j['is_guest'] == true,
        isMe: j['is_me'] == true,
        birthdate: _str(j['birthdate']),
        gender: _str(j['gender']),
        parentPhone: _str(j['parent_phone']),
      );
}

class Team {
  final String code;
  final String sport;
  final String name;
  final String shortName;
  final String? logoUrl;
  final String? logoKey;
  final String area;
  final String city;
  final int members;
  /// The adult who runs the team: a coach, or the captain if they play.
  final String captainName;
  final String? captainPhotoUrl;
  final String managerRole;
  final String? myRole;
  final bool removed;
  final List<TeamMember> roster;

  const Team({
    required this.code,
    required this.sport,
    required this.name,
    required this.shortName,
    this.logoUrl,
    this.logoKey,
    required this.area,
    required this.city,
    required this.members,
    required this.captainName,
    this.captainPhotoUrl,
    this.managerRole = 'CAPTAIN',
    this.myRole,
    this.removed = false,
    this.roster = const [],
  });

  bool get isMember => myRole != null;
  bool get isCaptain => myRole == 'CAPTAIN';
  bool get isCoach => myRole == 'COACH';

  /// Coaches and the captain run the team; the vice-captain can add and remove players.
  bool get isAdmin => myRole == 'COACH' || myRole == 'CAPTAIN';
  bool get canManage => isAdmin || myRole == 'VICE_CAPTAIN';
  List<TeamMember> get coaches => roster.where((m) => m.isCoach).toList();
  List<TeamMember> get players => roster.where((m) => !m.isCoach).toList();
  String get location => [area, city].where((s) => s.isNotEmpty).join(', ');

  factory Team.fromJson(Map<String, dynamic> j) {
    final cap = Map<String, dynamic>.from(j['captain'] as Map? ?? {});
    return Team(
      code: j['code']?.toString() ?? '',
      sport: j['sport']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      shortName: j['short_name']?.toString() ?? '',
      logoUrl: _str(j['logo_url']),
      logoKey: _str(j['logo_key']),
      area: j['area']?.toString() ?? '',
      city: j['city']?.toString() ?? 'Mumbai',
      members: _int(j['members']),
      captainName: cap['name']?.toString() ?? '',
      captainPhotoUrl: _str(cap['photo_url']),
      managerRole: cap['role']?.toString() ?? 'CAPTAIN',
      myRole: _str(j['my_role']),
      removed: j['removed'] == true,
      roster: (j['roster'] as List? ?? []).whereType<Map>().map((m) => TeamMember.fromJson(Map<String, dynamic>.from(m))).toList(),
    );
  }
}

/// Row in My Teams.
class MyTeam {
  final String code;
  final String name;
  final String shortName;
  final String sport;
  final String? logoUrl;
  final String area;
  final String role;
  final int members;

  const MyTeam({
    required this.code,
    required this.name,
    required this.shortName,
    required this.sport,
    this.logoUrl,
    required this.area,
    required this.role,
    required this.members,
  });

  factory MyTeam.fromJson(Map<String, dynamic> j) => MyTeam(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        shortName: j['short_name']?.toString() ?? '',
        sport: j['sport']?.toString() ?? '',
        logoUrl: _str(j['logo_url']),
        area: j['area']?.toString() ?? '',
        role: j['role']?.toString() ?? 'PLAYER',
        members: _int(j['members']),
      );
}

/// What a squad link offers: joining a team's squad for one tournament.
class SquadInvite {
  final String tournamentCode;
  final String tournamentName;
  final String? division;
  final int squadCount;
  final int? squadMax;
  final bool inTeam;
  final bool inSquad;
  final String? problem; // why the user cannot join, or null

  const SquadInvite({
    required this.tournamentCode,
    required this.tournamentName,
    this.division,
    required this.squadCount,
    this.squadMax,
    required this.inTeam,
    required this.inSquad,
    this.problem,
  });

  factory SquadInvite.fromJson(Map<String, dynamic> j) => SquadInvite(
        tournamentCode: j['tournament_code']?.toString() ?? '',
        tournamentName: j['tournament_name']?.toString() ?? '',
        division: j['division']?.toString(),
        squadCount: (j['squad_count'] as num?)?.toInt() ?? 0,
        squadMax: (j['squad_max'] as num?)?.toInt(),
        inTeam: j['in_team'] == true,
        inSquad: j['in_squad'] == true,
        problem: j['problem']?.toString(),
      );
}
