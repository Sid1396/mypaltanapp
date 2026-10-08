class SportOption {
  final String code;
  final String label;
  final String asset;
  final List<(String, String)> roles;

  const SportOption(this.code, this.label, this.asset, this.roles);
}

class Sports {
  Sports._();

  static const all = [
    SportOption('CRICKET', 'Cricket', 'assets/images/turfcricket.png', [
      ('BATTER', 'Batter'),
      ('BOWLER', 'Bowler'),
      ('ALL_ROUNDER', 'All-rounder'),
      ('WICKETKEEPER', 'Wicketkeeper'),
    ]),
    SportOption('FOOTBALL', 'Football', 'assets/images/football.png', [
      ('GOALKEEPER', 'Goalkeeper'),
      ('DEFENDER', 'Defender'),
      ('MIDFIELDER', 'Midfielder'),
      ('FORWARD', 'Forward'),
    ]),
    SportOption('BADMINTON', 'Badminton', 'assets/images/badminton.png', [
      ('SINGLES', 'Singles'),
      ('DOUBLES', 'Doubles'),
      ('BOTH', 'Both'),
    ]),
    SportOption('PICKLEBALL', 'Pickleball', 'assets/images/pickleball.png', [
      ('SINGLES', 'Singles'),
      ('DOUBLES', 'Doubles'),
      ('BOTH', 'Both'),
    ]),
  ];

  static const battingHands = [('RIGHT', 'Right-handed'), ('LEFT', 'Left-handed')];
  static const bowlingStyles = [('PACE', 'Pace'), ('SPIN', 'Spin'), ('NONE', "Don't bowl")];
  static const genders = [('MALE', 'Male'), ('FEMALE', 'Female'), ('UNDISCLOSED', 'Prefer not to say')];
  static const jerseySizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'];
  static const jerseyChestInches = {'XS': 34, 'S': 36, 'M': 38, 'L': 40, 'XL': 42, 'XXL': 44, '3XL': 46};

  static SportOption? byCode(String code) {
    for (final s in all) {
      if (s.code == code) return s;
    }
    return null;
  }

  static String labelOf(List<(String, String)> options, String? code) {
    for (final (c, l) in options) {
      if (c == code) return l;
    }
    return code ?? '';
  }
}
