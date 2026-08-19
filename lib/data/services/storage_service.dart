import '../models/counter_model.dart';
import '../providers/local_storage_provider.dart';

class StorageService {
  final LocalStorageProvider _provider;

  StorageService(this._provider);

  CounterModel loadCounter() {
    final value = _provider.readCounterValue();
    final rawHistory = _provider.readHistory();
    final totalIncrements = _provider.readTotalIncrements();
    final totalDecrements = _provider.readTotalDecrements();

    final history = rawHistory
        .whereType<Map>()
        .map((e) => OperationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return CounterModel(
      value: value,
      history: history,
      totalIncrements: totalIncrements,
      totalDecrements: totalDecrements,
    );
  }

  void saveCounter(CounterModel model) {
    _provider.writeCounterValue(model.value);
    _provider.writeHistory(model.history.map((e) => e.toJson()).toList());
    _provider.writeTotalIncrements(model.totalIncrements);
    _provider.writeTotalDecrements(model.totalDecrements);
  }

  bool loadIsDarkMode() => _provider.readIsDarkMode();
  void saveIsDarkMode(bool isDark) => _provider.writeIsDarkMode(isDark);
}
