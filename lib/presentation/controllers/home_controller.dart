import 'package:get/get.dart';
import '../../data/services/api_service.dart';
import '../../utils/mixins/logger_mixin.dart';

class SportItem {
  final String name;
  final String iconAsset;
  const SportItem(this.name, this.iconAsset);
}

class VenueSlot {
  final String time;
  final String type;
  const VenueSlot(this.time, this.type);
}

class PlayVenue {
  final String emoji;
  final String name;
  final String distance;
  final String area;
  final List<VenueSlot> slots;
  const PlayVenue({
    required this.emoji,
    required this.name,
    required this.distance,
    required this.area,
    required this.slots,
  });
}

class PromoVenue {
  final String emoji;
  final String discountLabel;
  final String name;
  final String distance;
  final String area;
  final double? rating;
  final int? ratingCount;
  final String priceFrom;
  const PromoVenue({
    required this.emoji,
    required this.discountLabel,
    required this.name,
    required this.distance,
    required this.area,
    this.rating,
    this.ratingCount,
    required this.priceFrom,
  });
}

class SportEvent {
  final String emoji;
  final String location;
  final String title;
  final String dateTime;
  const SportEvent({
    required this.emoji,
    required this.location,
    required this.title,
    required this.dateTime,
  });
}

class Vendor {
  final String emoji;
  final String name;
  final String category;
  final String distance;
  final String area;
  final double? rating;
  const Vendor({
    required this.emoji,
    required this.name,
    required this.category,
    required this.distance,
    required this.area,
    this.rating,
  });
}

class AllVenue {
  final String emoji;
  final String name;
  final String distance;
  final String area;
  final String sport;
  final String priceFrom;
  const AllVenue({
    required this.emoji,
    required this.name,
    required this.distance,
    required this.area,
    required this.sport,
    required this.priceFrom,
  });
}

class HomeController extends GetxController with LoggerMixin {
  final userName = 'Player'.obs;
  final selectedCategory = 'Play'.obs;
  final selectedFilter = 'Under 5 km'.obs;

  final categories = const ['Events', 'Stores', 'Activities', 'Play', 'Comedy'];

  // Matches the sports actually offered by the backend (MyPaltanWebsite
  // database/schema.sql `sports` lookup table used for turf categorization).
  final sports = const [
    SportItem('Turf Cricket', 'assets/images/turfcricket.png'),
    SportItem('Cricket Nets', 'assets/images/netricket.png'),
    SportItem('Badminton', 'assets/images/badminton.png'),
    SportItem('Pickleball', 'assets/images/pickleball.png'),
    SportItem('Football', 'assets/images/football.png'),
  ];

  final playVenues = const [
    PlayVenue(
      emoji: '🏏',
      name: 'TSG Sports Arena - Ajmera Nucleus',
      distance: '1.7 km',
      area: 'Borivali West',
      slots: [
        VenueSlot('4:30 PM', 'Outdoor'),
        VenueSlot('5 PM', 'Outdoor'),
        VenueSlot('5:30 PM', 'Outdoor'),
      ],
    ),
    PlayVenue(
      emoji: '🏏',
      name: 'TSG x Inbox Woods Sports Arena',
      distance: '2.4 km',
      area: 'Kandivali West',
      slots: [
        VenueSlot('6 PM', 'Indoor'),
        VenueSlot('6:30 PM', 'Indoor'),
        VenueSlot('7 PM', 'Indoor'),
      ],
    ),
  ];

  final promoVenues = const [
    PromoVenue(
      emoji: '🏸',
      discountLabel: '20% OFF up to ₹250',
      name: 'Tsg Sports Arena @ GopalJi Hemraj',
      distance: '2.3 km',
      area: 'Borivali East, Mumbai',
      rating: null,
      ratingCount: null,
      priceFrom: '₹350 onwards',
    ),
    PromoVenue(
      emoji: '🎾',
      discountLabel: '20% OFF',
      name: 'Mihir Sen Sports Complex',
      distance: '5.0 km',
      area: 'Malad, Mumbai',
      rating: 4.5,
      ratingCount: 88,
      priceFrom: '₹400 onwards',
    ),
  ];

  final pickleballVenues = const [
    PromoVenue(
      emoji: '🥎',
      discountLabel: '20% OFF up to ₹250',
      name: 'DSF Pickleball Court by SportLight India',
      distance: '3.5 km',
      area: 'Dahisar East, Mumbai',
      rating: 4.8,
      ratingCount: 21,
      priceFrom: '₹300 onwards',
    ),
    PromoVenue(
      emoji: '🥎',
      discountLabel: '20% OFF',
      name: 'Samajonnati Academy',
      distance: '2.3 km',
      area: 'Borivali West, Mumbai',
      rating: null,
      ratingCount: null,
      priceFrom: '₹800 onwards',
    ),
  ];

  final events = const [
    SportEvent(
      emoji: '🥎',
      location: 'MAKS Sports Complex',
      title: 'TSM Pickleball Open 2026',
      dateTime: 'Sun, 06 Sep, 8:00 AM',
    ),
    SportEvent(
      emoji: '🥎',
      location: 'Andheri Sports Complex',
      title: 'School Parents Pickleball Championship 3.0',
      dateTime: 'Sat, 15 Aug, 10:00 AM',
    ),
  ];

  final upcomingTournaments = const [
    SportEvent(
      emoji: '🏆',
      location: 'TSG Sports Arena - Ajmera Nucleus',
      title: 'MyPaltan Box Cricket Premier League',
      dateTime: 'Sat, 22 Aug, 9:00 AM',
    ),
    SportEvent(
      emoji: '🏆',
      location: 'Shuttle Point Badminton Academy',
      title: 'Borivali Open Badminton Championship',
      dateTime: 'Sun, 30 Aug, 7:30 AM',
    ),
  ];

  final vendors = const [
    Vendor(
      emoji: '🏬',
      name: 'Decathlon Sports Store',
      category: 'Sports Shop',
      distance: '1.5 km',
      area: 'Kandivali West',
      rating: 4.4,
    ),
    Vendor(
      emoji: '👟',
      name: 'ProKit Cricket Gear',
      category: 'Sports Shop',
      distance: '2.8 km',
      area: 'Borivali West',
      rating: 4.6,
    ),
    Vendor(
      emoji: '🥤',
      name: 'FuelUp Sports Nutrition',
      category: 'Nutrition Store',
      distance: '3.2 km',
      area: 'Malad West',
      rating: 4.2,
    ),
  ];

  final filters = const ['Under 5 km', 'Badminton', 'Turf Cricket', 'Pickleball'];

  final allVenues = const [
    AllVenue(
      emoji: '⚽',
      name: 'MetroTurf Football Ground',
      distance: '1.2 km',
      area: 'Borivali West',
      sport: 'Football',
      priceFrom: '₹200 onwards',
    ),
    AllVenue(
      emoji: '🏸',
      name: 'Shuttle Point Badminton Academy',
      distance: '2.0 km',
      area: 'Kandivali East',
      sport: 'Badminton',
      priceFrom: '₹350 onwards',
    ),
    AllVenue(
      emoji: '🏏',
      name: 'MetroTurf Cricket Ground',
      distance: '3.1 km',
      area: 'Malad West',
      sport: 'Turf Cricket',
      priceFrom: '₹500 onwards',
    ),
  ];

  void selectCategory(String c) => selectedCategory.value = c;
  void selectFilter(String f) => selectedFilter.value = f;

  @override
  void onInit() {
    super.onInit();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    try {
      final res = await Get.find<ApiService>().getProfile();
      if (res['success'] == true && res['user'] != null) {
        final name = (res['user']['name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty) userName.value = name.split(' ').first;
      }
    } catch (e) {
      logError('Fetch user name failed', e);
    }
  }
}
