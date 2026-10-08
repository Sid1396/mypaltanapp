class HomeBanner {
  final int id;
  final String title;
  final String? subtitle;
  final String? badge;
  final String? imageUrl;
  final String theme;
  final String? ctaLabel;
  final String linkType;
  final String? linkValue;

  const HomeBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.badge,
    this.imageUrl,
    this.theme = 'ORANGE',
    this.ctaLabel,
    this.linkType = 'NONE',
    this.linkValue,
  });

  bool get isDark => theme == 'DARK';

  factory HomeBanner.fromJson(Map<String, dynamic> j) => HomeBanner(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        subtitle: j['subtitle']?.toString(),
        badge: j['badge']?.toString(),
        imageUrl: j['image_url']?.toString(),
        theme: j['theme']?.toString() ?? 'ORANGE',
        ctaLabel: j['cta_label']?.toString(),
        linkType: j['link_type']?.toString() ?? 'NONE',
        linkValue: j['link_value']?.toString(),
      );
}

/// A card in "Upcoming". Either a featured league (slug, info page only) or a real
/// public tournament (code, opens the full tournament page).
class FeaturedTournament {
  final String slug;
  final String? code;
  final String name;
  final String sport;
  final String? logoUrl;
  final DateTime? startDate;
  final String? area;
  final String city;
  final List<String> tags;
  final String status;

  const FeaturedTournament({
    required this.slug,
    this.code,
    required this.name,
    required this.sport,
    this.logoUrl,
    this.startDate,
    this.area,
    this.city = 'Mumbai',
    this.tags = const [],
    this.status = 'COMING_SOON',
  });

  static const _statusLabels = {
    'COMING_SOON': 'Registrations open soon',
    'REGISTRATION_OPEN': 'Registrations open',
    'REGISTRATION_CLOSED': 'Registrations closed',
    'FIXTURES_READY': 'Fixtures out',
    'LIVE': 'Live now',
    'COMPLETED': 'Completed',
  };
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String get statusLabel => _statusLabels[status] ?? status;
  String get location => [if (area != null && area!.isNotEmpty) area!, city].join(', ');
  String? get dayLabel => startDate?.day.toString().padLeft(2, '0');
  String? get monthLabel => startDate == null ? null : _months[startDate!.month - 1];
  String get dateLabel => startDate == null ? 'Coming soon' : '${startDate!.day} ${_months[startDate!.month - 1]} ${startDate!.year}';

  factory FeaturedTournament.fromJson(Map<String, dynamic> j) => FeaturedTournament(
        slug: j['slug']?.toString() ?? '',
        code: j['code']?.toString(),
        name: j['name']?.toString() ?? '',
        sport: j['sport']?.toString() ?? 'CRICKET',
        logoUrl: j['logo_url']?.toString(),
        startDate: DateTime.tryParse(j['start_date']?.toString() ?? ''),
        area: j['area']?.toString(),
        city: j['city']?.toString() ?? 'Mumbai',
        tags: ((j['tags'] as List?) ?? []).map((t) => t.toString()).toList(),
        status: j['status']?.toString() ?? 'COMING_SOON',
      );
}

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num?)?.toInt() ?? 0,
        type: j['type']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString(),
        isRead: j['is_read'] == true,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      );
}
