class UserProfileModel {
  final String name;
  final String? birthdate;
  final int? age;
  final String gender;
  final String pincode;
  final String city;
  final String state;
  final String area;
  final String skillLevel;
  final String? photoUrl;
  final String? memberSince;
  final List<String> sports;

  const UserProfileModel({
    required this.name,
    this.birthdate,
    this.age,
    required this.gender,
    required this.pincode,
    required this.city,
    required this.state,
    required this.area,
    required this.skillLevel,
    this.photoUrl,
    this.memberSince,
    required this.sports,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      name: json['name']?.toString() ?? '',
      birthdate: json['birthdate']?.toString(),
      age: json['age'] is int ? json['age'] as int : null,
      gender: json['gender']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      skillLevel: json['skill_level']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      memberSince: json['member_since']?.toString(),
      sports: (json['sports'] as List?)?.map((s) => s.toString()).toList() ?? [],
    );
  }
}
