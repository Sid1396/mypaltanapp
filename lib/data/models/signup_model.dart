class SignupModel {
  final String name;
  final String pincode;
  final String city;
  final String state;
  final String area;
  final List<String> sports;
  final String skillLevel;
  final String? username;

  const SignupModel({
    required this.name,
    required this.pincode,
    required this.city,
    required this.state,
    required this.area,
    required this.sports,
    required this.skillLevel,
    this.username,
  });

  factory SignupModel.empty() => const SignupModel(
        name: '',
        pincode: '',
        city: '',
        state: '',
        area: '',
        sports: [],
        skillLevel: 'Intermediate',
      );
}
