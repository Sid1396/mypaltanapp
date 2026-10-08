/// Option lists for tournaments. Codes match the server validator exactly.
class TournamentOptions {
  TournamentOptions._();

  static const categories = [
    ('OPEN', 'Open'),
    ('CORPORATE', 'Corporate'),
    ('COMMUNITY', 'Community'),
    ('SCHOOL', 'School'),
    ('COLLEGE', 'College'),
    ('UNIVERSITY', 'University'),
    ('OTHER', 'Other'),
  ];

  static const formats = [
    ('LEAGUE', 'League', 'Every team plays every other team. Top of the table wins.'),
    ('KNOCKOUT', 'Knockout', 'Lose once and you are out. Fast and simple.'),
    ('LEAGUE_KNOCKOUT', 'Groups + knockout', 'Group stage first, then the top teams play knockouts.'),
  ];

  static const matchDays = [('ALL', 'Any day'), ('WEEKEND', 'Weekends'), ('WEEKDAYS', 'Weekdays')];
  static const matchTimings = [('BOTH', 'Day & night'), ('DAY', 'Day'), ('NIGHT', 'Night')];

  static const prizeTypes = [('NONE', 'No prize'), ('TROPHY', 'Trophy'), ('CASH', 'Cash'), ('BOTH', 'Cash + trophy')];
  static const meals = [('BREAKFAST', 'Breakfast'), ('LUNCH', 'Lunch'), ('DINNER', 'Dinner'), ('SNACKS', 'Snacks')];
  static const jerseyPrints = [('NAME_NUMBER', 'Name + number'), ('NUMBER', 'Number only'), ('PLAIN', 'Plain')];

  static const cricketMatchTypes = [
    ('LIMITED_OVERS', 'Limited overs'),
    ('BOX', 'Box cricket'),
    ('PAIR', 'Pair cricket'),
    ('THE_HUNDRED', 'The Hundred'),
    ('TEST', 'Test / multi-day'),
  ];
  static const ballTypes = [('TENNIS', 'Tennis'), ('LEATHER', 'Leather'), ('OTHER', 'Other')];
  static const pitchTypes = [('TURF', 'Turf'), ('ASTROTURF', 'Astroturf'), ('MATTING', 'Matting'), ('CEMENT', 'Cement'), ('ROUGH', 'Rough')];
  static const racketEvents = [('SINGLES', 'Singles'), ('DOUBLES', 'Doubles'), ('MIXED', 'Mixed doubles')];
  static const pickleballScoring = [('SIDE_OUT', 'Side-out'), ('RALLY', 'Rally')];

  /// Tie-breakers allowed per sport (same as the server), in a sensible default order.
  static const tiebreakers = {
    'CRICKET': [('NRR', 'Net run rate'), ('HEAD_TO_HEAD', 'Head to head'), ('WINS', 'Most wins')],
    'FOOTBALL': [('GOAL_DIFF', 'Goal difference'), ('GOALS_FOR', 'Goals scored'), ('HEAD_TO_HEAD', 'Head to head'), ('SHOOTOUT', 'Penalty shootout')],
    'BADMINTON': [('GAMES_DIFF', 'Games difference'), ('POINT_DIFF', 'Point difference'), ('HEAD_TO_HEAD', 'Head to head')],
    'PICKLEBALL': [('GAMES_DIFF', 'Games difference'), ('POINT_DIFF', 'Point difference'), ('HEAD_TO_HEAD', 'Head to head')],
  };
  static const tiebreakerDefaults = {
    'CRICKET': ['NRR', 'HEAD_TO_HEAD'],
    'FOOTBALL': ['GOAL_DIFF', 'GOALS_FOR', 'HEAD_TO_HEAD'],
    'BADMINTON': ['GAMES_DIFF', 'POINT_DIFF', 'HEAD_TO_HEAD'],
    'PICKLEBALL': ['GAMES_DIFF', 'POINT_DIFF', 'HEAD_TO_HEAD'],
  };

  /// Default points (win, tie/draw, no result, loss). Football uses 3 for a win.
  static const pointDefaults = {'CRICKET': (2, 1, 1, 0), 'FOOTBALL': (3, 1, 1, 0), 'BADMINTON': (2, 1, 1, 0), 'PICKLEBALL': (2, 1, 1, 0)};

  /// Quick names when adding divisions. "Under N" also sets the age limit (under N on the start date).
  static const divisionSuggestions = [
    'Under 7', 'Under 9', 'Under 11', 'Under 13', 'Under 15', 'Under 17', 'Under 19',
    'Open', 'Men', 'Women', 'Mixed', 'Veterans 40+', 'Corporate',
  ];

  /// Default squad (min, max) per sport, same as the server.
  static const squadDefaults = {'CRICKET': (6, 25), 'FOOTBALL': (5, 25), 'BADMINTON': (1, 2), 'PICKLEBALL': (1, 2)};

  static const docTypes = [('FLYER', 'Flyer'), ('RULES', 'Rules'), ('SCHEDULE', 'Schedule'), ('OTHER', 'Other')];

  static const idTypes = [
    ('AADHAAR_MASKED', 'Aadhaar (masked)'),
    ('PAN', 'PAN card'),
    ('DRIVING_LICENCE', 'Driving licence'),
    ('VOTER_ID', 'Voter ID'),
    ('PASSPORT', 'Passport'),
  ];

  static const statusLabels = {
    'DRAFT': 'Draft',
    'REGISTRATION_OPEN': 'Registration open',
    'REGISTRATION_CLOSED': 'Registration closed',
    'FIXTURES_READY': 'Fixtures ready',
    'LIVE': 'Live',
    'COMPLETED': 'Completed',
    'CANCELLED': 'Cancelled',
  };
}
