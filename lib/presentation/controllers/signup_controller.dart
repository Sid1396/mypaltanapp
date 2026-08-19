import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';

enum PincodeStatus { idle, loading, valid, invalid }

class SignupController extends GetxController with LoggerMixin {
  late final PageController pageController;
  late final TextEditingController nameController;
  late final TextEditingController pincodeController;

  final _currentStep = 0.obs;
  final name = ''.obs;
  final birthdate = Rx<DateTime?>(null);
  final pincode = ''.obs;
  final city = ''.obs;
  final state = ''.obs;
  final area = ''.obs;
  final gender = ''.obs;
  final selectedSports = <String>[].obs;
  final skillLevel = 'Intermediate'.obs;
  final profileImagePath = Rx<String?>(null);
  final pincodeStatus = PincodeStatus.idle.obs;

  int get currentStep => _currentStep.value;

  int get age {
    final d = birthdate.value;
    if (d == null) return 0;
    final now = DateTime.now();
    int a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a;
  }

  final _imagePicker = ImagePicker();
  Timer? _pincodeTimer;

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: birthdate.value ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF1E1E1E),
          ),
        ),
        child: child!,
      ),
    );
    if (result != null) birthdate.value = result;
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) profileImagePath.value = picked.path;
    } catch (e) {
      if (e.toString().contains('photo_access_denied') ||
          e.toString().contains('camera_access_denied')) {
        AppSnackbar.warning(
          'Permission Required',
          'Allow ${source == ImageSource.camera ? 'camera' : 'photo library'} access in Settings',
        );
        return;
      }
      logError('Image picker failed', e);
    }
  }

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
    nameController = TextEditingController();
    pincodeController = TextEditingController();

    nameController.addListener(() => name.value = nameController.text);
    pincodeController.addListener(() => _onPincodeChanged(pincodeController.text));

    ever(_currentStep, (step) {
      if (pageController.hasClients) {
        pageController.animateToPage(
          step,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void onClose() {
    pageController.dispose();
    nameController.dispose();
    pincodeController.dispose();
    _pincodeTimer?.cancel();
    super.onClose();
  }

  void nextStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentStep.value < 7) _currentStep.value++;
  }

  void prevStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentStep.value > 0) {
      _currentStep.value--;
    } else {
      Get.back();
    }
  }

  bool validateName() {
    if (name.value.trim().length < 2) {
      AppSnackbar.error('Invalid Name', 'Name must be at least 2 characters');
      return false;
    }
    return true;
  }

  void _onPincodeChanged(String value) {
    _pincodeTimer?.cancel();
    pincode.value = value;
    city.value = '';
    state.value = '';
    area.value = '';
    if (value.length < 6) {
      pincodeStatus.value = PincodeStatus.idle;
      return;
    }
    pincodeStatus.value = PincodeStatus.loading;
    _pincodeTimer = Timer(
      const Duration(milliseconds: 600),
      () => _fetchLocation(value),
    );
  }

  Future<void> _fetchLocation(String pin) async {
    const url = 'https://api.postalpincode.in/pincode/';
    logInfo('Pincode API → GET $url$pin');
    // api.postalpincode.in has an expired SSL cert — bypass verification
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (_, __, ___) => true;
    try {
      final request = await client.getUrl(Uri.parse('$url$pin'));
      final response = await request.close();
      final bodyString = await response.transform(utf8.decoder).join();
      logInfo('Pincode API ← status: ${response.statusCode}  body: $bodyString');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(bodyString);
        if (decoded is List && decoded.isNotEmpty) {
          final first = decoded[0] as Map;
          if (first['Status'] == 'Success') {
            final offices = first['PostOffice'] as List?;
            if (offices != null && offices.isNotEmpty) {
              final po = offices.first as Map;
              city.value = po['District']?.toString() ?? '';
              state.value = po['State']?.toString() ?? '';
              area.value = po['Name']?.toString() ?? '';
              logInfo('Pincode resolved → city: ${city.value}, state: ${state.value}, area: ${area.value}');
              pincodeStatus.value = PincodeStatus.valid;
              return;
            }
          }
        }
      }
      logWarning('Pincode API → status ${response.statusCode}, no valid data');
      pincodeStatus.value = PincodeStatus.invalid;
    } catch (e) {
      logError('Pincode API failed', e);
      pincodeStatus.value = PincodeStatus.invalid;
    } finally {
      client.close();
    }
  }

  void toggleSport(String sport) {
    if (selectedSports.contains(sport)) {
      selectedSports.remove(sport);
    } else {
      if (selectedSports.length >= 4) {
        AppSnackbar.warning('Limit Reached', 'You can select up to 4 sports');
        return;
      }
      selectedSports.add(sport);
    }
  }

  void removeSport(String sport) => selectedSports.remove(sport);

  final isSubmitting = false.obs;

  Future<void> submitSignup() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (profileImagePath.value == null) return;
    isSubmitting.value = true;
    try {
      final api = Get.find<ApiService>();
      final dob = birthdate.value!;
      final birthdateStr =
          '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';

      final signupRes = await api.signup(
        name: name.value.trim(),
        birthdate: birthdateStr,
        gender: gender.value,
        pincode: pincode.value,
        city: city.value,
        state: state.value,
        area: area.value,
        skillLevel: skillLevel.value,
        sports: List<String>.from(selectedSports),
      );

      if (signupRes['success'] != true) {
        final msg = (signupRes['errors'] as List?)?.join(', ') ??
            signupRes['message']?.toString() ??
            'Signup failed';
        AppSnackbar.error('Error', msg);
        return;
      }

      final photoRes = await api.uploadPhoto(profileImagePath.value!);
      if (photoRes['success'] != true) {
        AppSnackbar.warning(
          'Photo Upload Failed',
          'Your account was created but the photo could not be uploaded.',
        );
      }

      nextStep();
    } catch (e) {
      logError('Signup failed', e);
      AppSnackbar.error('Network Error', 'Check your connection and try again');
    } finally {
      isSubmitting.value = false;
    }
  }
}
