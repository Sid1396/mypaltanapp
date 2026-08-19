import 'package:get/get.dart';
import '../../config/app_constants.dart';
import '../../data/models/counter_model.dart';
import '../../domain/usecases/counter_usecases.dart';
import '../../utils/helpers/format_helper.dart';
import '../../utils/helpers/snackbar_helper.dart';

class CounterController extends GetxController {
  final CounterUseCases _useCases;

  CounterController(this._useCases);

  final _model = CounterModel.initial().obs;

  int get value => _model.value.value;
  List<OperationModel> get history => _model.value.history;
  int get totalIncrements => _model.value.totalIncrements;
  int get totalDecrements => _model.value.totalDecrements;
  int get totalOperations => totalIncrements + totalDecrements;

  bool get canIncrement => value < AppConstants.maxCounterValue;
  bool get canDecrement => value > AppConstants.minCounterValue;

  @override
  void onInit() {
    super.onInit();
    _model.value = _useCases.loadCounter();
  }

  void increment() {
    if (!canIncrement) {
      AppSnackbar.warning('Limit Reached', 'Maximum value is ${AppConstants.maxCounterValue}');
      return;
    }
    _model.value = _useCases.increment(_model.value);
    AppSnackbar.success('Incremented', 'Counter is now ${FormatHelper.formatNumber(value)}');
  }

  void decrement() {
    if (!canDecrement) {
      AppSnackbar.warning('Limit Reached', 'Minimum value is ${AppConstants.minCounterValue}');
      return;
    }
    _model.value = _useCases.decrement(_model.value);
    AppSnackbar.info('Decremented', 'Counter is now ${FormatHelper.formatNumber(value)}');
  }

  void reset() {
    if (value == 0) return;
    _model.value = _useCases.reset(_model.value);
    AppSnackbar.warning('Reset', 'Counter has been reset to 0');
  }

  void setCustomValue(int newValue) {
    _model.value = _useCases.setCustomValue(_model.value, newValue);
    AppSnackbar.info('Value Set', 'Counter is now ${FormatHelper.formatNumber(value)}');
  }
}
