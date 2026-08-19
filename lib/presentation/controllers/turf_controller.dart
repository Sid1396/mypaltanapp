import 'package:get/get.dart';

class TurfListing {
  final String emoji;
  final String name;
  final String distance;
  final String area;
  final List<String> sports;
  final int pricePerHour;
  final double rating;
  final int ratingCount;
  const TurfListing({
    required this.emoji,
    required this.name,
    required this.distance,
    required this.area,
    required this.sports,
    required this.pricePerHour,
    required this.rating,
    required this.ratingCount,
  });

  String get priceFrom => '₹$pricePerHour/hr';

  // Mock available slots for booking (same set for every turf for now).
  static const availableSlots = [
    '6:00 AM', '7:00 AM', '8:00 AM',
    '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM',
  ];
}

class TurfController extends GetxController {
  final selectedFilter = 'All'.obs;

  // 'All' and 'Under 5 km' are quick filters; the rest match the real
  // backend sports list (MyPaltanWebsite database/schema.sql `sports` table).
  final filters = const [
    'All',
    'Under 5 km',
    'Turf Cricket',
    'Cricket Nets',
    'Badminton',
    'Pickleball',
    'Football',
  ];

  final turfs = const [
    TurfListing(
      emoji: '🏏',
      name: 'TSG Sports Arena - Ajmera Nucleus',
      distance: '1.7 km',
      area: 'Borivali West',
      sports: ['Turf Cricket', 'Football'],
      pricePerHour: 800,
      rating: 4.5,
      ratingCount: 132,
    ),
    TurfListing(
      emoji: '🏏',
      name: 'TSG x Inbox Woods Sports Arena',
      distance: '2.4 km',
      area: 'Kandivali West',
      sports: ['Turf Cricket', 'Cricket Nets'],
      pricePerHour: 700,
      rating: 4.3,
      ratingCount: 76,
    ),
    TurfListing(
      emoji: '🏸',
      name: 'Shuttle Point Badminton Academy',
      distance: '2.0 km',
      area: 'Kandivali East',
      sports: ['Badminton'],
      pricePerHour: 350,
      rating: 4.7,
      ratingCount: 54,
    ),
    TurfListing(
      emoji: '🥎',
      name: 'DSF Pickleball Court by SportLight India',
      distance: '3.5 km',
      area: 'Dahisar East',
      sports: ['Pickleball'],
      pricePerHour: 300,
      rating: 4.8,
      ratingCount: 21,
    ),
    TurfListing(
      emoji: '⚽',
      name: 'MetroTurf Football Ground',
      distance: '3.1 km',
      area: 'Malad West',
      sports: ['Football'],
      pricePerHour: 900,
      rating: 4.2,
      ratingCount: 98,
    ),
    TurfListing(
      emoji: '🎯',
      name: 'Elite Cricket Nets & Turf',
      distance: '4.0 km',
      area: 'Goregaon West',
      sports: ['Cricket Nets', 'Turf Cricket'],
      pricePerHour: 500,
      rating: 4.4,
      ratingCount: 40,
    ),
  ];

  List<TurfListing> get filteredTurfs {
    final f = selectedFilter.value;
    if (f == 'All' || f == 'Under 5 km') return turfs;
    return turfs.where((t) => t.sports.contains(f)).toList();
  }

  void selectFilter(String f) => selectedFilter.value = f;
}
