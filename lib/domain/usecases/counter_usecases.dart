import '../../data/models/counter_model.dart';
import '../../data/repositories/counter_repository.dart';

class CounterUseCases {
  final CounterRepositoryBase _repository;

  CounterUseCases(this._repository);

  CounterModel loadCounter() => _repository.getCounter();

  CounterModel increment(CounterModel model) {
    final updated = _repository.increment(model);
    _repository.saveCounter(updated);
    return updated;
  }

  CounterModel decrement(CounterModel model) {
    final updated = _repository.decrement(model);
    _repository.saveCounter(updated);
    return updated;
  }

  CounterModel reset(CounterModel model) {
    final updated = _repository.reset(model);
    _repository.saveCounter(updated);
    return updated;
  }

  CounterModel setCustomValue(CounterModel model, int value) {
    final updated = _repository.setCustomValue(model, value);
    _repository.saveCounter(updated);
    return updated;
  }
}
