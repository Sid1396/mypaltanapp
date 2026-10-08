class SportRole {
  final String sport;
  final String role;
  final String? battingHand;
  final String? bowlingStyle;

  const SportRole({
    required this.sport,
    required this.role,
    this.battingHand,
    this.bowlingStyle,
  });

  factory SportRole.fromJson(Map<String, dynamic> json) => SportRole(
        sport: json['sport']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        battingHand: json['batting_hand']?.toString(),
        bowlingStyle: json['bowling_style']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'sport': sport,
        'role': role,
        if (battingHand != null) 'batting_hand': battingHand,
        if (bowlingStyle != null) 'bowling_style': bowlingStyle,
      };
}

class AppUser {
  final String phone;
  final String? name;
  final DateTime? birthdate;
  final int? age;
  final String? gender;
  final String? jerseyName;
  final int? jerseyNumber;
  final String? jerseySize;
  final String? photoUrl;
  final List<SportRole> sports;
  final String? memberSince;
  final bool profileComplete;

  const AppUser({
    required this.phone,
    this.name,
    this.birthdate,
    this.age,
    this.gender,
    this.jerseyName,
    this.jerseyNumber,
    this.jerseySize,
    this.photoUrl,
    this.sports = const [],
    this.memberSince,
    this.profileComplete = false,
  });

  String get firstName => (name ?? '').trim().split(' ').first;

  String get initials {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        phone: json['phone']?.toString() ?? '',
        name: json['name']?.toString(),
        birthdate: DateTime.tryParse(json['birthdate']?.toString() ?? ''),
        age: json['age'] is num ? (json['age'] as num).toInt() : null,
        gender: json['gender']?.toString(),
        jerseyName: json['jersey_name']?.toString(),
        jerseyNumber: json['jersey_number'] is num ? (json['jersey_number'] as num).toInt() : null,
        jerseySize: json['jersey_size']?.toString(),
        photoUrl: json['photo_url']?.toString(),
        sports: ((json['sports'] as List?) ?? [])
            .whereType<Map>()
            .map((s) => SportRole.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
        memberSince: json['member_since']?.toString(),
        profileComplete: json['profile_complete'] == true,
      );
}
