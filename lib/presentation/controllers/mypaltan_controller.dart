import 'package:get/get.dart';

class CommunityEvent {
  final String emoji;
  final String title;
  final String sport;
  final String dateTime;
  final String location;
  final String organizer;
  final int joined;
  final int maxSpots;
  final String feeLabel;
  const CommunityEvent({
    required this.emoji,
    required this.title,
    required this.sport,
    required this.dateTime,
    required this.location,
    required this.organizer,
    required this.joined,
    required this.maxSpots,
    required this.feeLabel,
  });
}

class MyPaltanController extends GetxController {
  final searchQuery = ''.obs;

  final events = <CommunityEvent>[
    CommunityEvent(
      emoji: '🏏',
      title: 'Sunday Morning Box Cricket',
      sport: 'Turf Cricket',
      dateTime: 'Sun, 24 Aug, 7:00 AM',
      location: 'TSG Sports Arena, Borivali West',
      organizer: 'Rohan Mehta',
      joined: 8,
      maxSpots: 12,
      feeLabel: '₹200/person',
    ),
    CommunityEvent(
      emoji: '🏸',
      title: 'Casual Badminton Doubles',
      sport: 'Badminton',
      dateTime: 'Sat, 23 Aug, 6:30 PM',
      location: 'Shuttle Point Academy, Kandivali East',
      organizer: 'Priya Nair',
      joined: 3,
      maxSpots: 4,
      feeLabel: '₹150/person',
    ),
    CommunityEvent(
      emoji: '🥎',
      title: 'Pickleball Meetup for Beginners',
      sport: 'Pickleball',
      dateTime: 'Fri, 29 Aug, 5:00 PM',
      location: 'DSF Pickleball Court, Dahisar East',
      organizer: 'Aditya Shah',
      joined: 6,
      maxSpots: 8,
      feeLabel: 'Free',
    ),
    CommunityEvent(
      emoji: '⚽',
      title: 'Weeknight 5-a-side Football',
      sport: 'Football',
      dateTime: 'Wed, 27 Aug, 8:00 PM',
      location: 'MetroTurf Football Ground, Malad West',
      organizer: 'Karan Verma',
      joined: 9,
      maxSpots: 10,
      feeLabel: '₹250/person',
    ),
  ].obs;

  void addEvent(CommunityEvent event) => events.insert(0, event);

  List<CommunityEvent> get filteredEvents {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return events;
    return events
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.sport.toLowerCase().contains(q) ||
            e.location.toLowerCase().contains(q))
        .toList();
  }

  void onSearchChanged(String value) => searchQuery.value = value;
}
