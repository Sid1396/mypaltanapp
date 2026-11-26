import 'package:get/get.dart';
import '../../data/services/api_service.dart';
import '../../data/services/session_service.dart';
import '../../utils/mixins/logger_mixin.dart';

/// Career stats and rankings from every completed match (Home → My stats, Rankings), on two separate tabs. Tournament
/// and quick-match stats are kept apart: [kind] picks one, never both. Arguments: {'sport': 'CRICKET', 'tab': 'RANKS'} optional.
class RankingsController extends GetxController with LoggerMixin {
  ApiService get _api => Get.find<ApiService>();

  final tab = 'ME'.obs; // ME (my own stats) or RANKS
  final sport = 'CRICKET'.obs;
  final kind = 'TOURNAMENT'.obs;
  final list = 'overall'.obs;
  final period = 'ALL'.obs;
  final age = 'ALL'.obs;
  final gender = 'ALL'.obs;
  final ball = 'ALL'.obs;
  final city = ''.obs;
  final block = ''.obs;

  final data = Rx<Map<String, dynamic>?>(null);
  final isLoading = true.obs;
  final error = Rx<String?>(null);
  int _seq = 0;

  /// The player's own sports that have stats (cricket and football), cricket first.
  List<String> get sports {
    final mine = Get.find<SessionService>().user.value?.sports.map((s) => s.sport).where((s) => s == 'CRICKET' || s == 'FOOTBALL').toList() ?? [];
    return mine.isEmpty ? const ['CRICKET', 'FOOTBALL'] : (mine..sort());
  }

  List<(String, String)> get lists => sport.value == 'CRICKET'
      ? const [('overall', 'Overall'), ('batting', 'Batting'), ('bowling', 'Bowling'), ('fielding', 'Fielding')]
      : const [('overall', 'Overall'), ('goals', 'Goals'), ('assists', 'Assists'), ('clean_sheets', 'Clean sheets')];

  int get filterCount => [period.value != 'ALL', age.value != 'ALL', gender.value != 'ALL', ball.value != 'ALL', city.value.isNotEmpty].where((x) => x).length;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    final s = args is Map ? args['sport'] as String? : null;
    if (args is Map && args['tab'] == 'RANKS') tab.value = 'RANKS';
    sport.value = s ?? sports.first;
    load();
  }

  void setSport(String s) {
    if (s == sport.value) return;
    sport.value = s;
    list.value = 'overall';
    ball.value = 'ALL';
    load();
  }

  void setKind(String k) {
    if (k == kind.value) return;
    kind.value = k;
    load();
  }

  void setFilters({String? period, String? age, String? gender, String? ball, String? city, String? block}) {
    if (period != null) this.period.value = period;
    if (age != null) this.age.value = age;
    if (gender != null) this.gender.value = gender;
    if (ball != null) this.ball.value = ball;
    if (city != null) {
      this.city.value = city;
      this.block.value = '';
    }
    if (block != null) this.block.value = block;
    load();
  }

  void clearFilters() => setFilters(period: 'ALL', age: 'ALL', gender: 'ALL', ball: 'ALL', city: '');

  Future<void> load() async {
    final seq = ++_seq;
    isLoading.value = true;
    error.value = null;
    try {
      final res = await _api.getPlayerStats({
        'sport': sport.value,
        'kind': kind.value,
        'period': period.value,
        'age': age.value,
        'gender': gender.value,
        if (sport.value == 'CRICKET') 'ball': ball.value,
        if (city.value.isNotEmpty) 'city': city.value,
        if (block.value.isNotEmpty) 'block': block.value,
      });
      if (seq != _seq) return;
      if (res['success'] == true) {
        data.value = res;
      } else {
        error.value = res['message']?.toString() ?? 'Could not load the rankings.';
      }
    } on ApiException catch (e) {
      if (seq == _seq) error.value = e.message;
      logError('Rankings failed', e);
    } finally {
      if (seq == _seq) isLoading.value = false;
    }
  }
}
