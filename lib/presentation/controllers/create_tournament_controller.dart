import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/tournament_options.dart';
import '../../data/models/tournament.dart';
import '../../data/services/api_service.dart';
import '../../utils/helpers/image_prep.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/mixins/logger_mixin.dart';

/// A file already stored on the server. [localPath] is kept for an instant preview after upload.
class UploadedFile {
  final String key;
  final String? url;
  final String? localPath;
  final String mimeType;
  final int sizeBytes;

  const UploadedFile({required this.key, this.url, this.localPath, this.mimeType = 'image/jpeg', this.sizeBytes = 0});
}

/// One upload box in the form (logo, banner, QR...).
class UploadSlot {
  final file = Rx<UploadedFile?>(null);
  final busy = false.obs;
  bool get isSet => file.value != null;
}

class DocumentDraft {
  final String docType;
  final String title;
  final UploadedFile file;
  const DocumentDraft({required this.docType, required this.title, required this.file});
}

class SponsorDraft {
  final int? id;
  final String name;
  final String label;
  final bool isTitle;
  final UploadedFile logo;
  final UploadedFile? banner;
  final String? linkUrl;
  final String? tagline;

  const SponsorDraft({
    this.id,
    required this.name,
    required this.label,
    required this.isTitle,
    required this.logo,
    this.banner,
    this.linkUrl,
    this.tagline,
  });

  SponsorDraft copyWith({bool? isTitle}) => SponsorDraft(
        id: id,
        name: name,
        label: label,
        isTitle: isTitle ?? this.isTitle,
        logo: logo,
        banner: banner,
        linkUrl: linkUrl,
        tagline: tagline,
      );
}

/// Create / edit tournament wizard. Steps after a choice depend on it (points only for leagues,
/// UPI only when there is an entry fee), so conditional steps always come after the step that controls them.
class CreateTournamentController extends GetxController with LoggerMixin {
  static const stepTitles = {
    'sport': 'Sport',
    'basics': 'Basics',
    'venue': 'Where & when',
    'format': 'Format',
    'rules': 'Match rules',
    'points': 'Points',
    'fees': 'Entry fee & prize',
    'payment': 'Payment',
    'extras': 'Food & jerseys',
    'registration': 'Registration',
    'media': 'Documents & sponsors',
    'review': 'Review',
  };

  ApiService get _api => Get.find<ApiService>();
  final _picker = ImagePicker();

  /// Code of the tournament being edited, or null when creating.
  String? editCode;
  bool get isEditing => editCode != null;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final _index = 0.obs;
  final reviewReached = false.obs;
  final _tick = 0.obs; // bumps on every text change so Obx rebuilds validation

  // Sport & basics
  final sport = ''.obs;
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final logo = UploadSlot();
  final banner = UploadSlot();
  final category = ''.obs;

  // Where & when
  final areaCtrl = TextEditingController();
  final cityCtrl = TextEditingController(text: 'Mumbai');
  final groundCtrl = TextEditingController();
  final grounds = <String>[].obs;
  final startDate = Rx<DateTime?>(null);
  final endDate = Rx<DateTime?>(null);
  final matchDays = 'ALL'.obs;
  final matchTiming = 'BOTH'.obs;

  // Format
  final format = ''.obs;
  final maxTeams = 8.obs;
  final groupCount = 2.obs;
  final qualifyPerGroup = 2.obs;
  final squadMin = 6.obs;
  final squadMax = 25.obs;

  // Cricket rules
  final matchType = 'LIMITED_OVERS'.obs;
  final ballType = 'TENNIS'.obs;
  final pitchType = ''.obs;
  final playersPerSide = 11.obs;
  final overs = 10.obs;
  final oversPerBowler = 2.obs;
  final powerplayOvers = 0.obs;
  final lastBatter = false.obs;
  // Football rules
  final footballPlayers = 7.obs;
  final halfMinutes = 20.obs;
  final rollingSubs = true.obs;
  final extraTime = false.obs;
  final penalties = true.obs;
  // Badminton / pickleball rules
  final racketEvent = 'DOUBLES'.obs;
  final pointsPerGame = 21.obs;
  final games = 3.obs;
  final winByTwo = true.obs;
  final scoring = 'SIDE_OUT'.obs;

  // Points table
  final ptsWin = 2.obs;
  final ptsTie = 1.obs;
  final ptsNoResult = 1.obs;
  final ptsLoss = 0.obs;
  final tiebreaker = ''.obs;

  // Fees & prize
  final entryFeeCtrl = TextEditingController();
  final prizeType = 'NONE'.obs;
  final prizeCtrl = TextEditingController();

  // Payment
  final upiCtrl = TextEditingController();
  final upiNameCtrl = TextEditingController();
  final qr = UploadSlot();
  final acceptCash = false.obs;
  final payNoteCtrl = TextEditingController();

  // Extras
  final foodProvided = false.obs;
  final meals = <String>{}.obs;
  final jerseyProvided = false.obs;
  final jerseyPrint = 'NAME_NUMBER'.obs;
  final jerseyFeeCtrl = TextEditingController();

  // Registration
  final registrationDeadline = Rx<DateTime?>(null);
  final checklistDeadline = Rx<DateTime?>(null);

  // Documents & sponsors
  final documents = <DocumentDraft>[].obs;
  final sponsors = <SponsorDraft>[].obs;
  final docBusy = false.obs;

  List<TextEditingController> get _controllers =>
      [nameCtrl, descCtrl, areaCtrl, cityCtrl, groundCtrl, entryFeeCtrl, prizeCtrl, upiCtrl, upiNameCtrl, payNoteCtrl, jerseyFeeCtrl];

  @override
  void onInit() {
    super.onInit();
    for (final c in _controllers) {
      c.addListener(() => _tick.value++);
    }
    final args = Get.arguments;
    editCode = args is Map ? args['code'] as String? : null;
    if (isEditing) _loadForEdit();
  }

  @override
  void onClose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.onClose();
  }

  // ─── Steps ────────────────────────────────────────────────────

  int get entryFee => int.tryParse(entryFeeCtrl.text.trim()) ?? 0;
  int get jerseyFee => int.tryParse(jerseyFeeCtrl.text.trim()) ?? 0;
  bool get hasExtras => foodProvided.value || jerseyProvided.value;

  List<String> get steps {
    _tick.value; // entry fee lives in a text field
    return [
      'sport',
      'basics',
      'venue',
      'format',
      'rules',
      if (format.value != 'KNOCKOUT') 'points',
      'fees',
      if (entryFee > 0) 'payment',
      'extras',
      'registration',
      'media',
      'review',
    ];
  }

  int get index => _index.value.clamp(0, steps.length - 1);
  String get currentStep => steps[index];

  void goTo(String step) {
    final i = steps.indexOf(step);
    if (i < 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _index.value = i;
    if (step == 'review') reviewReached.value = true;
  }

  void next() {
    final step = currentStep;
    if (step == 'venue') addGround(silent: true);
    final error = validate(step);
    if (error != null) return AppSnackbar.error('Check your details', error);
    if (step == 'review') {
      save();
      return;
    }
    goTo(steps[index + 1]);
  }

  void back() {
    if (isSaving.value) return;
    if (index > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      _index.value = index - 1;
      return;
    }
    _confirmLeave();
  }

  void _confirmLeave() {
    Get.dialog(AlertDialog(
      backgroundColor: AppColors.darkSurface,
      title: Text(isEditing ? 'Discard changes?' : 'Discard this tournament?',
          style: const TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, color: Colors.white)),
      content: Text(
        isEditing ? 'Your changes will not be saved.' : 'Everything you entered will be lost.',
        style: TextStyle(fontFamily: 'Gilroy', color: Colors.white.withAlpha(180)),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Keep editing', style: TextStyle(color: Colors.white))),
        TextButton(
          onPressed: () {
            Get.back();
            Get.back();
          },
          child: const Text('Discard', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    ));
  }

  void requestClose() => isSaving.value ? null : _confirmLeave();

  // ─── Sport defaults ───────────────────────────────────────────

  void selectSport(String code) {
    if (sport.value == code) return;
    sport.value = code;
    final (min, max) = TournamentOptions.squadDefaults[code]!;
    squadMin.value = min;
    squadMax.value = max;
    tiebreaker.value = TournamentOptions.tiebreakers[code]!.first.$1;
    pointsPerGame.value = code == 'PICKLEBALL' ? 11 : 21;
  }

  void setMatchType(String type) {
    matchType.value = type;
    switch (type) {
      case 'BOX':
        playersPerSide.value = 8;
        overs.value = 6;
      case 'PAIR':
        playersPerSide.value = 8;
        overs.value = 8;
      case 'THE_HUNDRED':
        playersPerSide.value = 11;
        overs.value = 17; // 100 balls, rounded up to overs
      case 'LIMITED_OVERS':
        playersPerSide.value = 11;
        overs.value = 10;
    }
    oversPerBowler.value = (overs.value / 5).ceil();
    if (powerplayOvers.value > overs.value) powerplayOvers.value = 0;
  }

  void setOvers(int v) {
    overs.value = v;
    if (oversPerBowler.value > v) oversPerBowler.value = v;
    if (powerplayOvers.value > v) powerplayOvers.value = v;
  }

  void setStartDate(DateTime d) {
    startDate.value = d;
    if (endDate.value == null || endDate.value!.isBefore(d)) endDate.value = d;
    final reg = registrationDeadline.value;
    if (reg == null || !reg.isBefore(d)) {
      final dayBefore = d.subtract(const Duration(days: 1));
      final today = DateTime.now();
      registrationDeadline.value = dayBefore.isBefore(DateTime(today.year, today.month, today.day))
          ? DateTime(d.year, d.month, d.day, 8)
          : DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 23, 59);
    }
  }

  void addGround({bool silent = false}) {
    final g = groundCtrl.text.trim();
    if (g.isEmpty) return;
    if (grounds.length >= 10) {
      if (!silent) AppSnackbar.warning('Grounds', 'You can add up to 10 grounds.');
      return;
    }
    if (!grounds.contains(g)) grounds.add(g);
    groundCtrl.clear();
  }

  void toggleMeal(String m) => meals.contains(m) ? meals.remove(m) : meals.add(m);

  // ─── Validation (mirrors the server rules) ───────────────────

  static final _upiRe = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String? validate(String step) {
    _tick.value;
    switch (step) {
      case 'sport':
        return sport.value.isEmpty ? 'Choose a sport.' : null;
      case 'basics':
        final n = nameCtrl.text.trim();
        if (n.length < 3 || n.length > 100) return 'Tournament name must be 3-100 characters.';
        if (descCtrl.text.trim().length > 1000) return 'Description must be under 1000 characters.';
        if (logo.busy.value || banner.busy.value) return 'Wait for the upload to finish.';
        if (!logo.isSet) return 'Add a tournament logo.';
        if (category.value.isEmpty) return 'Choose a category.';
        return null;
      case 'venue':
        final a = areaCtrl.text.trim(), c = cityCtrl.text.trim();
        if (a.length < 2 || a.length > 100) return 'Enter the area or locality.';
        if (c.length < 2 || c.length > 50) return 'Enter the city.';
        if (grounds.isEmpty && groundCtrl.text.trim().isEmpty) return 'Add at least one ground.';
        if (startDate.value == null) return 'Choose a start date.';
        if (startDate.value!.isBefore(_today)) return 'Start date cannot be in the past.';
        if (endDate.value == null) return 'Choose an end date.';
        if (endDate.value!.isBefore(startDate.value!)) return 'End date must be on or after the start date.';
        if (endDate.value!.difference(startDate.value!).inDays > 366) return 'A tournament can last at most a year.';
        return null;
      case 'format':
        if (format.value.isEmpty) return 'Choose a format.';
        if (squadMax.value < squadMin.value) return 'Maximum squad size must be at least the minimum.';
        if (format.value == 'LEAGUE_KNOCKOUT') {
          if (maxTeams.value / groupCount.value < 2) return 'Each group needs at least 2 teams.';
          if (qualifyPerGroup.value >= (maxTeams.value / groupCount.value).ceil()) {
            return 'Fewer teams must qualify than play in each group.';
          }
        }
        return null;
      case 'rules':
        if (sport.value == 'CRICKET' && matchType.value != 'TEST') {
          if (oversPerBowler.value > overs.value) return 'Overs per bowler cannot exceed overs per innings.';
          if (powerplayOvers.value > overs.value) return 'Powerplay cannot be longer than the innings.';
        }
        return null;
      case 'fees':
        final raw = entryFeeCtrl.text.trim();
        if (raw.isNotEmpty && (int.tryParse(raw) == null || entryFee < 0 || entryFee > 100000)) {
          return 'Entry fee must be between ₹0 and ₹1,00,000.';
        }
        if (prizeCtrl.text.trim().length > 255) return 'Prize details must be under 255 characters.';
        return null;
      case 'payment':
        if (!_upiRe.hasMatch(upiCtrl.text.trim())) return 'Enter a valid UPI ID, e.g. name@okaxis.';
        final n = upiNameCtrl.text.trim();
        if (n.length < 2 || n.length > 100) return 'Enter the name on the UPI account.';
        if (qr.busy.value) return 'Wait for the upload to finish.';
        if (payNoteCtrl.text.trim().length > 255) return 'Payment note must be under 255 characters.';
        return null;
      case 'extras':
        if (foodProvided.value && meals.isEmpty) return 'Choose which meals are provided.';
        if (jerseyProvided.value) {
          final raw = jerseyFeeCtrl.text.trim();
          if (raw.isNotEmpty && int.tryParse(raw) == null) return 'Jersey fee is invalid.';
          if (jerseyFee > entryFee) return 'Jersey fee must be included in the entry fee.';
        }
        return null;
      case 'registration':
        final reg = registrationDeadline.value;
        if (reg == null) return 'Choose a registration deadline.';
        if (startDate.value != null && !reg.isBefore(startDate.value!.add(const Duration(days: 1)))) {
          return 'Registration must close before the tournament starts.';
        }
        return null;
      case 'media':
        if (docBusy.value) return 'Wait for the upload to finish.';
        return null;
      case 'review':
        for (final s in steps.where((s) => s != 'review')) {
          final e = validate(s);
          if (e != null) return e;
        }
        return null;
    }
    return null;
  }

  bool isStepValid(String step) => validate(step) == null;

  // ─── Uploads ──────────────────────────────────────────────────

  Future<void> pickImage(UploadSlot slot, String kind, ImageShape shape) async {
    final file = await uploadImage(kind, shape, slot: slot);
    if (file != null) slot.file.value = file;
  }

  /// Picks an image from the gallery, prepares it and uploads it. Returns null if cancelled or failed.
  Future<UploadedFile?> uploadImage(String kind, ImageShape shape, {UploadSlot? slot}) async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400, imageQuality: 95);
      if (picked == null) return null;
      slot?.busy.value = true;
      final path = await ImagePrep.toJpeg(picked.path, shape);
      return await _upload(kind, path, 'image/jpeg');
    } catch (e) {
      _pickError(e);
      return null;
    } finally {
      slot?.busy.value = false;
    }
  }

  Future<UploadedFile?> _upload(String kind, String path, String mime) async {
    try {
      final res = await _api.uploadFile(kind, path, mime);
      if (res['success'] != true) {
        AppSnackbar.error('Upload failed', res['message']?.toString() ?? 'Please try again.');
        return null;
      }
      return UploadedFile(
        key: res['key'].toString(),
        url: res['url']?.toString(),
        localPath: path,
        mimeType: res['mime_type']?.toString() ?? mime,
        sizeBytes: (res['size_bytes'] as num?)?.toInt() ?? File(path).lengthSync(),
      );
    } on ApiException catch (e) {
      AppSnackbar.error('Upload failed', e.message);
      return null;
    }
  }

  void _pickError(Object e) {
    final msg = e.toString();
    if (msg.contains('denied')) {
      AppSnackbar.warning('Permission needed', 'Allow photo access for MyPaltan in Settings.');
    } else {
      logError('Image pick failed', e);
      AppSnackbar.error('Image', "Couldn't use that image. Try another one.");
    }
  }

  /// Picks a PDF, JPG or PNG for a tournament document and uploads it.
  Future<UploadedFile?> pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
      final path = result?.files.single.path;
      if (path == null) return null;
      docBusy.value = true;
      final isPdf = path.toLowerCase().endsWith('.pdf');
      if (isPdf) {
        if (File(path).lengthSync() > 10 * 1024 * 1024) {
          AppSnackbar.error('Too large', 'Documents must be under 10 MB.');
          return null;
        }
        return await _upload('TOURNAMENT_DOC', path, 'application/pdf');
      }
      final jpg = await ImagePrep.toJpeg(path, ImageShape.original);
      return await _upload('TOURNAMENT_DOC', jpg, 'image/jpeg');
    } catch (e) {
      logError('Document pick failed', e);
      AppSnackbar.error('Document', "Couldn't use that file. Try another one.");
      return null;
    } finally {
      docBusy.value = false;
    }
  }

  void addDocument(DocumentDraft d) => documents.add(d);
  void replaceDocument(int i, DocumentDraft d) => documents[i] = d;
  void removeDocument(int i) => documents.removeAt(i);

  /// Adds or replaces a sponsor. Only one title sponsor is allowed, so marking a new one clears the old.
  void upsertSponsor(SponsorDraft s, {int? at}) {
    if (s.isTitle) {
      for (var i = 0; i < sponsors.length; i++) {
        if (sponsors[i].isTitle && i != at) sponsors[i] = sponsors[i].copyWith(isTitle: false);
      }
    }
    if (at == null) {
      sponsors.add(s);
    } else {
      sponsors[at] = s;
    }
  }

  void removeSponsor(int i) => sponsors.removeAt(i);

  // ─── Date pickers ─────────────────────────────────────────────

  static Widget _pickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.darkSurface,
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppColors.darkSurface),
        ),
        child: child!,
      );

  Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last, String? help}) {
    final f = first ?? _today;
    final l = last ?? _today.add(const Duration(days: 730));
    var init = initial ?? f;
    if (init.isBefore(f)) init = f;
    if (init.isAfter(l)) init = l;
    return showDatePicker(context: context, initialDate: init, firstDate: f, lastDate: l, helpText: help, builder: _pickerTheme);
  }

  Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial, DateTime? last, String? help}) async {
    final d = await pickDate(context, initial: initial, last: last, help: help);
    if (d == null || !context.mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : const TimeOfDay(hour: 23, minute: 59),
      builder: _pickerTheme,
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  // ─── Save ─────────────────────────────────────────────────────

  static String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _dt(DateTime d) =>
      '${_d(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  static String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Map<String, dynamic> _matchRules() => switch (sport.value) {
        'CRICKET' => {
            'match_type': matchType.value,
            'ball_type': ballType.value,
            if (pitchType.value.isNotEmpty) 'pitch_type': pitchType.value,
            'players_per_side': playersPerSide.value,
            'last_batter': lastBatter.value,
            if (matchType.value != 'TEST') ...{
              'overs': overs.value,
              'overs_per_bowler': oversPerBowler.value,
              'powerplay_overs': powerplayOvers.value,
            },
          },
        'FOOTBALL' => {
            'players_per_side': footballPlayers.value,
            'half_minutes': halfMinutes.value,
            'rolling_subs': rollingSubs.value,
            'extra_time': extraTime.value,
            'penalties': penalties.value,
          },
        _ => {
            'event': racketEvent.value,
            'points_per_game': pointsPerGame.value,
            'games': games.value,
            'win_by_two': winByTwo.value,
            if (sport.value == 'PICKLEBALL') 'scoring': scoring.value,
          },
      };

  Map<String, dynamic> buildPayload() => {
        if (isEditing) 'code': editCode,
        'sport': sport.value,
        'name': nameCtrl.text.trim(),
        'description': _opt(descCtrl),
        'logo_key': logo.file.value?.key,
        'banner_key': banner.file.value?.key,
        'category': category.value,
        'city': cityCtrl.text.trim(),
        'area': areaCtrl.text.trim(),
        'grounds': grounds.toList(),
        'start_date': startDate.value == null ? null : _d(startDate.value!),
        'end_date': endDate.value == null ? null : _d(endDate.value!),
        'match_days': matchDays.value,
        'match_timing': matchTiming.value,
        'format': format.value,
        if (format.value == 'LEAGUE_KNOCKOUT') ...{'group_count': groupCount.value, 'qualify_per_group': qualifyPerGroup.value},
        'max_teams': maxTeams.value,
        'squad_min': squadMin.value,
        'squad_max': squadMax.value,
        'match_rules': _matchRules(),
        'points': {
          'win': ptsWin.value,
          'tie': ptsTie.value,
          'no_result': ptsNoResult.value,
          'loss': ptsLoss.value,
          'tiebreaker': tiebreaker.value,
        },
        'entry_fee': entryFee,
        'prize_type': prizeType.value,
        'prize_details': prizeType.value == 'NONE' ? null : _opt(prizeCtrl),
        if (entryFee > 0)
          'payment': {
            'upi_id': upiCtrl.text.trim(),
            'upi_name': upiNameCtrl.text.trim(),
            'qr_key': qr.file.value?.key,
            'accept_cash': acceptCash.value,
            'note': _opt(payNoteCtrl),
          },
        'food_provided': foodProvided.value,
        'meals': foodProvided.value ? meals.toList() : <String>[],
        'jersey_provided': jerseyProvided.value,
        'jersey_print': jerseyProvided.value ? jerseyPrint.value : null,
        'jersey_fee': jerseyProvided.value ? jerseyFee : 0,
        'registration_deadline': registrationDeadline.value == null ? null : _dt(registrationDeadline.value!),
        'checklist_deadline': hasExtras && checklistDeadline.value != null ? _dt(checklistDeadline.value!) : null,
        'documents': [
          for (final d in documents)
            {
              'doc_type': d.docType,
              'title': d.title,
              'file_key': d.file.key,
              'mime_type': d.file.mimeType,
              'size_bytes': d.file.sizeBytes,
            },
        ],
        'sponsors': [
          for (final s in sponsors)
            {
              'id': s.id,
              'name': s.name,
              'label': s.label,
              'is_title': s.isTitle,
              'logo_key': s.logo.key,
              'banner_key': s.banner?.key,
              'link_url': s.linkUrl,
              'tagline': s.tagline,
            },
        ],
      };

  Future<void> save() async {
    isSaving.value = true;
    try {
      final res = await _api.saveTournament(buildPayload());
      if (res['success'] != true) {
        AppSnackbar.error('Could not save', res['message']?.toString() ?? 'Please try again.');
        return;
      }
      final code = res['code'].toString();
      if (isEditing) {
        Get.back(result: true);
        AppSnackbar.success('Saved', 'Your tournament is updated.');
      } else {
        Get.offNamed(AppRoutes.tournament, arguments: {'code': code});
        AppSnackbar.success('Tournament created', 'Saved as a draft. Publish it when you are ready.');
      }
    } on ApiException catch (e) {
      AppSnackbar.error('Could not save', e.message);
    } finally {
      isSaving.value = false;
    }
  }

  // ─── Edit mode ────────────────────────────────────────────────

  Future<void> _loadForEdit() async {
    isLoading.value = true;
    try {
      final res = await _api.getTournament(editCode!);
      if (res['success'] != true || res['tournament'] is! Map) {
        Get.back();
        AppSnackbar.error('Tournament', res['message']?.toString() ?? 'Could not load the tournament.');
        return;
      }
      _prefill(Tournament.fromJson(Map<String, dynamic>.from(res['tournament'] as Map)));
      goTo('review');
    } on ApiException catch (e) {
      Get.back();
      AppSnackbar.error('Tournament', e.message);
    } finally {
      isLoading.value = false;
    }
  }

  void _prefill(Tournament t) {
    selectSport(t.sport);
    nameCtrl.text = t.name;
    descCtrl.text = t.description ?? '';
    if (t.logoKey != null) logo.file.value = UploadedFile(key: t.logoKey!, url: t.logoUrl);
    if (t.bannerKey != null) banner.file.value = UploadedFile(key: t.bannerKey!, url: t.bannerUrl);
    category.value = t.category;
    areaCtrl.text = t.area;
    cityCtrl.text = t.city;
    grounds.assignAll(t.grounds);
    startDate.value = t.startDate;
    endDate.value = t.endDate;
    matchDays.value = t.matchDays;
    matchTiming.value = t.matchTiming;
    format.value = t.format;
    maxTeams.value = t.maxTeams;
    groupCount.value = t.groupCount ?? 2;
    qualifyPerGroup.value = t.qualifyPerGroup ?? 2;
    squadMin.value = t.squadMin;
    squadMax.value = t.squadMax;

    final r = t.matchRules;
    int ri(String k, int f) => (r[k] as num?)?.toInt() ?? f;
    bool rb(String k, bool f) => r[k] is bool ? r[k] as bool : f;
    if (t.sport == 'CRICKET') {
      matchType.value = r['match_type']?.toString() ?? 'LIMITED_OVERS';
      ballType.value = r['ball_type']?.toString() ?? 'TENNIS';
      pitchType.value = r['pitch_type']?.toString() ?? '';
      playersPerSide.value = ri('players_per_side', 11);
      overs.value = ri('overs', 10);
      oversPerBowler.value = ri('overs_per_bowler', 2);
      powerplayOvers.value = ri('powerplay_overs', 0);
      lastBatter.value = rb('last_batter', false);
    } else if (t.sport == 'FOOTBALL') {
      footballPlayers.value = ri('players_per_side', 7);
      halfMinutes.value = ri('half_minutes', 20);
      rollingSubs.value = rb('rolling_subs', true);
      extraTime.value = rb('extra_time', false);
      penalties.value = rb('penalties', true);
    } else {
      racketEvent.value = r['event']?.toString() ?? 'DOUBLES';
      pointsPerGame.value = ri('points_per_game', 21);
      games.value = ri('games', 3);
      winByTwo.value = rb('win_by_two', true);
      scoring.value = r['scoring']?.toString() ?? 'SIDE_OUT';
    }

    final p = t.points;
    ptsWin.value = (p['win'] as num?)?.toInt() ?? 2;
    ptsTie.value = (p['tie'] as num?)?.toInt() ?? 1;
    ptsNoResult.value = (p['no_result'] as num?)?.toInt() ?? 1;
    ptsLoss.value = (p['loss'] as num?)?.toInt() ?? 0;
    tiebreaker.value = p['tiebreaker']?.toString() ?? tiebreaker.value;

    entryFeeCtrl.text = t.entryFee > 0 ? '${t.entryFee}' : '';
    prizeType.value = t.prizeType;
    prizeCtrl.text = t.prizeDetails ?? '';
    final pay = t.payment;
    if (pay != null) {
      upiCtrl.text = pay.upiId;
      upiNameCtrl.text = pay.upiName;
      if (pay.qrKey != null) qr.file.value = UploadedFile(key: pay.qrKey!, url: pay.qrUrl);
      acceptCash.value = pay.acceptCash;
      payNoteCtrl.text = pay.note ?? '';
    }
    foodProvided.value = t.foodProvided;
    meals.assignAll(t.meals);
    jerseyProvided.value = t.jerseyProvided;
    jerseyPrint.value = t.jerseyPrint ?? 'NAME_NUMBER';
    jerseyFeeCtrl.text = t.jerseyFee > 0 ? '${t.jerseyFee}' : '';
    registrationDeadline.value = t.registrationDeadline;
    checklistDeadline.value = t.checklistDeadline;
    documents.assignAll(t.documents.where((d) => d.fileKey != null).map((d) => DocumentDraft(
          docType: d.docType,
          title: d.title,
          file: UploadedFile(key: d.fileKey!, url: d.url, mimeType: d.mimeType, sizeBytes: d.sizeBytes),
        )));
    sponsors.assignAll(t.sponsors.where((s) => s.logoKey != null).map((s) => SponsorDraft(
          id: s.id,
          name: s.name,
          label: s.label,
          isTitle: s.isTitle,
          logo: UploadedFile(key: s.logoKey!, url: s.logoUrl),
          banner: s.bannerKey == null ? null : UploadedFile(key: s.bannerKey!, url: s.bannerUrl),
          linkUrl: s.linkUrl,
          tagline: s.tagline,
        )));
  }
}
