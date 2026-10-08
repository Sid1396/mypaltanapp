import '../../config/tournament_options.dart';

int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
bool _bool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
String? _str(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v'.replaceFirst(' ', 'T'));

class TournamentDocument {
  final int id;
  final String docType;
  final String title;
  final String mimeType;
  final int sizeBytes;
  final String? url;
  final String? fileKey;

  const TournamentDocument({
    required this.id,
    required this.docType,
    required this.title,
    required this.mimeType,
    required this.sizeBytes,
    this.url,
    this.fileKey,
  });

  bool get isPdf => mimeType == 'application/pdf';

  factory TournamentDocument.fromJson(Map<String, dynamic> j) => TournamentDocument(
        id: _int(j['id']),
        docType: j['doc_type']?.toString() ?? 'OTHER',
        title: j['title']?.toString() ?? '',
        mimeType: j['mime_type']?.toString() ?? '',
        sizeBytes: _int(j['size_bytes']),
        url: _str(j['url']),
        fileKey: _str(j['file_key']),
      );
}

class TournamentSponsor {
  final int id;
  final String name;
  final String label;
  final bool isTitle;
  final String? logoUrl;
  final String? bannerUrl;
  final String? linkUrl;
  final String? tagline;
  final String? logoKey;
  final String? bannerKey;
  final int views;
  final int taps;

  const TournamentSponsor({
    required this.id,
    required this.name,
    required this.label,
    required this.isTitle,
    this.logoUrl,
    this.bannerUrl,
    this.linkUrl,
    this.tagline,
    this.logoKey,
    this.bannerKey,
    this.views = 0,
    this.taps = 0,
  });

  factory TournamentSponsor.fromJson(Map<String, dynamic> j) => TournamentSponsor(
        id: _int(j['id']),
        name: j['name']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        isTitle: _bool(j['is_title']),
        logoUrl: _str(j['logo_url']),
        bannerUrl: _str(j['banner_url']),
        linkUrl: _str(j['link_url']),
        tagline: _str(j['tagline']),
        logoKey: _str(j['logo_key']),
        bannerKey: _str(j['banner_key']),
        views: _int(j['views']),
        taps: _int(j['taps']),
      );
}

class TournamentPayment {
  final String upiId;
  final String upiName;
  final String? qrKey;
  final String? qrUrl;
  final bool acceptCash;
  final String? note;

  const TournamentPayment({required this.upiId, required this.upiName, this.qrKey, this.qrUrl, this.acceptCash = false, this.note});

  factory TournamentPayment.fromJson(Map<String, dynamic> j) => TournamentPayment(
        upiId: j['upi_id']?.toString() ?? '',
        upiName: j['upi_name']?.toString() ?? '',
        qrKey: _str(j['qr_key']),
        qrUrl: _str(j['qr_url']),
        acceptCash: _bool(j['accept_cash']),
        note: _str(j['note']),
      );
}

/// An age group or category inside a tournament, with its own teams, format, rules, fee and prize.
class TournamentDivision {
  final int? id;
  final String name;
  final int? minAge;
  final int? maxAge;
  final String format;
  final int? groupCount;
  final int? qualifyPerGroup;
  final int maxTeams;
  final int squadMin;
  final int squadMax;
  final int entryFee;
  final String prizeType;
  final String? prizeDetails;
  final Map<String, dynamic> matchRules;
  final Map<String, dynamic> points;
  final int approvedTeams;

  const TournamentDivision({
    this.id,
    required this.name,
    this.minAge,
    this.maxAge,
    required this.format,
    this.groupCount,
    this.qualifyPerGroup,
    required this.maxTeams,
    required this.squadMin,
    required this.squadMax,
    required this.entryFee,
    required this.prizeType,
    this.prizeDetails,
    required this.matchRules,
    required this.points,
    this.approvedTeams = 0,
  });

  /// "Under 13", "40 and over", "Ages 10 to 14" or null when anyone can play.
  String? get ageLabel {
    if (minAge == null && maxAge == null) return null;
    if (minAge == null) return 'Under ${maxAge! + 1}';
    if (maxAge == null) return '$minAge and over';
    return 'Ages $minAge to $maxAge';
  }

  factory TournamentDivision.fromJson(Map<String, dynamic> j) => TournamentDivision(
        id: j['id'] == null ? null : _int(j['id']),
        name: j['name']?.toString() ?? 'Open',
        minAge: j['min_age'] == null ? null : _int(j['min_age']),
        maxAge: j['max_age'] == null ? null : _int(j['max_age']),
        format: j['format']?.toString() ?? 'KNOCKOUT',
        groupCount: j['group_count'] == null ? null : _int(j['group_count']),
        qualifyPerGroup: j['qualify_per_group'] == null ? null : _int(j['qualify_per_group']),
        maxTeams: _int(j['max_teams'], 8),
        squadMin: _int(j['squad_min'], 1),
        squadMax: _int(j['squad_max'], 1),
        entryFee: _int(j['entry_fee']),
        prizeType: j['prize_type']?.toString() ?? 'NONE',
        prizeDetails: _str(j['prize_details']),
        matchRules: Map<String, dynamic>.from(j['match_rules'] as Map? ?? {}),
        points: Map<String, dynamic>.from(j['points'] as Map? ?? {}),
        approvedTeams: _int(j['approved_teams']),
      );
}

/// Full tournament as returned by `tournaments/detail`. Owner-only fields are null for everyone else.
class Tournament {
  final String code;
  final String sport;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String category;
  final String city;
  final String area;
  final DateTime? startDate;
  final DateTime? endDate;
  final String matchDays;
  final String matchTiming;
  final String format;
  final int? groupCount;
  final int? qualifyPerGroup;
  final int maxTeams;
  final int squadMin;
  final int squadMax;
  final int entryFee;
  final int jerseyFee;
  final String prizeType;
  final String? prizeDetails;
  final bool foodProvided;
  final List<String> meals;
  final bool jerseyProvided;
  final String? jerseyPrint;
  final DateTime? registrationDeadline;
  final DateTime? checklistDeadline;
  final String visibility;
  final String status;
  final int approvedTeams;
  final Map<String, dynamic> matchRules;
  final Map<String, dynamic> points;
  final List<String> grounds;
  final List<TournamentDocument> documents;
  final List<TournamentSponsor> sponsors;
  final List<TournamentDivision> divisions;
  final String? organizerName;
  final String? organizerPhotoUrl;
  final bool organizerVerified;
  final int organizerCompleted;
  final bool isOwner;
  final String? logoKey;
  final String? bannerKey;
  final TournamentPayment? payment;

  const Tournament({
    required this.code,
    required this.sport,
    required this.name,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    required this.category,
    required this.city,
    required this.area,
    this.startDate,
    this.endDate,
    required this.matchDays,
    required this.matchTiming,
    required this.format,
    this.groupCount,
    this.qualifyPerGroup,
    required this.maxTeams,
    required this.squadMin,
    required this.squadMax,
    required this.entryFee,
    required this.jerseyFee,
    required this.prizeType,
    this.prizeDetails,
    required this.foodProvided,
    required this.meals,
    required this.jerseyProvided,
    this.jerseyPrint,
    this.registrationDeadline,
    this.checklistDeadline,
    required this.visibility,
    required this.status,
    required this.approvedTeams,
    required this.matchRules,
    required this.points,
    required this.grounds,
    required this.documents,
    required this.sponsors,
    required this.divisions,
    this.organizerName,
    this.organizerPhotoUrl,
    required this.organizerVerified,
    required this.organizerCompleted,
    required this.isOwner,
    this.logoKey,
    this.bannerKey,
    this.payment,
  });

  bool get isDraft => status == 'DRAFT';
  String get statusLabel => TournamentOptions.statusLabels[status] ?? status;
  String get location => [area, city].where((s) => s.isNotEmpty).join(', ');
  TournamentSponsor? get titleSponsor => sponsors.where((s) => s.isTitle).firstOrNull;
  bool get hasDivisions => divisions.length > 1;
  int get minEntryFee => divisions.isEmpty ? entryFee : divisions.map((d) => d.entryFee).reduce((a, b) => a < b ? a : b);
  int get maxEntryFee => divisions.isEmpty ? entryFee : divisions.map((d) => d.entryFee).reduce((a, b) => a > b ? a : b);

  factory Tournament.fromJson(Map<String, dynamic> j) {
    final org = Map<String, dynamic>.from(j['organizer'] as Map? ?? {});
    List<Map<String, dynamic>> list(String k) =>
        (j[k] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    return Tournament(
      code: j['code']?.toString() ?? '',
      sport: j['sport']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      description: _str(j['description']),
      logoUrl: _str(j['logo_url']),
      bannerUrl: _str(j['banner_url']),
      category: j['category']?.toString() ?? 'OPEN',
      city: j['city']?.toString() ?? 'Mumbai',
      area: j['area']?.toString() ?? '',
      startDate: _date(j['start_date']),
      endDate: _date(j['end_date']),
      matchDays: j['match_days']?.toString() ?? 'ALL',
      matchTiming: j['match_timing']?.toString() ?? 'BOTH',
      format: j['format']?.toString() ?? 'KNOCKOUT',
      groupCount: j['group_count'] == null ? null : _int(j['group_count']),
      qualifyPerGroup: j['qualify_per_group'] == null ? null : _int(j['qualify_per_group']),
      maxTeams: _int(j['max_teams'], 8),
      squadMin: _int(j['squad_min'], 1),
      squadMax: _int(j['squad_max'], 1),
      entryFee: _int(j['entry_fee']),
      jerseyFee: _int(j['jersey_fee']),
      prizeType: j['prize_type']?.toString() ?? 'NONE',
      prizeDetails: _str(j['prize_details']),
      foodProvided: _bool(j['food_provided']),
      meals: (j['meals'] as List? ?? []).map((m) => '$m').where((m) => m.isNotEmpty).toList(),
      jerseyProvided: _bool(j['jersey_provided']),
      jerseyPrint: _str(j['jersey_print']),
      registrationDeadline: _date(j['registration_deadline']),
      checklistDeadline: _date(j['checklist_deadline']),
      visibility: j['visibility']?.toString() ?? 'PRIVATE',
      status: j['status']?.toString() ?? 'DRAFT',
      approvedTeams: _int(j['approved_teams']),
      matchRules: Map<String, dynamic>.from(j['match_rules'] as Map? ?? {}),
      points: Map<String, dynamic>.from(j['points'] as Map? ?? {}),
      grounds: (j['grounds'] as List? ?? []).map((g) => '$g').toList(),
      documents: list('documents').map(TournamentDocument.fromJson).toList(),
      sponsors: list('sponsors').map(TournamentSponsor.fromJson).toList(),
      divisions: list('divisions').map(TournamentDivision.fromJson).toList(),
      organizerName: _str(org['name']),
      organizerPhotoUrl: _str(org['photo_url']),
      organizerVerified: _bool(org['verified']),
      organizerCompleted: _int(org['completed_tournaments']),
      isOwner: _bool(j['is_owner']),
      logoKey: _str(j['logo_key']),
      bannerKey: _str(j['banner_key']),
      payment: j['payment'] is Map ? TournamentPayment.fromJson(Map<String, dynamic>.from(j['payment'] as Map)) : null,
    );
  }
}

/// Row in "My tournaments".
class MyTournament {
  final String code;
  final String name;
  final String sport;
  final String status;
  final String visibility;
  final DateTime? startDate;
  final String? area;
  final String? logoUrl;
  final int maxTeams;
  final int entryFee;
  final int approvedTeams;
  final int pendingTeams;
  final String role;

  const MyTournament({
    required this.code,
    required this.name,
    required this.sport,
    required this.status,
    required this.visibility,
    this.startDate,
    this.area,
    this.logoUrl,
    required this.maxTeams,
    required this.entryFee,
    required this.approvedTeams,
    required this.pendingTeams,
    required this.role,
  });

  String get statusLabel => TournamentOptions.statusLabels[status] ?? status;

  factory MyTournament.fromJson(Map<String, dynamic> j) => MyTournament(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        sport: j['sport']?.toString() ?? '',
        status: j['status']?.toString() ?? 'DRAFT',
        visibility: j['visibility']?.toString() ?? 'PRIVATE',
        startDate: _date(j['start_date']),
        area: _str(j['area']),
        logoUrl: _str(j['logo_url']),
        maxTeams: _int(j['max_teams']),
        entryFee: _int(j['entry_fee']),
        approvedTeams: _int(j['approved_teams']),
        pendingTeams: _int(j['pending_teams']),
        role: j['role']?.toString() ?? 'ORGANIZER',
      );
}

/// Identity verification state from `verification/status`.
class VerificationStatus {
  final bool isVerified;
  final String status; // NOT_SUBMITTED, PENDING, REJECTED, VERIFIED
  final String? rejectReason;
  final String? submittedAt;

  const VerificationStatus({required this.isVerified, required this.status, this.rejectReason, this.submittedAt});

  factory VerificationStatus.fromJson(Map<String, dynamic> j) => VerificationStatus(
        isVerified: _bool(j['is_verified']),
        status: j['status']?.toString() ?? 'NOT_SUBMITTED',
        rejectReason: _str(j['reject_reason']),
        submittedAt: _str(j['submitted_at']),
      );
}
