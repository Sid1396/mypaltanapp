import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/snackbar_helper.dart';
import 'mypaltan_controller.dart';
import 'turf_controller.dart';

class CreateEventController extends GetxController {
  static const sports = ['Turf Cricket', 'Cricket Nets', 'Badminton', 'Pickleball', 'Football'];
  static const sportEmojis = {
    'Turf Cricket': '🏏',
    'Cricket Nets': '🎯',
    'Badminton': '🏸',
    'Pickleball': '🥎',
    'Football': '⚽',
  };
  static const paymentMethods = ['UPI', 'Card', 'Net Banking'];

  late final PageController pageController;
  final currentStep = 0.obs;

  // ── Step 1: basic info ──────────────────────────────────
  final titleController = TextEditingController();
  final maxSpotsController = TextEditingController(text: '10');
  final feeController = TextEditingController();
  final selectedSport = Rx<String?>(null);
  final selectedDate = Rx<DateTime?>(null);
  final selectedTime = Rx<TimeOfDay?>(null);
  final isFree = false.obs;

  // ── Step 2: turf & slot ──────────────────────────────────
  final selectedTurf = Rx<TurfListing?>(null);
  final selectedSlot = Rx<String?>(null);

  // ── Step 3: payment ──────────────────────────────────────
  final selectedPaymentMethod = 'UPI'.obs;
  final isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
  }

  @override
  void onClose() {
    pageController.dispose();
    titleController.dispose();
    maxSpotsController.dispose();
    feeController.dispose();
    super.onClose();
  }

  List<TurfListing> get turfsForSport {
    final sport = selectedSport.value;
    final all = Get.find<TurfController>().turfs;
    if (sport == null) return all;
    return all.where((t) => t.sports.contains(sport)).toList();
  }

  int get bookingTotal => selectedTurf.value?.pricePerHour ?? 0;

  void selectSport(String s) {
    selectedSport.value = s;
    selectedTurf.value = null;
    selectedSlot.value = null;
  }

  void toggleFree(bool free) => isFree.value = free;

  void selectTurf(TurfListing t) {
    selectedTurf.value = t;
    selectedSlot.value = null;
  }

  void selectSlot(String s) => selectedSlot.value = s;
  void selectPaymentMethod(String m) => selectedPaymentMethod.value = m;

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate.value ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1E1E)),
        ),
        child: child!,
      ),
    );
    if (result != null) selectedDate.value = result;
  }

  Future<void> pickTime(BuildContext context) async {
    final result = await showTimePicker(
      context: context,
      initialTime: selectedTime.value ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1E1E)),
        ),
        child: child!,
      ),
    );
    if (result != null) selectedTime.value = result;
  }

  String get formattedDateTime {
    final d = selectedDate.value;
    final t = selectedTime.value;
    if (d == null || t == null) return '';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${weekdays[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}, $hour12:$minute $period';
  }

  bool _validateStep1() {
    if (titleController.text.trim().isEmpty) {
      AppSnackbar.error('Missing Title', 'Give your event a name');
      return false;
    }
    if (selectedSport.value == null) {
      AppSnackbar.error('Missing Sport', 'Select a sport for this event');
      return false;
    }
    if (selectedDate.value == null || selectedTime.value == null) {
      AppSnackbar.error('Missing Date/Time', 'Pick a date and time');
      return false;
    }
    final spots = int.tryParse(maxSpotsController.text.trim());
    if (spots == null || spots < 1) {
      AppSnackbar.error('Invalid Spots', 'Enter a valid number of participants');
      return false;
    }
    if (!isFree.value && feeController.text.trim().isEmpty) {
      AppSnackbar.error('Missing Fee', 'Enter a fee amount, or mark this event as Free');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (selectedTurf.value == null) {
      AppSnackbar.error('Select a Turf', 'Choose a venue for your event');
      return false;
    }
    if (selectedSlot.value == null) {
      AppSnackbar.error('Select a Slot', 'Choose an available time slot');
      return false;
    }
    return true;
  }

  void nextStep() {
    if (currentStep.value == 0 && !_validateStep1()) return;
    if (currentStep.value == 1 && !_validateStep2()) return;
    if (currentStep.value < 2) {
      currentStep.value++;
      pageController.animateToPage(
        currentStep.value,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void prevStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
      pageController.animateToPage(
        currentStep.value,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Get.back();
    }
  }

  void confirmAndPay() {
    isSubmitting.value = true;

    final turf = selectedTurf.value!;
    final event = CommunityEvent(
      emoji: sportEmojis[selectedSport.value]!,
      title: titleController.text.trim(),
      sport: selectedSport.value!,
      dateTime: formattedDateTime,
      location: '${turf.name}, ${turf.area}',
      organizer: 'You',
      joined: 1,
      maxSpots: int.parse(maxSpotsController.text.trim()),
      feeLabel: isFree.value ? 'Free' : '₹${feeController.text.trim()}/person',
    );

    Get.find<MyPaltanController>().addEvent(event);
    isSubmitting.value = false;
    AppSnackbar.success('Event Created', '${event.title} is now live');
    Get.back();
  }
}
