import '../../config/app_constants.dart';
import '../models/counter_model.dart';
import '../services/storage_service.dart';

abstract class CounterRepositoryBase {
  CounterModel getCounter();
  void saveCounter(CounterModel model);
  CounterModel increment(CounterModel model);
  CounterModel decrement(CounterModel model);
  CounterModel reset(CounterModel model);
  CounterModel setCustomValue(CounterModel model, int value);
}

class CounterRepository implements CounterRepositoryBase {
  final StorageService _storageService;

  CounterRepository(this._storageService);

  @override
  CounterModel getCounter() => _storageService.loadCounter();

  @override
  void saveCounter(CounterModel model) => _storageService.saveCounter(model);

  @override
  CounterModel increment(CounterModel model) {
    if (model.value >= AppConstants.maxCounterValue) return model;
    return _addOperation(model, 'increment', model.value + 1);
  }

  @override
  CounterModel decrement(CounterModel model) {
    if (model.value <= AppConstants.minCounterValue) return model;
    return _addOperation(model, 'decrement', model.value - 1);
  }

  @override
  CounterModel reset(CounterModel model) {
    if (model.value == 0) return model;
    return _addOperation(model, 'reset', 0);
  }

  @override
  CounterModel setCustomValue(CounterModel model, int value) {
    final clamped = value.clamp(
      AppConstants.minCounterValue,
      AppConstants.maxCounterValue,
    );
    if (clamped == model.value) return model;
    return _addOperation(model, 'custom', clamped);
  }

  CounterModel _addOperation(CounterModel model, String type, int newValue) {
    final operation = OperationModel(
      type: type,
      previousValue: model.value,
      newValue: newValue,
      timestamp: DateTime.now(),
    );

    final updatedHistory = [operation, ...model.history]
        .take(AppConstants.maxHistoryItems)
        .toList();

    return model.copyWith(
      value: newValue,
      history: updatedHistory,
      totalIncrements:
          type == 'increment' ? model.totalIncrements + 1 : model.totalIncrements,
      totalDecrements:
          type == 'decrement' ? model.totalDecrements + 1 : model.totalDecrements,
    );
  }
}
